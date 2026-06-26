extends RefCounted
## V5-N3/N4（决策 48）：客户端经济（HTTP，服务器权威）。拉状态 + 升级/升阶/解锁。
## 服务器算成本 + 校验 + 落库（改本地存档/客户端无效）；客户端只展示 + 缓存最近快照。
## HTTPRequest 由 caller 传入（须在 SceneTree）。token = 会话登录令牌（Bearer）。

const EconomyProto = preload("res://net/proto/economy.gd")
const CommonProto = preload("res://net/proto/common.gd")

const CONTENT_TYPE := "application/x-protobuf"

var api_url := "http://localhost:8080"
var state := {}   # 最近一次服务器状态快照（缓存展示）


func _init(url: String = "") -> void:
	if url != "":
		api_url = url


## 拉经济状态（钱包/卡牌养成/关卡进度）。返回 {ok, status_code, state} 或 {ok:false, error...}。
func get_state(http: HTTPRequest, token: String) -> Dictionary:
	return await _request(http, "GET", "/v5/economy/state", token, PackedByteArray())

func upgrade(http: HTTPRequest, token: String, card_id: String) -> Dictionary:
	return await _action(http, "/v5/economy/upgrade", token, card_id)

func rank_up(http: HTTPRequest, token: String, card_id: String) -> Dictionary:
	return await _action(http, "/v5/economy/rank-up", token, card_id)

func unlock(http: HTTPRequest, token: String, card_id: String) -> Dictionary:
	return await _action(http, "/v5/economy/unlock", token, card_id)


func _action(http: HTTPRequest, path: String, token: String, card_id: String) -> Dictionary:
	var req = EconomyProto.EconomyActionReq.new()
	req.set_card_id(card_id)
	return await _request(http, "POST", path, token, req.to_bytes())


func _request(http: HTTPRequest, method: String, path: String, token: String, body: PackedByteArray) -> Dictionary:
	var headers := [
		"Content-Type: " + CONTENT_TYPE,
		"Accept: " + CONTENT_TYPE,
		"Authorization: Bearer " + token,
	]
	var m := HTTPClient.METHOD_POST
	if method == "GET":
		m = HTTPClient.METHOD_GET
	var err := http.request_raw(api_url + path, headers, m, body)
	if err != OK:
		return {"ok": false, "status_code": 0, "error": "request err %d" % err}
	var res = await http.request_completed
	var status: int = res[1]
	var resp_body: PackedByteArray = res[3]
	if status == 200:
		var es = EconomyProto.EconomyState.new()
		if es.from_bytes(resp_body) != EconomyProto.PB_ERR.NO_ERRORS:
			return {"ok": false, "status_code": status, "error": "decode fail"}
		state = _state_to_dict(es)
		return {"ok": true, "status_code": status, "state": state}
	# 非 200：解 ErrorResp（拿业务错误码）
	var ecode := 0
	var er = CommonProto.ErrorResp.new()
	if er.from_bytes(resp_body) == CommonProto.PB_ERR.NO_ERRORS:
		ecode = er.get_code()
	return {"ok": false, "status_code": status, "error_code": ecode}


func _state_to_dict(es) -> Dictionary:
	var cards := {}
	for c in es.get_cards():
		cards[c.get_card_id()] = {
			"level": c.get_level(), "rank": c.get_rank(),
			"shards": c.get_shards(), "unlocked": c.get_unlocked(),
		}
	var stages := {}
	for s in es.get_stages():
		stages[s.get_stage_id()] = {"stars": s.get_stars(), "cleared": s.get_cleared()}
	return {
		"gold": es.get_gold(), "gems": es.get_gems(),
		"idle_last_collect_ts": es.get_idle_last_collect_ts(),
		"highest_cleared": es.get_highest_cleared(),
		"cards": cards, "stages": stages,
	}
