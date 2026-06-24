package battle

import (
	"context"
	"time"

	"github.com/gorilla/websocket"
	pbbattle "github.com/jchensh/godot-clash-pusher/server/internal/pb/battle"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	"google.golang.org/protobuf/proto"
)

const (
	writeWait  = 10 * time.Second
	readWait   = 60 * time.Second // refreshed on every inbound frame
	maxMsgSize = 16 * 1024
)

// Serve runs one battle WS connection end-to-end: read the opening JoinRoomReq,
// pair through the hub, then pump frames between the socket and the room until
// the match ends or the connection drops. Blocks until done; the caller runs
// one Serve per connection (its own goroutine).
func (h *Hub) Serve(ctx context.Context, ws *websocket.Conn, accountID int64, summary *pbcommon.ProfileSummary) {
	defer ws.Close()
	ws.SetReadLimit(maxMsgSize)
	_ = ws.SetReadDeadline(time.Now().Add(readWait))

	// 1. The opening frame must be JoinRoomReq (carries this player's deck).
	_, data, err := ws.ReadMessage()
	if err != nil {
		return
	}
	msgID, payload, ok := decodeFrame(data)
	if !ok || msgID != pbcommon.MsgId_JOIN_ROOM_REQ {
		return
	}
	var jr pbbattle.JoinRoomReq
	if proto.Unmarshal(payload, &jr) != nil {
		return
	}

	p := &player{accountID: accountID, deck: jr.Deck, summary: summary, send: make(chan []byte, 64)}

	// 2. Write pump: drain p.send to the socket.
	writeDone := make(chan struct{})
	go func() {
		defer close(writeDone)
		for frame := range p.send {
			_ = ws.SetWriteDeadline(time.Now().Add(writeWait))
			if ws.WriteMessage(websocket.BinaryMessage, frame) != nil {
				return
			}
		}
	}()

	// 3. Pair (blocks until an opponent arrives). Room.Run is started by side 2.
	room := h.Join(p)

	// 4. Closing the socket on room end / shutdown unblocks the read loop below.
	// On a normal end, give the write pump a brief grace to flush the final
	// BattleResultPush before the socket closes (otherwise the close can race
	// the result frame). Crude but sufficient for S3 玩法验证.
	go func() {
		select {
		case <-room.done:
			time.Sleep(300 * time.Millisecond)
		case <-ctx.Done():
		}
		_ = ws.Close()
	}()

	// 5. Read pump: forward inbound frames to the room until end/disconnect.
	for {
		_, data, err := ws.ReadMessage()
		if err != nil {
			break
		}
		_ = ws.SetReadDeadline(time.Now().Add(readWait))
		mid, pl, ok := decodeFrame(data)
		if !ok {
			continue
		}
		select {
		case room.in <- inbound{side: p.side, msgID: mid, payload: pl}:
		case <-room.done:
		}
	}

	close(p.send)
	<-writeDone
}
