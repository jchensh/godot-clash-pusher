# V5-N1/N2：持久会话连接的配置下发解析 + 薄缓存（无需 live server）。
extends "res://tests/test_case.gd"

const SessionConn = preload("res://net/session_conn.gd")
const SessionProto = preload("res://net/proto/session.gd")

const TMP := "user://_test_config_cache.json"


class FakeWS extends RefCounted:
	var state := WebSocketPeer.STATE_CLOSED
	var connect_calls := 0
	func can_connect() -> bool: return state == WebSocketPeer.STATE_CLOSED
	func connect_to(_url: String) -> int:
		connect_calls += 1
		state = WebSocketPeer.STATE_CONNECTING
		return OK
	func poll() -> void: pass
	func send_frame(_msg_id: int, _payload: PackedByteArray) -> void: pass
	func close() -> void: state = WebSocketPeer.STATE_CLOSED

func _make_push(version: String, up_to_date: bool, bundle_json: String) -> PackedByteArray:
	var cp = SessionProto.ConfigPush.new()
	cp.set_version(version)
	cp.set_up_to_date(up_to_date)
	if not up_to_date:
		cp.set_bundle(bundle_json.to_utf8_buffer())
	return cp.to_bytes()

func test_config_push_full_parses_and_caches() -> void:
	var sc = SessionConn.new()
	sc.cache_path = TMP
	sc.clear_cache()
	var bundle = '{"cards.json":{"knight":{"elixir_cost":3}},"economy.json":{"x":1}}'
	sc._handle_config_push(_make_push("v1", false, bundle))
	assert_eq(sc.config_version, "v1", "版本更新")
	assert_eq(int(sc.get_file("cards.json").get("knight", {}).get("elixir_cost", 0)), 3, "cards 解析")
	assert_eq(int(sc.get_file("economy.json").get("x", 0)), 1, "economy 解析")
	assert_true(FileAccess.file_exists(TMP), "薄缓存落盘")
	sc.clear_cache()

func test_config_push_up_to_date_uses_cache() -> void:
	var sc1 = SessionConn.new()
	sc1.cache_path = TMP
	sc1.clear_cache()
	sc1._handle_config_push(_make_push("v2", false, '{"cards.json":{"a":1}}'))   # 写缓存 v2
	# 新实例：读缓存版本 + 服务器回 up_to_date → 用缓存配置
	var sc2 = SessionConn.new()
	sc2.cache_path = TMP
	var cache = sc2._load_cache()
	assert_eq(String(cache.get("version", "")), "v2", "缓存版本读回")
	sc2.config_version = "v2"
	sc2.config_files = cache.get("files", {})
	sc2._handle_config_push(_make_push("v2", true, ""))
	assert_eq(sc2.config_version, "v2", "up_to_date 保持版本")
	assert_eq(int(sc2.get_file("cards.json").get("a", 0)), 1, "用缓存配置")
	sc1.clear_cache()

func test_parse_bundle_bad_json() -> void:
	var sc = SessionConn.new()
	assert_true(sc._parse_bundle("not json".to_utf8_buffer()).is_empty(), "坏 JSON → 空")

func test_default_and_override_url() -> void:
	assert_eq(SessionConn.new().ws_url, "ws://localhost:8081/v5/session/ws", "默认 url")
	assert_eq(SessionConn.new("ws://x/y").ws_url, "ws://x/y", "构造覆盖 url")


func test_up_to_date_without_cache_is_rejected() -> void:
	var sc = SessionConn.new()
	var failures: Array = []
	sc.config_failed.connect(func(reason: String): failures.append(reason))
	sc.config_files = {}
	sc._handle_config_push(_make_push("v3", true, ""))
	assert_eq(failures.size(), 1, "空缓存不能被 up_to_date 误判为可用")
	assert_eq(sc.config_version, "", "失败时不更新版本")


func test_full_push_updates_reconnect_version() -> void:
	var sc = SessionConn.new()
	sc.cache_path = TMP
	sc.clear_cache()
	sc._handle_config_push(_make_push("v4", false, '{"cards.json":{"a":1}}'))
	assert_eq(sc._pending_cfgver, "v4", "重连应携最新已确认版本")
	sc.clear_cache()


func test_reconnect_waits_until_peer_is_closed() -> void:
	var sc = SessionConn.new()
	var fake := FakeWS.new()
	sc._ws = fake
	sc._reconnect = true
	fake.state = WebSocketPeer.STATE_CONNECTING
	sc.poll(SessionConn.RECONNECT_INTERVAL + 0.1)
	assert_eq(fake.connect_calls, 0, "CONNECTING 中不得重复拨号")
	assert_true(sc._reconnect_accum >= SessionConn.RECONNECT_INTERVAL, "等待期间保留到期重试")
	fake.state = WebSocketPeer.STATE_CLOSED
	sc.poll(0.0)
	assert_eq(fake.connect_calls, 1, "peer CLOSED 后立即发起一次重连")
	sc.poll(SessionConn.RECONNECT_INTERVAL + 0.1)
	assert_eq(fake.connect_calls, 1, "新拨号仍 CONNECTING 时不得重入")
