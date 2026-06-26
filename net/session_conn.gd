extends RefCounted
## V5-N1/N2（决策 48）：持久会话连接 + 登录后配置下发。
##
## 流程：上层登录拿 token → start(token) → 连 /v5/session/ws?token=&cfgver=
##   → 服务器推 ConfigPush（配置入内存 + 薄缓存）→ 每帧 poll() 心跳 → 断线自动重连。
## 断线即不可玩：connected_flag=false 时上层应挡操作；重连窗口耗尽 → 回登录。
## 配置非权威：客户端只缓存展示/战斗计算用，服务器为唯一源（cfgver 比对，版本不符重拉）。

const WSClient = preload("res://net/ws_client.gd")
const SessionProto = preload("res://net/proto/session.gd")

# MsgId（与 proto/common.proto 对齐）
const MSG_PING := 1
const MSG_PONG := 2
const MSG_CONFIG_PUSH := 60

const HEARTBEAT_INTERVAL := 5.0
const RECONNECT_INTERVAL := 2.0
const RECONNECT_WINDOW := 60.0

signal config_ready(version: String)   # 配置就绪（首次/更新/缓存命中）
signal connected
signal disconnected
signal reconnecting

var ws_url := "ws://localhost:8081/v5/session/ws"
var cache_path := "user://config_cache.json"
var config_version := ""
var config_files := {}                  # {filename: 解析后的 Variant}
var connected_flag := false

var _ws
var _token := ""
var _pending_cfgver := ""
var _hb_accum := 0.0
var _reconnect := false
var _reconnect_accum := 0.0
var _reconnect_elapsed := 0.0


func _init(url: String = "") -> void:
	if url != "":
		ws_url = url
	_ws = WSClient.new()
	_ws.frame_received.connect(_on_frame)
	_ws.opened.connect(_on_opened)
	_ws.closed.connect(_on_closed)


## 用已登录的 token 建立持久会话连接。
func start(token: String) -> void:
	_token = token
	var cache := _load_cache()
	_pending_cfgver = String(cache.get("version", ""))
	# 先用本地缓存填上（秒启动展示，等服务器确认/更新覆盖）
	config_version = _pending_cfgver
	var cf = cache.get("files", {})
	config_files = cf if typeof(cf) == TYPE_DICTIONARY else {}
	_connect()


func _connect() -> void:
	var url := "%s?token=%s&cfgver=%s" % [ws_url, _token.uri_encode(), _pending_cfgver.uri_encode()]
	_ws.connect_to(url)


## 每帧调用：推进 WS + 心跳 + 重连。
func poll(delta: float) -> void:
	_ws.poll()
	if connected_flag:
		_hb_accum += delta
		if _hb_accum >= HEARTBEAT_INTERVAL:
			_hb_accum = 0.0
			_ws.send_frame(MSG_PING, PackedByteArray())
	elif _reconnect:
		_reconnect_elapsed += delta
		_reconnect_accum += delta
		if _reconnect_elapsed >= RECONNECT_WINDOW:
			_reconnect = false   # 放弃 → 上层应回登录
		elif _reconnect_accum >= RECONNECT_INTERVAL:
			_reconnect_accum = 0.0
			_connect()


func close() -> void:
	_reconnect = false
	if _ws != null:
		_ws.close()


func is_online() -> bool:
	return connected_flag


func get_file(name: String) -> Dictionary:
	var f = config_files.get(name, {})
	return f if typeof(f) == TYPE_DICTIONARY else {}


func _on_opened() -> void:
	connected_flag = true
	_reconnect = false
	_reconnect_elapsed = 0.0
	_hb_accum = 0.0
	connected.emit()


func _on_closed() -> void:
	connected_flag = false
	if not _reconnect:
		_reconnect = true
		_reconnect_accum = 0.0
		_reconnect_elapsed = 0.0
		reconnecting.emit()
	disconnected.emit()


func _on_frame(msg_id: int, payload: PackedByteArray) -> void:
	if msg_id == MSG_CONFIG_PUSH:
		_handle_config_push(payload)
	# PONG(2) 忽略：仅用于刷新服务器侧 read deadline


# 处理配置下发：up_to_date → 用本地缓存；否则解析全量 bundle、入内存 + 写薄缓存。
func _handle_config_push(payload: PackedByteArray) -> void:
	var cp = SessionProto.ConfigPush.new()
	if cp.from_bytes(payload) != SessionProto.PB_ERR.NO_ERRORS:
		return
	var ver := String(cp.get_version())
	if cp.get_up_to_date():
		config_version = ver
		config_ready.emit(ver)   # 缓存已最新（start 时已填 config_files）
		return
	var files := _parse_bundle(cp.get_bundle())
	if files.is_empty():
		return
	config_version = ver
	config_files = files
	_save_cache(ver, files)
	config_ready.emit(ver)


# bundle = JSON {filename: <json value>}；JSON.parse 已递归解析各文件内容。
func _parse_bundle(bytes: PackedByteArray) -> Dictionary:
	var data = JSON.parse_string(bytes.get_string_from_utf8())
	return data if typeof(data) == TYPE_DICTIONARY else {}


# —— 薄缓存（非权威；仅秒启动 + 离线只读展示）——
func _load_cache() -> Dictionary:
	if not FileAccess.file_exists(cache_path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _save_cache(version: String, files: Dictionary) -> void:
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": version, "files": files}))
		f.close()


func clear_cache() -> void:
	if FileAccess.file_exists(cache_path):
		var dir := DirAccess.open(cache_path.get_base_dir())
		if dir != null:
			dir.remove(cache_path.get_file())
