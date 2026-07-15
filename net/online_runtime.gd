extends Node
## E1：唯一在线运行时（autoload `Online`）。
##
## 持有账号会话、持久 SessionConn、服务器配置快照与经济缓存；场景只经 GameState
## 取得本对象，不再各自建立权威状态。配置/经济均就绪前不进入 ONLINE_READY。

const AccountSessionScript := preload("res://net/session.gd")
const SessionConnScript := preload("res://net/session_conn.gd")
const ConfigLoaderScript := preload("res://logic/config_loader.gd")
const EconomyStateCacheScript := preload("res://net/economy_state_cache.gd")

const BOOT_TIMEOUT_MS := 15_000
const API_RECOVERY_INTERVAL := 2.0

enum State {
	BOOTSTRAP,
	AUTHENTICATING,
	CONNECTING,
	SYNCING,
	ONLINE_READY,
	DEGRADED,
	SIGNED_OUT,
}

signal state_changed(state: int)
signal online_ready(config_version: String)
signal online_lost(reason: String)

var state: int = State.BOOTSTRAP
var last_error := ""
var config_version := ""

var _account
var _connection
var _config
var _economy
var _sync_http: HTTPRequest
var _started := false
var _bootstrapping := false
var _syncing := false
var _recovery_accum := 0.0

var ws_url: String:
	get:
		return _account.ws_url


func _init() -> void:
	_account = AccountSessionScript.new()
	var net := _load_network()
	var session_ws := String(net.get("session_ws_url", "ws://localhost:8081/v5/session/ws"))
	_connection = SessionConnScript.new(session_ws)
	_config = ConfigLoaderScript.new()
	_economy = EconomyStateCacheScript.new(_account.api_url)
	_economy.online_guard = Callable(self, "is_online_ready")
	_economy.transport_failure_reporter = Callable(self, "_on_api_transport_failure")
	_connection.connected.connect(_on_connected)
	_connection.disconnected.connect(_on_disconnected)
	_connection.reconnecting.connect(_on_reconnecting)
	_connection.config_ready.connect(_on_config_ready)
	_connection.config_failed.connect(_on_config_failed)


func _ready() -> void:
	_sync_http = HTTPRequest.new()
	add_child(_sync_http)
	set_process(true)


func _process(delta: float) -> void:
	if _started:
		_connection.poll(delta)
	if state == State.DEGRADED and _connection.is_online() and not _syncing:
		_recovery_accum += delta
		if _recovery_accum >= API_RECOVERY_INTERVAL:
			_recovery_accum = 0.0
			_sync_authoritative_state(_connection.config_version)
	else:
		_recovery_accum = 0.0


## 兼容既有 session.ensure(http) 调用；成功含义升级为“认证+持久连接+配置+经济均 ready”。
## KAN-109：本地无记住的 username → 直接 SIGNED_OUT（调用方跳登录页），不再自动建号。
func ensure(http: HTTPRequest) -> bool:
	if is_online_ready():
		return true
	if _bootstrapping:
		return await _wait_for_ready()
	if _account.needs_login():
		last_error = "needs login"
		_set_state(State.SIGNED_OUT)
		return false
	_bootstrapping = true
	last_error = ""
	_set_state(State.AUTHENTICATING)
	if not await _account.ensure(http):
		last_error = "authentication or profile sync failed"
		_set_state(State.SIGNED_OUT)
		_bootstrapping = false
		return false
	_set_state(State.CONNECTING)
	if not _started:
		_started = true
		_connection.start(_account.token())
	var ok := await _wait_for_ready()
	_bootstrapping = false
	return ok


# —— KAN-109 username 裸登录（登录页专用入口）——

## 是否需要弹登录页。
func needs_login() -> bool:
	return _account.needs_login()


## 查 username 注册状态（服务器权威判新老）。返回 {ok, valid, registered, error}。
func check_name(http: HTTPRequest, p_username: String) -> Dictionary:
	return await _account.check_name(http, p_username)


## 老玩家登录 → 走完整在线引导（认证+连接+配置+经济）。
func login_with_name(http: HTTPRequest, p_username: String) -> bool:
	if not await _account.login_name(http, p_username):
		last_error = "login-name failed"
		_set_state(State.SIGNED_OUT)
		return false
	return await ensure(http)


## 新玩家注册（username+头像）→ 走完整在线引导；后续路由由主菜单按 tutorial_done 判。
func register_with_name(http: HTTPRequest, p_username: String, avatar: String) -> bool:
	if not await _account.register_name(http, p_username, avatar):
		last_error = "register failed"
		_set_state(State.SIGNED_OUT)
		return false
	return await ensure(http)


## 登出（设置页）：清凭据 + 断持久连接 + 状态回 SIGNED_OUT；跳登录页由调用方做。
## 本地经济/存档缓存不清（非权威只读镜像，下个账号登录时被服务器快照整体覆盖）。
func sign_out() -> void:
	_account.sign_out()
	if _started:
		_connection.close()
		_started = false
	config_version = ""
	last_error = "signed out"
	_set_state(State.SIGNED_OUT)
	Log.i("[V5][online] 已登出 → 登录页")


func _wait_for_ready() -> bool:
	var deadline := Time.get_ticks_msec() + BOOT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if is_online_ready():
			return true
		if state == State.SIGNED_OUT:
			return false
		await get_tree().process_frame
	if last_error == "":
		last_error = "online bootstrap timeout"
	_set_state(State.DEGRADED)
	return false


func _on_connected() -> void:
	Log.i("[E1][online] persistent session connected")
	if state != State.ONLINE_READY:
		_set_state(State.CONNECTING)


func _on_disconnected() -> void:
	if _started:
		last_error = "persistent session disconnected"
		Log.w("[E1][online] %s" % last_error)
		_set_state(State.DEGRADED)
		online_lost.emit(last_error)


func _on_reconnecting() -> void:
	if _started:
		_set_state(State.DEGRADED)


func _on_config_ready(version: String) -> void:
	if _syncing:
		return
	_sync_authoritative_state(version)


func _on_config_failed(reason: String) -> void:
	last_error = reason
	Log.w("[E1][online] config failed: %s" % reason)
	_set_state(State.DEGRADED)


func _on_api_transport_failure(reason: String) -> void:
	var was_ready := state == State.ONLINE_READY
	last_error = reason
	if state != State.SIGNED_OUT:
		_set_state(State.DEGRADED)
	if was_ready:
		Log.w("[E1][online] authoritative API lost: %s" % reason)
		online_lost.emit(reason)


func _sync_authoritative_state(version: String) -> void:
	_syncing = true
	_set_state(State.SYNCING)
	if not _config.load_from_files(_connection.config_files):
		last_error = "server config rejected: %s" % "; ".join(_config.errors)
		_set_state(State.DEGRADED)
		_syncing = false
		return
	if _sync_http == null:
		last_error = "online runtime HTTP client unavailable"
		_set_state(State.DEGRADED)
		_syncing = false
		return
	var result: Dictionary = await _economy.refresh(_sync_http, token(), _config.cards.keys())
	if not bool(result.get("ok", false)) or not _connection.is_online():
		last_error = "authoritative economy sync failed"
		_set_state(State.DEGRADED)
		_syncing = false
		return
	config_version = version
	last_error = ""
	_set_state(State.ONLINE_READY)
	_syncing = false
	Log.i("[E1][online] ready cfg=%s" % config_version)
	online_ready.emit(config_version)


func _set_state(value: int) -> void:
	if state == value:
		return
	state = value
	state_changed.emit(state)


func is_online_ready() -> bool:
	return state == State.ONLINE_READY and _connection.is_online() and _economy.is_loaded


func config():
	return _config


func economy():
	return _economy


func token() -> String:
	return _account.token()


func trophies() -> int:
	return _account.trophies()


func is_new() -> bool:
	return _account.is_new()


func nickname() -> String:
	return _account.nickname()


func avatar_card_id() -> String:
	return _account.avatar_card_id()


func tutorial_done() -> bool:
	return _account.tutorial_done()


func needs_account_setup() -> bool:
	return _account.needs_account_setup()


func refresh_profile(http: HTTPRequest) -> void:
	await _account.refresh_profile(http)


func update_identity(http: HTTPRequest, nickname_value: String, avatar_value: String) -> bool:
	if not is_online_ready():
		return false
	return await _account.update_identity(http, nickname_value, avatar_value)


func mark_tutorial_done(http: HTTPRequest) -> bool:
	if not is_online_ready():
		return false
	return await _account.mark_tutorial_done(http)


func save_deck(http: HTTPRequest, slot: int, cards: Array) -> bool:
	if not is_online_ready():
		return false
	return await _account.save_deck(http, slot, cards)


func _load_network() -> Dictionary:
	var f := FileAccess.open("res://config/network.json", FileAccess.READ)
	var d = {}
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			d = parsed
	
	# Web 平台动态 URL 注入支持 (环境无关性)
	if OS.has_feature("web"):
		var js_api = JavaScriptBridge.eval("window.GAME_API_URL")
		var js_ws = JavaScriptBridge.eval("window.GAME_WS_URL")
		var js_session_ws = JavaScriptBridge.eval("window.GAME_SESSION_WS_URL")
		if js_api != null and str(js_api) != "":
			d["api_url"] = str(js_api)
		if js_ws != null and str(js_ws) != "":
			var ws_str = str(js_ws)
			if not ws_str.contains("/v4/"):
				if ws_str.ends_with("/"):
					ws_str = ws_str + "v4/battle/ws"
				else:
					ws_str = ws_str + "/v4/battle/ws"
			d["ws_url"] = ws_str
		if js_session_ws != null and str(js_session_ws) != "":
			var sws_str = str(js_session_ws)
			if not sws_str.contains("/v5/"):
				if sws_str.ends_with("/"):
					sws_str = sws_str + "v5/session/ws"
				else:
					sws_str = sws_str + "/v5/session/ws"
			d["session_ws_url"] = sws_str
			
	return d
