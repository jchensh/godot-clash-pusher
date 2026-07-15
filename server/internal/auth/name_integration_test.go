package auth_test

// KAN-109 username 裸登录集成测（真 PG）：check-name / register / login-name 全链，
// 服务器判新老玩家（不看客户端本地）、重名拒绝、未注册登录拒绝、profile 落库对帐。

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"testing"

	pbauth "github.com/jchensh/godot-clash-pusher/server/internal/pb/auth"
	"google.golang.org/protobuf/proto"
)

func postJSON(t *testing.T, url string, payload map[string]any) (int, []byte) {
	t.Helper()
	body, _ := json.Marshal(payload)
	resp, err := http.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST %s: %v", url, err)
	}
	defer resp.Body.Close()
	out, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, out
}

func decodeCheck(t *testing.T, body []byte) (valid, registered bool) {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(body, &m); err != nil {
		t.Fatalf("check-name json: %v (%s)", err, body)
	}
	v, _ := m["valid"].(bool)
	r, _ := m["registered"].(bool)
	return v, r
}

func decodeLogin(t *testing.T, body []byte) *pbauth.LoginResp {
	t.Helper()
	var lr pbauth.LoginResp
	if err := proto.Unmarshal(body, &lr); err != nil {
		t.Fatalf("unmarshal LoginResp: %v", err)
	}
	return &lr
}

func TestNameAuth_FullFlow(t *testing.T) {
	db, srv, ctx := setupIntegration(t)

	// ① 未注册：check 判定 registered=false（服务器权威判新老）
	status, body := postJSON(t, srv.URL+"/v5/auth/check-name", map[string]any{"username": "陈到叔至"})
	if status != 200 {
		t.Fatalf("check status=%d", status)
	}
	if valid, registered := decodeCheck(t, body); !valid || registered {
		t.Fatalf("fresh name: want valid && !registered, got valid=%v registered=%v", valid, registered)
	}

	// ② 未注册直接 login-name → 404
	status, _ = postJSON(t, srv.URL+"/v5/auth/login-name", map[string]any{"username": "陈到叔至"})
	if status != http.StatusNotFound {
		t.Fatalf("login unregistered: want 404, got %d", status)
	}

	// ③ 注册（带头像）→ LoginResp is_new=true + token 可用
	status, body = postJSON(t, srv.URL+"/v5/auth/register",
		map[string]any{"username": "陈到叔至", "avatar_card_id": "knight"})
	if status != 200 {
		t.Fatalf("register status=%d body=%s", status, body)
	}
	lr := decodeLogin(t, body)
	if !lr.IsNew || lr.Token == "" || lr.RefreshToken == "" {
		t.Fatalf("register resp: is_new=%v token empty=%v", lr.IsNew, lr.Token == "")
	}

	// ④ profile 落库对帐：nickname=username（合一）+ avatar 已选 + tutorial 未做
	var nick, avatar string
	var tutorial bool
	err := db.Pool.QueryRow(ctx, `
		SELECT p.nickname, p.avatar_card_id, p.tutorial_done FROM profiles p
		JOIN accounts a ON a.id = p.account_id
		WHERE a.provider = 'name' AND a.external_id = '陈到叔至'
	`).Scan(&nick, &avatar, &tutorial)
	if err != nil {
		t.Fatalf("profile row: %v", err)
	}
	if nick != "陈到叔至" || avatar != "knight" || tutorial {
		t.Fatalf("profile mismatch: nick=%q avatar=%q tutorial=%v", nick, avatar, tutorial)
	}

	// ⑤ 重名注册 → 409
	status, _ = postJSON(t, srv.URL+"/v5/auth/register",
		map[string]any{"username": "陈到叔至", "avatar_card_id": "archer"})
	if status != http.StatusConflict {
		t.Fatalf("dup register: want 409, got %d", status)
	}

	// ⑥ check 现在判老玩家
	_, body = postJSON(t, srv.URL+"/v5/auth/check-name", map[string]any{"username": "陈到叔至"})
	if valid, registered := decodeCheck(t, body); !valid || !registered {
		t.Fatalf("after register: want valid && registered, got %v %v", valid, registered)
	}

	// ⑦ 老玩家 login-name → is_new=false（客户端据此直进主界面）
	status, body = postJSON(t, srv.URL+"/v5/auth/login-name", map[string]any{"username": "陈到叔至"})
	if status != 200 {
		t.Fatalf("login status=%d", status)
	}
	if lr2 := decodeLogin(t, body); lr2.IsNew || lr2.Token == "" {
		t.Fatalf("login resp: want is_new=false + token, got is_new=%v", lr2.IsNew)
	}
}

func TestNameAuth_InvalidNames(t *testing.T) {
	_, srv, _ := setupIntegration(t)

	// check-name 对非法名返回 valid=false（200，客户端预检提示用）
	_, body := postJSON(t, srv.URL+"/v5/auth/check-name", map[string]any{"username": "   "})
	if valid, _ := decodeCheck(t, body); valid {
		t.Fatalf("blank name should be invalid")
	}

	// register 对非法名 400；缺头像 400
	status, _ := postJSON(t, srv.URL+"/v5/auth/register",
		map[string]any{"username": "这是一个远远超过十个全角字符宽度上限的名字", "avatar_card_id": "knight"})
	if status != http.StatusBadRequest {
		t.Fatalf("overlong register: want 400, got %d", status)
	}
	status, _ = postJSON(t, srv.URL+"/v5/auth/register", map[string]any{"username": "合法名字"})
	if status != http.StatusBadRequest {
		t.Fatalf("no avatar: want 400, got %d", status)
	}
}

func TestNameAuth_DeviceLoginStillMounted(t *testing.T) {
	// V4-S1 匿名 device 登录保留（用户决策：客户端注释、服务端不动）。
	_, srv, _ := setupIntegration(t)
	req := &pbauth.LoginReq{DeviceId: "dev-keep-alive", ClientVersion: "0.4.0", Platform: "test"}
	status, body := postProto(t, srv.URL+"/v4/auth/login", req)
	if status != 200 {
		t.Fatalf("device login should stay working, got %d", status)
	}
	if lr := decodeLogin(t, body); lr.Token == "" {
		t.Fatalf("device login token empty")
	}
}
