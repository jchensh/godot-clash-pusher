package battle

import (
	"context"
	"testing"
	"time"

	pbbattle "github.com/jchensh/godot-clash-pusher/server/internal/pb/battle"
	pbcommon "github.com/jchensh/godot-clash-pusher/server/internal/pb/common"
	"google.golang.org/protobuf/proto"
)

var testDeck = []string{"knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"}

type fakePersister struct{ saved *MatchResult }

func (f *fakePersister) SaveMatch(_ context.Context, m MatchResult) error {
	f.saved = &m
	return nil
}

func newTestRoom(persist Persister) (*Room, *player, *player) {
	p1 := &player{accountID: 100, side: 1, deck: testDeck, summary: &pbcommon.ProfileSummary{AccountId: 100}, send: make(chan []byte, 256)}
	p2 := &player{accountID: 200, side: 2, deck: testDeck, summary: &pbcommon.ProfileSummary{AccountId: 200}, send: make(chan []byte, 256)}
	r := NewRoom("room-test", "ladder_01", 0, p1, p2, persist, func() time.Time { return time.Unix(1700000000, 0) })
	return r, p1, p2
}

func recvFrame(t *testing.T, p *player) (pbcommon.MsgId, []byte) {
	t.Helper()
	select {
	case f := <-p.send:
		mid, pl, ok := decodeFrame(f)
		if !ok {
			t.Fatal("short frame")
		}
		return mid, pl
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for frame")
		return 0, nil
	}
}

func recvBundle(t *testing.T, p *player) *pbbattle.TickBundle {
	t.Helper()
	mid, pl := recvFrame(t, p)
	if mid != pbcommon.MsgId_TICK_BUNDLE {
		t.Fatalf("expected TICK_BUNDLE, got %v", mid)
	}
	var b pbbattle.TickBundle
	if err := proto.Unmarshal(pl, &b); err != nil {
		t.Fatalf("unmarshal bundle: %v", err)
	}
	return &b
}

func TestSendJoinResp(t *testing.T) {
	r, p1, p2 := newTestRoom(nil)
	r.sendJoinResp()

	mid, pl := recvFrame(t, p1)
	if mid != pbcommon.MsgId_JOIN_ROOM_RESP {
		t.Fatalf("p1 got %v", mid)
	}
	var resp pbbattle.JoinRoomResp
	_ = proto.Unmarshal(pl, &resp)
	if resp.YourSide != 1 {
		t.Errorf("p1 side=%d want 1", resp.YourSide)
	}
	if len(resp.Side1Deck) != 8 || len(resp.Side2Deck) != 8 {
		t.Errorf("decks not conveyed: %d/%d", len(resp.Side1Deck), len(resp.Side2Deck))
	}
	if resp.LevelId != "ladder_01" {
		t.Errorf("level=%q", resp.LevelId)
	}

	_, pl2 := recvFrame(t, p2)
	var resp2 pbbattle.JoinRoomResp
	_ = proto.Unmarshal(pl2, &resp2)
	if resp2.YourSide != 2 {
		t.Errorf("p2 side=%d want 2", resp2.YourSide)
	}
	if resp2.Opponent.GetAccountId() != 100 {
		t.Errorf("p2 opponent should be p1 (100), got %d", resp2.Opponent.GetAccountId())
	}
}

func TestDeployBundling(t *testing.T) {
	r, p1, _ := newTestRoom(nil)
	r.onDeploy(1, &pbbattle.DeployCmd{Tick: 3, CardId: "knight", XMilli: 4500, YMilli: 17000})
	for i := 0; i < 5; i++ {
		r.onTick()
	}
	for i := 0; i < 5; i++ {
		b := recvBundle(t, p1)
		if b.Tick == 3 {
			if len(b.Deploys) != 1 || b.Deploys[0].Deploy.CardId != "knight" || b.Deploys[0].Side != 1 {
				t.Errorf("tick 3 should carry the side-1 knight deploy, got %+v", b.Deploys)
			}
		} else if len(b.Deploys) != 0 {
			t.Errorf("tick %d should be empty, got %d deploys", b.Tick, len(b.Deploys))
		}
	}
}

func TestBothSidesDeploySameTick(t *testing.T) {
	r, p1, _ := newTestRoom(nil)
	r.onDeploy(1, &pbbattle.DeployCmd{Tick: 2, CardId: "knight"})
	r.onDeploy(2, &pbbattle.DeployCmd{Tick: 2, CardId: "giant"})
	r.onTick() // 0
	r.onTick() // 1
	r.onTick() // 2
	for i := 0; i < 3; i++ {
		b := recvBundle(t, p1)
		if b.Tick == 2 && len(b.Deploys) != 2 {
			t.Errorf("tick 2 should bundle both deploys, got %d", len(b.Deploys))
		}
	}
}

func TestPastTickClamped(t *testing.T) {
	r, p1, _ := newTestRoom(nil)
	r.onTick() // 0
	r.onTick() // 1
	r.onTick() // 2 -> curTick now 3
	r.onDeploy(2, &pbbattle.DeployCmd{Tick: 0, CardId: "giant"}) // past -> clamp to curTick+1 = 4
	r.onTick() // 3
	r.onTick() // 4
	for i := 0; i < 5; i++ {
		b := recvBundle(t, p1)
		if b.Tick == 4 {
			if len(b.Deploys) != 1 {
				t.Errorf("clamped deploy should land at tick 4, got %d", len(b.Deploys))
			}
		} else if len(b.Deploys) != 0 {
			t.Errorf("tick %d should be empty", b.Tick)
		}
	}
}

func TestHashMatchNoMismatch(t *testing.T) {
	r, _, _ := newTestRoom(nil)
	h := []byte("0123456789abcdef0123456789abcdef")
	r.onHash(1, &pbbattle.StateHashUp{Tick: 10, Hash: h})
	if mm := r.onHash(2, &pbbattle.StateHashUp{Tick: 10, Hash: h}); mm {
		t.Error("equal hashes must not flag mismatch")
	}
	if r.mismatch {
		t.Error("mismatch should be false")
	}
}

func TestHashMismatchFlagged(t *testing.T) {
	r, _, _ := newTestRoom(nil)
	r.onHash(1, &pbbattle.StateHashUp{Tick: 10, Hash: []byte("aaaaaaaa")})
	if mm := r.onHash(2, &pbbattle.StateHashUp{Tick: 10, Hash: []byte("bbbbbbbb")}); !mm {
		t.Error("divergent hashes must flag mismatch")
	}
	if !r.mismatch {
		t.Error("mismatch should be true")
	}
}

func TestEndReportFinalizesAndPersists(t *testing.T) {
	fp := &fakePersister{}
	r, p1, p2 := newTestRoom(fp)

	if r.onEnd(1, &pbbattle.BattleEndReport{Tick: 500, Winner: 1, Reason: int32(pbbattle.BattleResultPush_KING_DESTROYED)}) {
		t.Fatal("should not finalize on first report alone")
	}
	if !r.onEnd(2, &pbbattle.BattleEndReport{Tick: 500, Winner: 1, Reason: int32(pbbattle.BattleResultPush_KING_DESTROYED)}) {
		t.Fatal("should finalize once both sides agree")
	}
	if !r.ended {
		t.Error("room should be ended")
	}

	for _, p := range []*player{p1, p2} {
		mid, pl := recvFrame(t, p)
		if mid != pbcommon.MsgId_BATTLE_RESULT_PUSH {
			t.Fatalf("expected result push, got %v", mid)
		}
		var res pbbattle.BattleResultPush
		_ = proto.Unmarshal(pl, &res)
		if res.Winner != pbbattle.BattleResultPush_SIDE_1 {
			t.Errorf("winner=%v want SIDE_1", res.Winner)
		}
		if res.TrophiesDeltaSide_1 != trophyWin || res.TrophiesDeltaSide_2 != -trophyWin {
			t.Errorf("deltas=%d/%d", res.TrophiesDeltaSide_1, res.TrophiesDeltaSide_2)
		}
	}

	if fp.saved == nil {
		t.Fatal("persister not called")
	}
	if fp.saved.WinnerAccount != 100 {
		t.Errorf("persisted winner=%d want 100", fp.saved.WinnerAccount)
	}
	if fp.saved.P1Delta != trophyWin || fp.saved.P2Delta != -trophyWin {
		t.Errorf("persisted deltas=%d/%d", fp.saved.P1Delta, fp.saved.P2Delta)
	}
}

func TestEndReportDraw(t *testing.T) {
	fp := &fakePersister{}
	r, p1, _ := newTestRoom(fp)
	r.onEnd(1, &pbbattle.BattleEndReport{Winner: 0, Reason: int32(pbbattle.BattleResultPush_TIMEOUT)})
	r.onEnd(2, &pbbattle.BattleEndReport{Winner: 0, Reason: int32(pbbattle.BattleResultPush_TIMEOUT)})

	_, pl := recvFrame(t, p1)
	var res pbbattle.BattleResultPush
	_ = proto.Unmarshal(pl, &res)
	if res.Winner != pbbattle.BattleResultPush_DRAW {
		t.Errorf("winner=%v want DRAW", res.Winner)
	}
	if fp.saved.WinnerAccount != 0 || fp.saved.P1Delta != 0 || fp.saved.P2Delta != 0 {
		t.Errorf("draw should persist no winner / zero deltas, got %+v", fp.saved)
	}
}

func TestEndAfterEndedIsNoop(t *testing.T) {
	fp := &fakePersister{}
	r, _, _ := newTestRoom(fp)
	r.onEnd(1, &pbbattle.BattleEndReport{Winner: 1})
	r.onEnd(2, &pbbattle.BattleEndReport{Winner: 1})
	first := fp.saved
	if r.onEnd(1, &pbbattle.BattleEndReport{Winner: 2}) {
		t.Error("end report after finalize must be ignored")
	}
	if fp.saved != first {
		t.Error("a second finalize must not overwrite persistence")
	}
}
