// Package battle implements the V4-S3 lockstep relay: it pairs two clients,
// paces a 10Hz tick loop, bundles each tick's deploy commands and broadcasts
// them so both clients advance their own logic/ in lockstep, compares the
// state hashes the clients report, and finalizes the result the clients claim.
//
// The server runs NO battle simulation (that's the whole point of lockstep —
// no second copy of logic/ in Go). It is a deterministic relay + referee:
// order deploys by tick, broadcast identically to both sides, and trust the
// (cross-checked) client reports for hashes and the final outcome.
package battle

import (
	"context"
	"encoding/binary"
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
)

// player is one side of a room. send carries framed [2B msgid][payload] messages
// out to that client; nil-safe via sendTo.
type player struct {
	accountID int64
	side      int32 // 1 or 2
	deck      []string
	summary   *pbcommon.ProfileSummary
	send      chan []byte
}

// inbound is a decoded client->server message handed to the room loop.
type inbound struct {
	side    int32
	msgID   pbcommon.MsgId
	payload []byte
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

	in   chan inbound
	done chan struct{}

	// The following are touched only from the single run-loop goroutine (or
	// directly by tests), so they need no locking.
	curTick  int32
	pending  map[int32][]*pbbattle.TickBundle_SideDeploy
	hashes   map[int32]map[int32][]byte // tick -> side -> hash
	endRep   map[int32]*pbbattle.BattleEndReport
	ended    bool
	mismatch bool // set if two clients ever report divergent hashes for a tick
}

// NewRoom wires a room. now defaults to time.Now when nil.
func NewRoom(id, levelID string, seed uint64, p1, p2 *player, persist Persister, now func() time.Time) *Room {
	if now == nil {
		now = time.Now
	}
	return &Room{
		id: id, levelID: levelID, seed: seed, p1: p1, p2: p2,
		persist: persist, now: now,
		in:      make(chan inbound, 256),
		done:    make(chan struct{}),
		pending: map[int32][]*pbbattle.TickBundle_SideDeploy{},
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

// sendJoinResp tells both clients the match setup so they build identical
// initial Matches (both decks + level + their side + start tick).
func (r *Room) sendJoinResp() {
	r.started = r.now()
	for _, p := range []*player{r.p1, r.p2} {
		opp := r.p2.summary
		if p.side == 2 {
			opp = r.p1.summary
		}
		resp := &pbbattle.JoinRoomResp{
			Ok:        true,
			Opponent:  opp,
			YourSide:  p.side,
			StartTick: 0,
			Seed:      r.seed,
			Side1Deck: r.p1.deck,
			Side2Deck: r.p2.deck,
			LevelId:   r.levelID,
		}
		r.sendTo(p, pbcommon.MsgId_JOIN_ROOM_RESP, resp)
	}
}

// onDeploy buffers a deploy for its target tick. The tick is clamped to at
// least curTick+1 so a late/past command still lands deterministically in the
// next bundle (both clients receive the same bundle, so determinism holds).
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

// onTick broadcasts the bundle for the current tick (empty bundles included so
// both clients stay tick-synced) and advances curTick.
func (r *Room) onTick() {
	bundle := &pbbattle.TickBundle{Tick: r.curTick, Deploys: r.pending[r.curTick]}
	r.broadcast(pbcommon.MsgId_TICK_BUNDLE, bundle)
	delete(r.pending, r.curTick)
	r.curTick++
}

// onHash records a client's reported hash and, once both sides have reported
// the same tick, compares them. Divergence flags the room (full arbitration is
// deferred to V4-S7; S3 just records it). Returns true if a mismatch was found.
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
		delete(r.hashes, h.Tick) // compared; free it
		return r.mismatch
	}
	return false
}

// onEnd records a client's end-of-match claim. It finalizes once both sides
// have reported (server cross-checks they agree on the winner) or, if only one
// has reported and they disagree, trusts the first valid claim. Returns true
// when the room finalized.
func (r *Room) onEnd(side int32, rep *pbbattle.BattleEndReport) bool {
	if r.ended || rep == nil {
		return false
	}
	r.endRep[side] = rep
	other := r.endRep[3-side]
	if other != nil {
		// Both reported: trust if they agree; on disagreement the lower-trust
		// resolution (S3) is to keep side 1's claim and flag mismatch.
		if other.Winner != rep.Winner {
			r.mismatch = true
		}
		r.finalize(rep)
		return true
	}
	return false
}

// finalize computes trophy deltas, pushes the result to both clients, and
// persists the match. Idempotent: a second call after ended is a no-op.
func (r *Room) finalize(rep *pbbattle.BattleEndReport) {
	if r.ended {
		return
	}
	r.ended = true

	var d1, d2 int32
	var winnerAcc int64
	reason := pbbattle.BattleResultPush_Reason(rep.Reason)
	switch rep.Winner {
	case 1:
		d1, d2 = trophyWin, -trophyWin
		winnerAcc = r.p1.accountID
	case 2:
		d1, d2 = -trophyWin, trophyWin
		winnerAcc = r.p2.accountID
	default: // draw
		d1, d2 = 0, 0
	}

	result := &pbbattle.BattleResultPush{
		Winner:            pbbattle.BattleResultPush_Winner(rep.Winner),
		Reason:            reason,
		Side_1Score:       rep.Side_1Score,
		Side_2Score:       rep.Side_2Score,
		TrophiesDeltaSide_1: d1,
		TrophiesDeltaSide_2: d2,
	}
	r.broadcast(pbcommon.MsgId_BATTLE_RESULT_PUSH, result)

	if r.persist != nil {
		_ = r.persist.SaveMatch(context.Background(), MatchResult{
			P1Account:     r.p1.accountID,
			P2Account:     r.p2.accountID,
			WinnerAccount: winnerAcc,
			Reason:        reason.String(),
			StartedAt:     r.started,
			EndedAt:       r.now(),
			P1Delta:       d1,
			P2Delta:       d2,
		})
	}
	close(r.done)
}

// Run drives the room: a 10Hz ticker advances ticks while inbound client
// messages are dispatched. Returns when the match ends, the cap is hit, or ctx
// is cancelled. Single goroutine → room state needs no locking.
func (r *Room) Run(ctx context.Context) {
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
			r.dispatch(m)
			if r.ended {
				return
			}
		case <-ticker.C:
			r.onTick()
			if r.curTick > maxTicks && !r.ended {
				r.finalize(&pbbattle.BattleEndReport{Winner: 0, Reason: int32(pbbattle.BattleResultPush_TIMEOUT)})
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

// deliver pushes a frame to a player without blocking the room loop: if the
// client's send buffer is full (slow/stuck client) the frame is dropped rather
// than stalling the whole room.
func (r *Room) deliver(p *player, frame []byte) {
	if p == nil || frame == nil {
		return
	}
	select {
	case p.send <- frame:
	default:
	}
}

// encodeFrame builds [2B msgid big-endian][protobuf payload].
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

// decodeFrame splits [2B msgid][payload]. ok=false on a short frame.
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
