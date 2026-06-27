package battle

import (
	"context"
	"time"

	"github.com/gorilla/websocket"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbmatch "github.com/jchensh/godot-clash-pusher/server/internal/pb/match"
	"google.golang.org/protobuf/proto"
)

const (
	writeWait  = 10 * time.Second
	readWait   = 90 * time.Second // refreshed on every inbound frame (> client heartbeat)
	maxMsgSize = 16 * 1024
)

// Serve runs one WS connection end-to-end. The opening frame decides the path:
//   - FindMatchReq  -> matchmaking (queue by ELO, wait for a pair) -> battle
//   - JoinRoomReq   -> reconnect to the account's live room (V4-S3f)
//
// then it pumps frames between the socket and the battle room until the match
// ends or the connection drops. Blocks until done.
func (l *Lobby) Serve(ctx context.Context, ws *websocket.Conn, accountID int64, summary *pbcommon.ProfileSummary) {
	defer ws.Close()
	ws.SetReadLimit(maxMsgSize)
	_ = ws.SetReadDeadline(time.Now().Add(readWait))

	_, data, err := ws.ReadMessage()
	if err != nil {
		return
	}
	msgID, payload, ok := decodeFrame(data)
	if !ok {
		return
	}

	send := make(chan []byte, 64)
	quit := make(chan struct{})
	writeDone := make(chan struct{})
	go writePump(ws, send, quit, writeDone)
	stop := func() { close(quit); <-writeDone }

	// Read goroutine: forwards every subsequent frame to inbox, closing it on drop.
	inbox := make(chan inbound, 64)
	go readPump(ws, inbox)

	var room *Room
	var side int32

	switch msgID {
	case pbcommon.MsgId_FIND_MATCH_REQ:
		var req pbmatch.FindMatchReq
		if proto.Unmarshal(payload, &req) != nil {
			stop()
			return
		}
		w, err := l.EnterQueue(ctx, accountID, summary, send, req.DeckSlot)
		if err != nil {
			stop()
			return
		}
		// Wait for a match while staying responsive to cancel / disconnect.
		matched := false
		for !matched {
			select {
			case mi := <-w.matched:
				room, side = mi.room, mi.side
				matched = true
			case m, more := <-inbox:
				if !more { // disconnected while queued
					l.LeaveQueue(ctx, accountID)
					stop()
					return
				}
				if m.msgID == pbcommon.MsgId_CANCEL_MATCH_REQ {
					l.LeaveQueue(ctx, accountID)
					send <- encodeFrame(pbcommon.MsgId_CANCEL_MATCH_RESP, &pbmatch.CancelMatchResp{Ok: true})
					stop()
					return
				}
				// ignore other frames while queuing
			case <-ctx.Done():
				l.LeaveQueue(ctx, accountID)
				stop()
				return
			}
		}

	case pbcommon.MsgId_JOIN_ROOM_REQ:
		// Reconnect path: rejoin the account's live room.
		p := &player{accountID: accountID, summary: summary, send: send}
		room = l.Reconnect(p)
		if room == nil {
			stop()
			return
		}
		side = p.side

	default:
		stop()
		return
	}

	// Battle phase. Close the socket on room end / shutdown to unblock readPump.
	go func() {
		select {
		case <-room.done:
			time.Sleep(300 * time.Millisecond) // let the result frame flush
		case <-ctx.Done():
		}
		_ = ws.Close()
	}()

	for m := range inbox {
		select {
		case room.in <- inbound{side: side, msgID: m.msgID, payload: m.payload}:
		case <-room.done:
		}
	}

	// Connection dropped. If the match is still live, open the reconnect window.
	stop()
	if !room.isEnded() {
		select {
		case room.disc <- side:
		case <-room.done:
		}
	}
}

// writePump drains send to the socket. Exits on quit or a write error. send is
// never closed here — the room owns it and may swap it on reconnect.
func writePump(ws *websocket.Conn, send chan []byte, quit, done chan struct{}) {
	defer close(done)
	for {
		select {
		case frame := <-send:
			_ = ws.SetWriteDeadline(time.Now().Add(writeWait))
			if ws.WriteMessage(websocket.BinaryMessage, frame) != nil {
				return
			}
		case <-quit:
			return
		}
	}
}

// readPump decodes every inbound frame into inbox (side filled in by Serve) and
// closes inbox when the socket drops.
func readPump(ws *websocket.Conn, inbox chan inbound) {
	defer close(inbox)
	for {
		_, data, err := ws.ReadMessage()
		if err != nil {
			return
		}
		_ = ws.SetReadDeadline(time.Now().Add(readWait))
		mid, pl, ok := decodeFrame(data)
		if !ok {
			continue
		}
		inbox <- inbound{msgID: mid, payload: pl}
	}
}
