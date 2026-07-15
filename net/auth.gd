extends RefCounted
##
## 客户端身份层。
## KAN-109（2026-07-15）起主路 = username 裸登录（开发/测试阶段，无凭证；服务器查库
## 判新老玩家，客户端本地数据只当"记住我"）：check_name / login_name / register_name。
## username 与游戏内昵称合一；user://auth.cfg 记 username + token 对。
## V4-S1 匿名 device_id 登录（login()）**保留不删**——正式上线"新设备直进引导"的
## 体验仍有意义，调用点（session.ensure）暂时注释停用，服务端 /v4/auth/login 仍挂载。
##
## 用法:
##   var auth = preload("res://net/auth.gd").new("http://localhost:8080")
##   var http := HTTPRequest.new()
##   add_child(http)                       # HTTPRequest 必须在 SceneTree 里
##   var res = await auth.login_name(http, "陈到叔至")
##   if res.ok:
##       Log.i("logged in, token=%s" % auth.access_token)

const _DEVICE_PATH := "user://device.cfg"
const _AUTH_PATH := "user://auth.cfg"

const _AuthPb := preload("res://net/proto/auth.gd")

var server_url: String = "http://localhost:8080"
var device_id: String = ""
var username: String = ""  # KAN-109：记住我（登录/注册成功后落盘；登出清空）
var access_token: String = ""
var refresh_token: String = ""
var is_new: bool = false   # V5-S9：本次 login 是否首次建号（服务端 LoginResp.is_new）

## Result of login() / refresh(). 不嵌 message 字段, 避免外部代码碰 godobuf 类型.
class Result extends RefCounted:
	var ok: bool = false
	var error: String = ""        # 失败原因 (空=成功)
	var status_code: int = 0      # HTTP 状态码 (0=请求未发出)
	var account_id: int = 0       # 仅 login 成功且服务端回 profile 时填; V4-S1 服务端不回, 暂为 0


func _init(p_server_url: String = "http://localhost:8080") -> void:
	server_url = p_server_url
	device_id = _ensure_device_id()
	_load_tokens()


# ---------------- device_id ----------------

func _ensure_device_id() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(_DEVICE_PATH) == OK:
		var saved: String = cfg.get_value("device", "id", "")
		if saved != "":
			return saved
	# 没存过 -> 生成 + 落盘.
	var fresh := _gen_uuid4()
	cfg.set_value("device", "id", fresh)
	cfg.save(_DEVICE_PATH)
	return fresh


## Generates a RFC 4122 v4 UUID using Godot's RNG.
## (GDScript 标准库没有 UUID, 16 字节随机 + version 4 / variant 10 位拼 8-4-4-4-12 hex.)
static func _gen_uuid4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = rng.randi() & 0xFF
	# RFC 4122 §4.4: version=4 in high nibble of byte 6; variant=10 in top bits of byte 8.
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := ""
	for b in bytes:
		hex += "%02x" % b
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]


# ---------------- token storage ----------------

func _load_tokens() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_AUTH_PATH) != OK:
		return
	access_token = cfg.get_value("auth", "access", "")
	refresh_token = cfg.get_value("auth", "refresh", "")
	username = cfg.get_value("auth", "username", "")


func _save_tokens() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "access", access_token)
	cfg.set_value("auth", "refresh", refresh_token)
	cfg.set_value("auth", "username", username)
	cfg.save(_AUTH_PATH)


func _clear_tokens() -> void:
	access_token = ""
	refresh_token = ""
	username = ""
	if FileAccess.file_exists(_AUTH_PATH):
		DirAccess.remove_absolute(_AUTH_PATH)


## Drop stored tokens + username (but keep device_id; logging back in re-uses it).
func logout() -> void:
	_clear_tokens()


## KAN-109：是否有可用于静默重登的凭据（记住的 username）。
## 服务器权威判新老——这里只决定"要不要弹登录页"，不决定账号存在性。
func has_credentials() -> bool:
	return username != ""


# ---------------- HTTP calls (await-based) ----------------

## Sends LoginReq with current device_id. On success stores access + refresh
## tokens and returns ok=true. `http_req` must already be add_child'd to a
## node in the SceneTree (HTTPRequest's hard constraint).
func login(http_req: HTTPRequest) -> Result:
	var req = _AuthPb.LoginReq.new()
	req.set_device_id(device_id)
	req.set_client_version("0.4.0")
	req.set_platform(OS.get_name().to_lower())  # "windows" / "android" / ...
	var body: PackedByteArray = req.to_bytes()

	var resp := await _post_proto(http_req, "/v4/auth/login", body)
	if not resp.ok:
		var fail := Result.new()
		fail.error = resp.error
		fail.status_code = resp.status_code
		return fail

	var lr = _AuthPb.LoginResp.new()
	if lr.from_bytes(resp.body) != _AuthPb.PB_ERR.NO_ERRORS:
		var fail := Result.new()
		fail.error = "decode LoginResp failed"
		fail.status_code = resp.status_code
		return fail

	access_token = lr.get_token()
	refresh_token = lr.get_refresh_token()
	is_new = lr.get_is_new()   # V5-S9：首次建号 → 客户端进创号流程
	_save_tokens()

	var result := Result.new()
	result.ok = true
	result.status_code = resp.status_code
	# Profile not populated by V4-S1 server; account_id stays 0 until V4-S2.
	return result


## Sends RefreshReq with stored refresh_token. On 401 wipes stored tokens
## (refresh has expired -> user must re-login). On success rotates both tokens.
func refresh(http_req: HTTPRequest) -> Result:
	if refresh_token == "":
		var r := Result.new()
		r.error = "no refresh_token stored"
		return r

	var req = _AuthPb.RefreshReq.new()
	req.set_refresh_token(refresh_token)
	var body: PackedByteArray = req.to_bytes()

	var resp := await _post_proto(http_req, "/v4/auth/refresh", body)
	if not resp.ok:
		if resp.status_code == 401:
			_clear_tokens()
		var fail := Result.new()
		fail.error = resp.error
		fail.status_code = resp.status_code
		return fail

	var rr = _AuthPb.RefreshResp.new()
	if rr.from_bytes(resp.body) != _AuthPb.PB_ERR.NO_ERRORS:
		var fail := Result.new()
		fail.error = "decode RefreshResp failed"
		fail.status_code = resp.status_code
		return fail

	access_token = rr.get_token()
	refresh_token = rr.get_refresh_token()
	_save_tokens()

	var result := Result.new()
	result.ok = true
	result.status_code = resp.status_code
	return result


# ---------------- KAN-109 username 裸登录（JSON 请求 + pb LoginResp 响应）----------------

## 查询 username 是否已注册（服务器查库判新老玩家）。
## 返回 {ok, valid, registered, error}；ok=false 表示网络/服务器错误。
func check_name(http_req: HTTPRequest, p_username: String) -> Dictionary:
	var resp := await _post_json(http_req, "/v5/auth/check-name", {"username": p_username})
	if not resp.ok:
		return {"ok": false, "valid": false, "registered": false, "error": resp.error}
	var d = JSON.parse_string(resp.body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return {"ok": false, "valid": false, "registered": false, "error": "bad check-name json"}
	return {"ok": true, "valid": bool(d.get("valid", false)),
			"registered": bool(d.get("registered", false)), "error": str(d.get("reason", ""))}


## 老玩家按 username 登录。成功存 token+username（记住我）。
func login_name(http_req: HTTPRequest, p_username: String) -> Result:
	return await _name_auth(http_req, "/v5/auth/login-name", {"username": p_username}, p_username)


## 新玩家注册（username+头像，服务器落 accounts+profiles，昵称=username）。
func register_name(http_req: HTTPRequest, p_username: String, avatar_card_id: String) -> Result:
	return await _name_auth(http_req, "/v5/auth/register",
			{"username": p_username, "avatar_card_id": avatar_card_id}, p_username)


## 共用：POST JSON → 解析 pb LoginResp（与 /v4/auth/login 同构复用解析）→ 存凭据。
func _name_auth(http_req: HTTPRequest, path: String, payload: Dictionary, p_username: String) -> Result:
	var resp := await _post_json(http_req, path, payload)
	if not resp.ok:
		var fail := Result.new()
		fail.error = resp.error
		fail.status_code = resp.status_code
		return fail
	var lr = _AuthPb.LoginResp.new()
	if lr.from_bytes(resp.body) != _AuthPb.PB_ERR.NO_ERRORS:
		var fail := Result.new()
		fail.error = "decode LoginResp failed"
		fail.status_code = resp.status_code
		return fail
	access_token = lr.get_token()
	refresh_token = lr.get_refresh_token()
	is_new = lr.get_is_new()
	username = p_username.strip_edges()
	_save_tokens()
	var result := Result.new()
	result.ok = true
	result.status_code = resp.status_code
	return result


# ---------------- internal HTTP plumbing ----------------

class _HttpResult extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var status_code: int = 0
	var body: PackedByteArray = PackedByteArray()


## Internal: POSTs a JSON body（KAN-109 username 端点；响应可能是 JSON 或 pb 二进制）。
func _post_json(http_req: HTTPRequest, path: String, payload: Dictionary) -> _HttpResult:
	var url := server_url + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := http_req.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		var r := _HttpResult.new()
		r.error = "HTTPRequest.request err=%d" % err
		return r
	var args: Array = await http_req.request_completed
	var hr := _HttpResult.new()
	hr.status_code = args[1]
	hr.body = args[3]
	if args[0] != HTTPRequest.RESULT_SUCCESS:
		hr.error = "HTTPRequest.result=%d" % args[0]
		return hr
	if args[1] != 200:
		hr.error = "HTTP %d" % args[1]
		return hr
	hr.ok = true
	return hr


## Internal: POSTs a binary protobuf body. Returns once HTTPRequest emits
## request_completed. http_req must be in a SceneTree before calling.
func _post_proto(http_req: HTTPRequest, path: String, body: PackedByteArray) -> _HttpResult:
	var url := server_url + path
	var headers := PackedStringArray([
		"Content-Type: application/x-protobuf",
		"Accept: application/x-protobuf",
	])
	var err := http_req.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		var r := _HttpResult.new()
		r.error = "HTTPRequest.request_raw err=%d" % err
		return r
	# request_completed (result, response_code, headers, body)
	var args: Array = await http_req.request_completed
	var hr := _HttpResult.new()
	hr.status_code = args[1]
	hr.body = args[3]
	if args[0] != HTTPRequest.RESULT_SUCCESS:
		hr.error = "HTTPRequest.result=%d" % args[0]
		return hr
	if args[1] != 200:
		hr.error = "HTTP %d" % args[1]
		return hr
	hr.ok = true
	return hr
