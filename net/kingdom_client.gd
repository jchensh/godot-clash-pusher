extends RefCounted
## K2（DESIGN_KINGDOM，决策 48）：王国领地客户端（HTTP + protobuf，服务器权威）。
## 拉状态 + 建造/升级 + 收取 + 加速。服务器算成本/上限/计时/产出（改本地无效）；
## 客户端只收发数据 + 展示（用户拍板 2026-07-19：服务器权威为永久原则）。
## HTTPRequest 由 caller 传入（须在 SceneTree）。token = 会话登录令牌（Bearer）。

const KingdomProto = preload("res://net/proto/kingdom.gd")
const CommonProto = preload("res://net/proto/common.gd")

const CONTENT_TYPE := "application/x-protobuf"

var api_url := "http://localhost:8080"
var request_timeout_s := 5.0   # E1 同款：权威 API 不可用时有界失败，禁止无限 await


func _init(url: String = "") -> void:
	if url != "":
		api_url = url


## 拉王国状态（资源/建筑/施工计时/可收取预估）。返回 {ok, status_code, state} 或 {ok:false,...}。
func get_state(http: HTTPRequest, token: String) -> Dictionary:
	return await _request(http, "GET", "/v5/kingdom/state", token, PackedByteArray())

## 建造/升级（Lv0→1 即建造，统一动作）。服务器校验 王城门/章节门/工匠队/资源 后落库。
func upgrade(http: HTTPRequest, token: String, building: String) -> Dictionary:
	return await _action(http, "/v5/kingdom/upgrade", token, building)

## 收取全部产出（粮草/木石入仓封顶；铸币坊金币进主钱包）。now 全服务器定。
func collect(http: HTTPRequest, token: String) -> Dictionary:
	return await _action(http, "/v5/kingdom/collect", token, "")

## 宝石加速完成施工（定价 = 剩余时长 × 配置费率，服务器算）。
func speedup(http: HTTPRequest, token: String, building: String) -> Dictionary:
	return await _action(http, "/v5/kingdom/speedup", token, building)


## 王国 GM（开发作弊，镜像 economy gm_apply）：JSON 请求 / KingdomState proto 响应。
## ops = {add_resources: {food:N, wood:N}, finish_builds: bool, reset: bool}。
func gm_apply(http: HTTPRequest, token: String, ops: Dictionary) -> Dictionary:
	http.timeout = request_timeout_s
	var headers := [
		"Content-Type: application/json",
		"Accept: " + CONTENT_TYPE,
		"Authorization: Bearer " + token,
	]
	var body := JSON.stringify(ops).to_utf8_buffer()
	var err := http.request_raw(api_url + "/v5/kingdom/gm", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		return {"ok": false, "status_code": 0, "error": "request err %d" % err}
	var res = await http.request_completed
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status_code": 0, "error": "request failed %d" % int(res[0])}
	var status: int = res[1]
	var resp_body: PackedByteArray = res[3]
	if status == 200:
		var ks = KingdomProto.KingdomState.new()
		if ks.from_bytes(resp_body) != KingdomProto.PB_ERR.NO_ERRORS:
			return {"ok": false, "status_code": status, "error": "decode fail"}
		return {"ok": true, "status_code": status, "state": state_to_dict(ks)}
	var ecode := 0
	var er = CommonProto.ErrorResp.new()
	if er.from_bytes(resp_body) == CommonProto.PB_ERR.NO_ERRORS:
		ecode = er.get_code()
	return {"ok": false, "status_code": status, "error_code": ecode}


func _action(http: HTTPRequest, path: String, token: String, building: String) -> Dictionary:
	var req = KingdomProto.KingdomActionReq.new()
	req.set_building(building)
	return await _request(http, "POST", path, token, req.to_bytes())


func _request(http: HTTPRequest, method: String, path: String, token: String, body: PackedByteArray) -> Dictionary:
	http.timeout = request_timeout_s
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
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status_code": 0, "error": "request failed %d" % int(res[0])}
	var status: int = res[1]
	var resp_body: PackedByteArray = res[3]
	if status == 200:
		var ks = KingdomProto.KingdomState.new()
		if ks.from_bytes(resp_body) != KingdomProto.PB_ERR.NO_ERRORS:
			return {"ok": false, "status_code": status, "error": "decode fail"}
		return {"ok": true, "status_code": status, "state": state_to_dict(ks)}
	var ecode := 0
	var er = CommonProto.ErrorResp.new()
	if er.from_bytes(resp_body) == CommonProto.PB_ERR.NO_ERRORS:
		ecode = er.get_code()
	return {"ok": false, "status_code": status, "error_code": ecode}


## pb → 平面字典（缓存/UI 消费形状；static 便于单测）。
static func state_to_dict(ks) -> Dictionary:
	var resources := {}
	for r in ks.get_resources():
		resources[r.get_resource()] = int(r.get_amount())
	var buildings := {}
	for b in ks.get_buildings():
		buildings[b.get_building()] = {
			"level": int(b.get_level()),
			"upgrade_end_ts": int(b.get_upgrade_end_ts()),
		}
	var pending := {}
	for p in ks.get_pending():
		pending[p.get_resource()] = int(p.get_amount())
	return {
		"resources": resources,
		"buildings": buildings,
		"server_now_ts": int(ks.get_server_now_ts()),
		"pending": pending,
		"pending_gold": int(ks.get_pending_gold()),
	}
