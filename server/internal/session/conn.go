package session

import (
	"context"
	"encoding/binary"
	"log"
	"time"

	"github.com/gorilla/websocket"
	"github.com/jchensh/godot-clash-pusher/server/internal/gameconfig"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	pbsession "github.com/jchensh/godot-clash-pusher/server/internal/pb/session"
	"google.golang.org/protobuf/proto"
)

const (
	writeWait  = 10 * time.Second
	readWait   = 60 * time.Second // > client heartbeat interval (~5s)；超时无帧 → 判掉线
	maxInbound = 4 * 1024         // client→server 帧很小（心跳）；config 是 server→client，不受此限
)

// Serve runs one persistent session connection until the socket drops or the
// session is evicted by a newer login. On connect it pushes the config bundle
// (conditionally on clientCfgVer, V5-N2), then heartbeats (PING→PONG). Blocks until done.
func (m *Manager) Serve(ctx context.Context, ws *websocket.Conn, accountID int64, clientCfgVer string, bundle *gameconfig.Bundle) {
	defer ws.Close()
	ws.SetReadLimit(maxInbound)
	_ = ws.SetReadDeadline(time.Now().Add(readWait))

	s := newSession(accountID)
	if old := m.register(s); old != nil {
		log.Printf("session: acc=%d evicting older connection", accountID)
		old.stop()
	}
	defer m.unregister(s)
	defer s.stop()

	// Close the socket when this session stops (eviction / shutdown) to unblock ReadMessage.
	go func() {
		select {
		case <-s.quit:
		case <-ctx.Done():
		}
		_ = ws.Close()
	}()

	// V5-N2: push config on connect (skip bundle if client's cached version matches).
	trySend(s.send, encodeFrame(pbcommon.MsgId_CONFIG_PUSH, buildConfigPush(clientCfgVer, bundle)))

	writeDone := make(chan struct{})
	go writePump(ws, s.send, s.quit, writeDone)

	// Read loop: PING → PONG; any frame refreshes the read deadline (heartbeat liveness).
	for {
		_, data, err := ws.ReadMessage()
		if err != nil {
			break
		}
		_ = ws.SetReadDeadline(time.Now().Add(readWait))
		if mid, _, ok := decodeFrame(data); ok && mid == pbcommon.MsgId_PING {
			trySend(s.send, encodeFrame(pbcommon.MsgId_PONG, nil))
		}
	}
	s.stop()
	<-writeDone
}

// buildConfigPush returns up_to_date (no bundle) when the client's version matches,
// else the full versioned bundle. nil bundle → empty push (config load failed upstream).
func buildConfigPush(clientVer string, bundle *gameconfig.Bundle) proto.Message {
	if bundle == nil {
		return &pbsession.ConfigPush{}
	}
	if clientVer != "" && clientVer == bundle.Version {
		return &pbsession.ConfigPush{Version: bundle.Version, UpToDate: true}
	}
	return &pbsession.ConfigPush{Version: bundle.Version, Bundle: bundle.Payload}
}

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

func trySend(ch chan []byte, frame []byte) {
	select {
	case ch <- frame:
	default:
	}
}

// —— frame codec（与 battle 一致：[2B msgid 大端][protobuf payload]）——

func encodeFrame(msgID pbcommon.MsgId, msg proto.Message) []byte {
	var payload []byte
	if msg != nil {
		payload, _ = proto.Marshal(msg)
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
