extends RefCounted
##
## V4-S1 客户端身份层。三件事:
##   1. device_id (UUID4) 持久化 user://device.cfg, 首次启动生成、设备换不变
##   2. access/refresh token 存盘 user://auth.cfg
##   3. login / refresh 调用封装 (POST + protobuf body, 异步 await)
##
## 用法:
##   var auth = preload("res://net/auth.gd").new("http://localhost:8080")
##   var http := HTTPRequest.new()
##   add_child(http)                       # HTTPRequest 必须在 SceneTree 里
##   var res = await auth.login(http)
##   if res.ok:
##       print("logged in, token=", auth.access_token)
##
## 后续 V4-S2 起的 profile / V4-S3 起的 WS 会复用 auth.access_token 做鉴权。

const _DEVICE_PATH := "user://device.cfg"
const _AUTH_PATH := "user://auth.cfg"

const _AuthPb := preload("res://net/proto/auth.gd")

var server_url: String = "http://localhost:8080"
var device_id: String = ""
var access_token: String = ""
var refresh_token: String = ""

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


func _save_tokens() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "access", access_token)
	cfg.set_value("auth", "refresh", refresh_token)
	cfg.save(_AUTH_PATH)


func _clear_tokens() -> void:
	access_token = ""
	refresh_token = ""
	if FileAccess.file_exists(_AUTH_PATH):
		DirAccess.remove_absolute(_AUTH_PATH)


## Drop stored tokens (but keep device_id; logging back in re-uses it).
func logout() -> void:
	_clear_tokens()


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


# ---------------- internal HTTP plumbing ----------------

class _HttpResult extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var status_code: int = 0
	var body: PackedByteArray = PackedByteArray()


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
