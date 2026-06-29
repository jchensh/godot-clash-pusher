package battle

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/jchensh/godot-clash-pusher/server/internal/matchmaking"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbmatch "github.com/jchensh/godot-clash-pusher/server/internal/pb/match"
	"github.com/jchensh/godot-clash-pusher/server/internal/store"
)

const matchTickInterval = 1 * time.Second

// ladderDefaultDeck backs a player who has no saved deck in the chosen slot
// (e.g. a fresh account). Matches V4-S2 decision 3.
var ladderDefaultDeck = []string{"knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"}

// waiter is a connection parked in matchmaking, waiting to be paired.
type waiter struct {
	accountID int64
	summary   *pbcommon.ProfileSummary
	send      chan []byte
	deckSlot  int32
	matched   chan matchInfo // buffered(1); fed when paired
}

type matchInfo struct {
	room *Room
	side int32
}

// Lobby replaces the S3 Hub: matchmaking by hidden ELO (Redis ZSET + Matcher)
// instead of "first two joiners", plus room creation and reconnect tracking.
type Lobby struct {
	queue   matchmaking.Queue
	matcher *matchmaking.Matcher
	persist Persister
	db      *store.DB
	levelID string
	now     func() time.Time

	mu      sync.Mutex
	waiting map[int64]*waiter // queued, awaiting a match
	active  map[int64]*Room   // in a live room (for reconnect lookup)
	roomSeq int
}

func NewLobby(queue matchmaking.Queue, persist Persister, db *store.DB, levelID string, now func() time.Time) *Lobby {
	if now == nil {
		now = time.Now
	}
	return &Lobby{
		queue:   queue,
		matcher: matchmaking.NewMatcher(queue, now),
		persist: persist,
		db:      db,
		levelID: levelID,
		now:     now,
		waiting: map[int64]*waiter{},
		active:  map[int64]*Room{},
	}
}

// EnterQueue reads the player's rating and adds them to the matchmaking queue,
// returning a waiter the caller blocks on (waiter.matched) until paired.
func (l *Lobby) EnterQueue(ctx context.Context, accountID int64, summary *pbcommon.ProfileSummary, send chan []byte, deckSlot int32) (*waiter, error) {
	mmr, err := l.readRating(ctx, accountID)
	if err != nil {
		return nil, err
	}
	w := &waiter{accountID: accountID, summary: summary, send: send, deckSlot: deckSlot, matched: make(chan matchInfo, 1)}
	l.mu.Lock()
	l.waiting[accountID] = w
	l.mu.Unlock()
	if err := l.queue.Add(ctx, matchmaking.Entry{AccountID: accountID, MMR: mmr, DeckSlot: deckSlot, JoinedAt: l.now()}); err != nil {
		l.LeaveQueue(ctx, accountID)
		return nil, err
	}
	log.Printf("mm: queued acc=%d mmr=%d slot=%d", accountID, mmr, deckSlot)
	return w, nil
}

// LeaveQueue cancels matchmaking for an account (cancel or disconnect while queued).
func (l *Lobby) LeaveQueue(ctx context.Context, accountID int64) {
	l.mu.Lock()
	_, was := l.waiting[accountID]
	delete(l.waiting, accountID)
	l.mu.Unlock()
	_ = l.queue.Remove(ctx, accountID)
	if was {
		log.Printf("mm: left queue acc=%d", accountID)
	}
}

// RunMatchmaker pairs waiting players on a short interval until ctx is done.
func (l *Lobby) RunMatchmaker(ctx context.Context) {
	t := time.NewTicker(matchTickInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			l.matchTick(ctx)
		}
	}
}

// matchTick runs one pairing pass (exported-ish for tests via the same package).
func (l *Lobby) matchTick(ctx context.Context) {
	pairs, err := l.matcher.FindPairs(ctx)
	if err != nil {
		return
	}
	for _, p := range pairs {
		l.createMatch(ctx, p)
	}
}

// createMatch turns a paired (accountID) tuple into a live Room: load both
// decks, build the room, push MatchFoundPush, and signal both waiters.
func (l *Lobby) createMatch(ctx context.Context, pair matchmaking.Pair) {
	l.mu.Lock()
	wa := l.waiting[pair.A.AccountID]
	wb := l.waiting[pair.B.AccountID]
	if wa == nil || wb == nil {
		// One left (cancel/disconnect) between FindPairs and here. Re-queue the
		// survivor so it gets matched next tick; drop the missing one.
		l.mu.Unlock()
		log.Printf("mm: pair %d/%d dropped before room (one left queue), requeue survivor (a=%v b=%v)",
			pair.A.AccountID, pair.B.AccountID, wa != nil, wb != nil)
		if wa != nil {
			_ = l.queue.Add(ctx, pair.A)
		}
		if wb != nil {
			_ = l.queue.Add(ctx, pair.B)
		}
		return
	}
	delete(l.waiting, pair.A.AccountID)
	delete(l.waiting, pair.B.AccountID)
	l.roomSeq++
	roomID := fmt.Sprintf("room-%d", l.roomSeq)
	l.mu.Unlock()

	p1 := &player{accountID: wa.accountID, side: 1, deck: l.lookupDeck(ctx, wa.accountID, wa.deckSlot), summary: wa.summary, send: wa.send}
	p2 := &player{accountID: wb.accountID, side: 2, deck: l.lookupDeck(ctx, wb.accountID, wb.deckSlot), summary: wb.summary, send: wb.send}
	room := NewRoom(roomID, l.levelID, 0, p1, p2, l.persist, l.now)
	log.Printf("mm: room %s ready: side1 acc=%d deck=%dcards | side2 acc=%d deck=%dcards",
		roomID, p1.accountID, len(p1.deck), p2.accountID, len(p2.deck))

	l.mu.Lock()
	l.active[wa.accountID] = room
	l.active[wb.accountID] = room
	l.mu.Unlock()

	log.Printf("mm: matched acc=%d(mmr %d) vs acc=%d(mmr %d) -> %s", pair.A.AccountID, pair.A.MMR, pair.B.AccountID, pair.B.MMR, roomID)
	pushMatchFound(p1, wb.summary, roomID)
	pushMatchFound(p2, wa.summary, roomID)
	wa.matched <- matchInfo{room: room, side: 1}
	wb.matched <- matchInfo{room: room, side: 2}

	go room.Run(context.Background())
	go l.reapWhenDone(room, wa.accountID, wb.accountID)
}

// Reconnect attaches a fresh connection back to the account's live room (the
// JoinRoomReq path). Returns nil if there's no live room to rejoin.
func (l *Lobby) Reconnect(p *player) *Room {
	l.mu.Lock()
	room := l.active[p.accountID]
	l.mu.Unlock()
	if room == nil || room.isEnded() {
		return nil
	}
	p.side = room.sideOf(p.accountID)
	room.reconnect(p)
	return room
}

func (l *Lobby) reapWhenDone(room *Room, accA, accB int64) {
	<-room.done
	l.mu.Lock()
	if l.active[accA] == room {
		delete(l.active, accA)
	}
	if l.active[accB] == room {
		delete(l.active, accB)
	}
	l.mu.Unlock()
}

func (l *Lobby) readRating(ctx context.Context, accountID int64) (int, error) {
	var r int
	if err := l.db.Pool.QueryRow(ctx,
		`SELECT rating FROM profiles WHERE account_id = $1`, accountID).Scan(&r); err != nil {
		return 0, fmt.Errorf("read rating acc=%d: %w", accountID, err)
	}
	return r, nil
}

// lookupDeck returns the player's saved deck for the slot, or the ladder default
// if none is saved (fresh account). Never errors the match — falls back instead.
func (l *Lobby) lookupDeck(ctx context.Context, accountID int64, slot int32) []string {
	var raw []byte
	if err := l.db.Pool.QueryRow(ctx,
		`SELECT card_ids FROM decks WHERE account_id = $1 AND slot = $2`, accountID, slot).Scan(&raw); err != nil {
		log.Printf("mm: acc=%d slot=%d no saved deck -> ladder default", accountID, slot)
		return ladderDefaultDeck
	}
	var cards []string
	if json.Unmarshal(raw, &cards) != nil || len(cards) == 0 {
		log.Printf("mm: acc=%d slot=%d deck unreadable -> ladder default", accountID, slot)
		return ladderDefaultDeck
	}
	return cards
}

func pushMatchFound(p *player, opponent *pbcommon.ProfileSummary, roomID string) {
	frame := encodeFrame(pbcommon.MsgId_MATCH_FOUND_PUSH, &pbmatch.MatchFoundPush{
		RoomId:   roomID,
		Opponent: opponent,
		YourSide: p.side,
		Arena:    1,
		Seed:     0,
	})
	select {
	case p.send <- frame:
	default:
	}
}
