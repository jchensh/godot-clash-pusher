package battle

import (
	"context"
	"fmt"
	"sync"
)

// Hub pairs waiting players into rooms. V4-S3 uses the simplest possible
// matchmaking — the first two joiners are matched (real ELO matchmaking is
// V4-S4). Each pair gets a Room running in its own goroutine. The hub also
// tracks active rooms by account so a dropped player can reconnect (V4-S3f).
type Hub struct {
	persist Persister
	levelID string

	mu      sync.Mutex
	waiting *player         // at most one player parked waiting for an opponent
	waitCh  chan *Room      // fed when the waiting player is paired
	active  map[int64]*Room // accountID -> live room (for reconnect lookup)
	roomSeq int
}

func NewHub(persist Persister, levelID string) *Hub {
	return &Hub{persist: persist, levelID: levelID, active: map[int64]*Room{}}
}

// Join blocks until the player is in a room, then returns it. If the account is
// already in a live room (it dropped and is coming back), it reconnects instead
// of pairing. Otherwise the first caller parks as side 1 and waits; the second
// becomes side 2, creates the room, and starts Room.Run.
func (h *Hub) Join(p *player) *Room {
	h.mu.Lock()

	// Reconnect: this account belongs to a live, unfinished room.
	if room, ok := h.active[p.accountID]; ok && !room.isEnded() {
		p.side = room.sideOf(p.accountID)
		h.mu.Unlock()
		room.reconnect(p)
		return room
	}

	if h.waiting == nil {
		p.side = 1
		ch := make(chan *Room, 1)
		h.waiting = p
		h.waitCh = ch
		h.mu.Unlock()
		return <-ch // unblocked when an opponent arrives
	}

	first := h.waiting
	ch := h.waitCh
	h.waiting = nil
	h.waitCh = nil
	h.roomSeq++
	roomID := fmt.Sprintf("room-%d", h.roomSeq)
	p.side = 2
	room := NewRoom(roomID, h.levelID, 0, first, p, h.persist, nil)
	h.active[first.accountID] = room
	h.active[p.accountID] = room
	h.mu.Unlock()

	ch <- room // wake the parked side-1 player with the shared room
	go room.Run(context.Background())
	go h.reapWhenDone(room, first.accountID, p.accountID)
	return room
}

// reapWhenDone removes a room from the active map once it finalizes, so future
// joins by those accounts pair fresh instead of reconnecting into a dead room.
func (h *Hub) reapWhenDone(room *Room, accA, accB int64) {
	<-room.done
	h.mu.Lock()
	if h.active[accA] == room {
		delete(h.active, accA)
	}
	if h.active[accB] == room {
		delete(h.active, accB)
	}
	h.mu.Unlock()
}

// cancelWaiting removes a parked player if they disconnect before being paired.
func (h *Hub) cancelWaiting(p *player) {
	h.mu.Lock()
	if h.waiting == p {
		h.waiting = nil
		h.waitCh = nil
	}
	h.mu.Unlock()
}
