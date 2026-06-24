package battle

import (
	"context"
	"fmt"
	"sync"
)

// Hub pairs waiting players into rooms. V4-S3 uses the simplest possible
// matchmaking — the first two joiners are matched (real ELO matchmaking is
// V4-S4). Each pair gets a Room running in its own goroutine.
type Hub struct {
	persist Persister
	levelID string

	mu       sync.Mutex
	waiting  *player    // at most one player parked waiting for an opponent
	waitCh   chan *Room // closed/fed when the waiting player is paired
	roomSeq  int
}

func NewHub(persist Persister, levelID string) *Hub {
	return &Hub{persist: persist, levelID: levelID}
}

// Join blocks until the player is paired into a room, then returns it. The
// first caller parks as side 1 and waits; the second caller becomes side 2,
// creates the room, hands it to the waiting player, and starts Room.Run.
func (h *Hub) Join(p *player) *Room {
	h.mu.Lock()
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
	h.mu.Unlock()

	ch <- room // wake the parked side-1 player with the shared room
	go room.Run(context.Background())
	return room
}

// cancelWaiting removes a parked player if they disconnect before being paired
// (so a stale waiter doesn't get matched into a dead connection).
func (h *Hub) cancelWaiting(p *player) {
	h.mu.Lock()
	if h.waiting == p {
		h.waiting = nil
		h.waitCh = nil
	}
	h.mu.Unlock()
}
