// Package battle implements the V4-S3 lockstep relay: it pairs two clients,
// paces a 10Hz tick loop, bundles each tick's deploy commands and broadcasts
// them so both clients advance their own logic/ in lockstep, compares the
// state hashes the clients report, and finalizes the result the clients claim.
//
// The server runs NO battle simulation (that's the whole point of lockstep —
// no second copy of logic/ in Go). It is a deterministic relay + referee:
// order deploys by tick, broadcast identically to both sides, and trust the
// (cross-checked) client reports for hashes and the final outcome.
//
// V4-S3f adds robustness: heartbeats keep the connection live; a dropped or
// silent client pauses the room and opens a reconnect window; reconnecting
// replays the command stream so the client fast-forwards back into lockstep;
// if the window expires the opponent wins by disconnect.
package battle

import (
	"context"
	"encoding/binary"
	"log"
	"time"

	pbbattle "github.com/jchensh/godot-clash-pusher/server/internal/pb/battle"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	"google.golang.org/protobuf/proto"
)

const (
	TickHz       = 10
	TickInterval = time.Second / TickHz
	// trophyWin is the flat trophy swing in S3 (placeholder; real ELO in S4/S5).
	trophyWin = 30
	// maxTicks caps a room's lifetime as an anti-hang safety net (~5 min at
	// 10Hz). Clients report TIMEOUT at their own match_duration well before this.
	maxTicks = 3000

	// V4-S3f timeouts (overridable per room for tests).
	defaultSilenceTimeout  = 30 * time.Second // no inbound this long -> treat as disconnected
	defaultReconnectWindow = 60 * time.Second // grace to reconnect before the opponent wins
)

// player is one side of a room. send carries framed [2B msgid][payload] messages
// out to that client; it is swapped on reconnect.
type player struct {
	accountID int64
	side      int32 // 1 or 2
	deck      []string
	progress  []*pbbattle.CardProgress // per-card level/rank from economy_cards (KAN-76)
	summary   *pbcommon.ProfileSummary
	send      chan []byte
	connected bool
	lastSeen  time.Time
}

// inbound is a decoded client->server message handed to the room loop.
type inbound struct {
	side    int32
	msgID   pbcommon.MsgId
	payload []byte
}

// reconnReq re-attaches a fresh connection's send channel to a disconnected side.
type reconnReq struct {
	side int32
	send chan []byte
}

// Room relays one lockstep match between two players.
type Room struct {
	id      string
	levelID string
	seed    uint64
	p1, p2  *player
	persist Persister
	now     func() time.Time
	started time.Time

	silenceTimeout  time.Duration
	reconnectWindow time.Duration

	in     chan inbound
	disc   chan int32     // a side's connection dropped
	reconn chan reconnReq // a side reconnected
	done   chan struct{}

	// The following are touched only from the single run-loop goroutine (or
	// directly by tests), so they need no locking.
	curTick  int32
	pending  map[int32][]*pbbattle.TickBundle_SideDeploy
	history  []*pbbattle.TickBundle // all broadcast bundles, replayed on reconnect
	hashes   map[int32]map[int32][]byte
	endRep   map[int32]*pbbattle.BattleEndReport
	ended    bool
	mismatch bool

	paused bool      // true while a side is disconnected (ticking halts)
	discAt time.Time // when the current pause began
}

// NewRoom wires a room. now defaults to time.Now when nil.
func NewRoom(id, levelID string, seed uint64, p1, p2 *player, persist Persister, now func() time.Time) *Room {
	if now == nil {
		now = time.Now
	}
	t := now()
	p1.connected, p1.lastSeen = true, t
	p2.connected, p2.lastSeen = true, t
	return &Room{
		id: id, levelID: levelID, seed: seed, p1: p1, p2: p2,
		persist: persist, now: now,
		silenceTimeout:  defaultSilenceTimeout,
		reconnectWindow: defaultReconnectWindow,
		in:      make(chan inbound, 256),
		disc:    make(chan int32, 4),
		reconn:  make(chan reconnReq, 4),
		done:    make(chan struct{}),
		pending: map[int32][]*pbbattle.TickBundle_SideDeploy{},
		history: []*pbbattle.TickBundle{},
		hashes:  map[int32]map[int32][]byte{},
		endRep:  map[int32]*pbbattle.BattleEndReport{},
	}
}

func (r *Room) playerBySide(side int32) *player {
	if side == 1 {
		return r.p1
	}
	if side == 2 {
		return r.p2
	}
	return nil
}

func (r *Room) sideOf(accountID int64) int32 {
	if r.p1.accountID == accountID {
		return 1
	}
	if r.p2.accountID == accountID {
		return 2
	}
	return 0
}

// isEnded reports whether the room has finalized (race-free for the hub).
func (r *Room) isEnded() bool {
	select {
	case <-r.done:
		return true
	default:
		return false
	}
}

// reconnect hands a fresh connection back to the run loop (called by the hub).
func (r *Room) reconnect(p *player) {
	select {
	case r.reconn <- reconnReq{side: p.side, send: p.send}:
	case <-r.done:
	}
}

func (r *Room) joinRespFor(p *player) *pbbattle.JoinRoomResp {
	opp := r.p2.summary
	if p.side == 2 {
		opp = r.p1.summary
	}
	return &pbbattle.JoinRoomResp{
		Ok: true, Opponent: opp, YourSide: p.side, StartTick: 0, Seed: r.seed,
		Side1Deck: r.p1.deck, Side2Deck: r.p2.deck, LevelId: r.levelID,
		// KAN-76: both sides receive BOTH progressions so the two clients build
		// bit-identical Matches (lockstep). Reconnect replays this same resp.
		Side1Progress: r.p1.progress, Side2Progress: r.p2.progress,
	}
}

// sendJoinResp tells both clients the match setup so they build identical Matches.
func (r *Room) sendJoinResp() {
	r.started = r.now()
	r.sendTo(r.p1, pbcommon.MsgId_JOIN_ROOM_RESP, r.joinRespFor(r.p1))
	r.sendTo(r.p2, pbcommon.MsgId_JOIN_ROOM_RESP, r.joinRespFor(r.p2))
}

// onDeploy buffers a deploy for its target tick (clamped to >= curTick+1).
func (r *Room) onDeploy(side int32, d *pbbattle.DeployCmd) {
	if r.ended || d == nil {
		return
	}
	t := d.Tick
	if t < r.curTick+1 {
		t = r.curTick + 1
	}
	d.Tick = t
	r.pending[t] = append(r.pending[t], &pbbattle.TickBundle_SideDeploy{Side: side, Deploy: d})
}

// onTick broadcasts the current tick's bundle (recorded for reconnect replay)
// and advances curTick. No-op while paused.
func (r *Room) onTick() {
	if r.paused {
		return
	}
	bundle := &pbbattle.TickBundle{Tick: r.curTick, Deploys: r.pending[r.curTick]}
	r.broadcast(pbcommon.MsgId_TICK_BUNDLE, bundle)
	r.history = append(r.history, bundle)
	delete(r.pending, r.curTick)
	r.curTick++
}

// onHash records a client's hash and compares once both sides reported a tick.
func (r *Room) onHash(side int32, h *pbbattle.StateHashUp) bool {
	if h == nil {
		return false
	}
	m := r.hashes[h.Tick]
	if m == nil {
		m = map[int32][]byte{}
		r.hashes[h.Tick] = m
	}
	m[side] = h.Hash
	if len(m) == 2 {
		if !bytesEqual(m[1], m[2]) {
			r.mismatch = true
		}
		delete(r.hashes, h.Tick)
		return r.mismatch
	}
	return false
}

// onEnd records a client's end-of-match claim and finalizes once both agree.
func (r *Room) onEnd(side int32, rep *pbbattle.BattleEndReport) bool {
	if r.ended || rep == nil {
		return false
	}
	r.endRep[side] = rep
	other := r.endRep[3-side]
	if other != nil {
		if other.Winner != rep.Winner {
			r.mismatch = true
		}
		r.finalize(rep.Winner, pbbattle.BattleResultPush_Reason(rep.Reason), rep.Side_1Score, rep.Side_2Score)
		return true
	}
	return false
}

// onHeartbeat replies with a pong (RTT estimation + liveness).
func (r *Room) onHeartbeat(side int32) {
	if p := r.playerBySide(side); p != nil {
		r.sendTo(p, pbcommon.MsgId_HEARTBEAT_PONG, &pbbattle.HeartbeatPong{ServerTime: r.now().UnixMilli()})
	}
}

// onDisconnect marks a side dropped and pauses the room, opening the reconnect
// window. The opponent's client stops receiving bundles and pauses too.
func (r *Room) onDisconnect(side int32) {
	if r.ended {
		return
	}
	p := r.playerBySide(side)
	if p == nil || !p.connected {
		return
	}
	p.connected = false
	if !r.paused {
		r.paused = true
		r.discAt = r.now()
		log.Printf("battle %s: side %d dropped, reconnect window open", r.id, side)
	}
}

// onReconnect re-attaches the side's new connection and replays the whole
// command stream (fresh JoinRoomResp + every past TickBundle) so the client
// deterministically fast-forwards back to the current tick. Resumes when both
// sides are connected again.
func (r *Room) onReconnect(req reconnReq) {
	if r.ended {
		return
	}
	p := r.playerBySide(req.side)
	if p == nil {
		return
	}
	p.send = req.send
	p.connected = true
	p.lastSeen = r.now()
	r.sendTo(p, pbcommon.MsgId_JOIN_ROOM_RESP, r.joinRespFor(p))
	for _, b := range r.history {
		r.sendTo(p, pbcommon.MsgId_TICK_BUNDLE, b)
	}
	log.Printf("battle %s: side %d reconnected, replayed %d ticks", r.id, req.side, len(r.history))
	if r.p1.connected && r.p2.connected {
		r.paused = false
		r.discAt = time.Time{}
	}
}

// finalize computes trophy deltas, pushes the result, and persists. Idempotent.
func (r *Room) finalize(winner int32, reason pbbattle.BattleResultPush_Reason, s1, s2 int32) {
	if r.ended {
		return
	}
	r.ended = true

	var d1, d2 int32
	var winnerAcc int64
	switch winner {
	case 1:
		d1, d2, winnerAcc = trophyWin, -trophyWin, r.p1.accountID
	case 2:
		d1, d2, winnerAcc = -trophyWin, trophyWin, r.p2.accountID
	}
	log.Printf("battle %s: end winner=%d reason=%s trophy=%d/%d", r.id, winner, reason, d1, d2)

	r.broadcast(pbcommon.MsgId_BATTLE_RESULT_PUSH, &pbbattle.BattleResultPush{
		Winner:              pbbattle.BattleResultPush_Winner(winner),
		Reason:              reason,
		Side_1Score:         s1,
		Side_2Score:         s2,
		TrophiesDeltaSide_1: d1,
		TrophiesDeltaSide_2: d2,
	})

	if r.persist != nil {
		_ = r.persist.SaveMatch(context.Background(), MatchResult{
			P1Account: r.p1.accountID, P2Account: r.p2.accountID,
			WinnerAccount: winnerAcc, Reason: reason.String(),
			StartedAt: r.started, EndedAt: r.now(), P1Delta: d1, P2Delta: d2,
		})
	}
	close(r.done)
}

// finalizeDisconnect ends the match in favor of the still-connected side (draw
// if both are gone) after the reconnect window expires.
func (r *Room) finalizeDisconnect() {
	var winner int32
	if r.p1.connected && !r.p2.connected {
		winner = 1
	} else if r.p2.connected && !r.p1.connected {
		winner = 2
	}
	r.finalize(winner, pbbattle.BattleResultPush_DISCONNECT, 0, 0)
}

// step is one tick of the loop body (extracted so tests can drive it). While
// paused it watches the reconnect window; otherwise it checks for silent
// clients then advances a tick.
func (r *Room) step() {
	if r.paused {
		if r.now().Sub(r.discAt) > r.reconnectWindow {
			r.finalizeDisconnect()
		}
		return
	}
	for _, p := range []*player{r.p1, r.p2} {
		if p.connected && r.now().Sub(p.lastSeen) > r.silenceTimeout {
			r.onDisconnect(p.side)
		}
	}
	if r.paused {
		return
	}
	r.onTick()
	if r.curTick > maxTicks && !r.ended {
		r.finalize(0, pbbattle.BattleResultPush_TIMEOUT, 0, 0)
	}
}

// Run drives the room: a 10Hz ticker plus inbound / disconnect / reconnect
// channels. Single goroutine → room state needs no locking.
func (r *Room) Run(ctx context.Context) {
	log.Printf("battle %s: room started, sent JoinResp to both sides, lockstep begins", r.id)
	r.sendJoinResp()
	ticker := time.NewTicker(TickInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-r.done:
			return
		case m := <-r.in:
			if p := r.playerBySide(m.side); p != nil {
				p.lastSeen = r.now()
			}
			r.dispatch(m)
			if r.ended {
				return
			}
		case side := <-r.disc:
			r.onDisconnect(side)
		case req := <-r.reconn:
			r.onReconnect(req)
		case <-ticker.C:
			r.step()
			if r.ended {
				return
			}
		}
	}
}

func (r *Room) dispatch(m inbound) {
	switch m.msgID {
	case pbcommon.MsgId_DEPLOY_CMD:
		var d pbbattle.DeployCmd
		if proto.Unmarshal(m.payload, &d) == nil {
			r.onDeploy(m.side, &d)
		}
	case pbcommon.MsgId_STATE_HASH_UP:
		var h pbbattle.StateHashUp
		if proto.Unmarshal(m.payload, &h) == nil {
			r.onHash(m.side, &h)
		}
	case pbcommon.MsgId_BATTLE_END_REPORT:
		var rep pbbattle.BattleEndReport
		if proto.Unmarshal(m.payload, &rep) == nil {
			r.onEnd(m.side, &rep)
		}
	case pbcommon.MsgId_HEARTBEAT_PING:
		r.onHeartbeat(m.side)
	}
}

func (r *Room) broadcast(msgID pbcommon.MsgId, msg proto.Message) {
	frame := encodeFrame(msgID, msg)
	r.deliver(r.p1, frame)
	r.deliver(r.p2, frame)
}

func (r *Room) sendTo(p *player, msgID pbcommon.MsgId, msg proto.Message) {
	r.deliver(p, encodeFrame(msgID, msg))
}

// deliver pushes a frame without blocking the room loop: a full send buffer
// (slow/stuck client) drops the frame rather than stalling the room. A
// disconnected side is skipped (its channel is orphaned until reconnect swaps
// in a fresh one).
func (r *Room) deliver(p *player, frame []byte) {
	if p == nil || frame == nil || !p.connected {
		return
	}
	select {
	case p.send <- frame:
	default:
	}
}

func encodeFrame(msgID pbcommon.MsgId, msg proto.Message) []byte {
	payload, err := proto.Marshal(msg)
	if err != nil {
		return nil
	}
	out := make([]byte, 2+len(payload))
	binary.BigEndian.PutUint16(out[:2], uint16(msgID))
	copy(out[2:], payload)
	return out
}

func decodeFrame(data []byte) (pbcommon.MsgId, []byte, bool) {
	if len(data) < 2 {
		return 0, nil, false
	}
	return pbcommon.MsgId(binary.BigEndian.Uint16(data[:2])), data[2:], true
}

func bytesEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
