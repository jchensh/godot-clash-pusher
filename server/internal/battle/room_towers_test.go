package battle

// K5（DESIGN_KINGDOM）：JoinRoomResp 携带双方王国城防塔加成（两端同收、重连重放同带）。

import (
	"testing"

	pbbattle "github.com/jchensh/godot-clash-pusher/server/internal/pb/battle"
	"google.golang.org/protobuf/proto"
)

func TestJoinRespCarriesTowerBonus(t *testing.T) {
	r, p1, p2 := newTestRoom(nil)
	r.p1.towers = &pbbattle.TowerBonus{HpPct: 30, DmgPct: 20}
	// p2 无城防（nil）→ resp 缺省，客户端按白板注入。
	r.sendJoinResp()

	for _, p := range []*player{p1, p2} {
		_, pl := recvFrame(t, p)
		var resp pbbattle.JoinRoomResp
		_ = proto.Unmarshal(pl, &resp)
		if resp.Side1Towers == nil || resp.Side1Towers.HpPct != 30 || resp.Side1Towers.DmgPct != 20 {
			t.Fatalf("side %d: side1 towers not conveyed: %+v", p.side, resp.Side1Towers)
		}
		if resp.Side2Towers != nil {
			t.Fatalf("side %d: side2 towers should be nil (no kingdom defense), got %+v", p.side, resp.Side2Towers)
		}
	}

	// 重连重放：新连接收到的 JoinRoomResp 仍带城防（与 progress 同语义）。
	r.onDisconnect(1)
	newSend := make(chan []byte, 256)
	r.onReconnect(reconnReq{side: 1, send: newSend})
	_, pl := recvFrameCh(t, newSend)
	var resp pbbattle.JoinRoomResp
	_ = proto.Unmarshal(pl, &resp)
	if resp.Side1Towers == nil || resp.Side1Towers.HpPct != 30 {
		t.Fatalf("reconnect: side1 towers lost: %+v", resp.Side1Towers)
	}
}
