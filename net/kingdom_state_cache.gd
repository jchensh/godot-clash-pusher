extends RefCounted
## K2（DESIGN_KINGDOM，决策 48）：王国状态的**非权威本地缓存**（镜像 EconomyStateCache 范式）。
## 持有最近一次服务器快照（平面字典），UI 只读展示；全部写操作经服务器结算后回写。
## 倒计时基准：服务器下发 server_now_ts + 本地收包时刻 → remaining()，本地改时钟不影响结算
## （服务器到点才真完级；客户端只是显示）。
class_name KingdomStateCache

const KingdomClient = preload("res://net/kingdom_client.gd")

var _client
var cache: Dictionary = {}        # 最近服务器快照（空 = 未加载）
var is_loaded: bool = false
var last_error: Dictionary = {}
var online_guard: Callable        # E1 同款：写操作前 fail-closed gate（OnlineRuntime 注入）
var transport_failure_reporter: Callable
var _recv_local_ms: int = 0       # 收到快照时的本地毫秒钟（倒计时插值基准）


func _init(api_url: String = "") -> void:
	_client = KingdomClient.new(api_url)


func refresh(http, token: String) -> Dictionary:
	var res: Dictionary = await _client.get_state(http, token)
	_observe_result(res, "kingdom refresh")
	if not bool(res.get("ok", false)):
		last_error = res
		Log.w("[V5][kingdom] 拉状态失败 status=%d" % int(res.get("status_code", 0)))
		return res
	_apply(res["state"])
	Log.i("[V5][kingdom] 拉状态 ok res=%s pending=%s gold=%d"
			% [str(cache.get("resources", {})), str(cache.get("pending", {})), int(cache.get("pending_gold", 0))])
	return {"ok": true}


## 建造/升级（Lv0→1 即建造）。成功 → 缓存刷新 + kingdom_changed 广播；失败缓存不变。
func upgrade(http, token: String, building: String) -> Dictionary:
	return await _do(http, token, "upgrade", building)


## 收取全部产出。
func collect(http, token: String) -> Dictionary:
	return await _do(http, token, "collect", "")


## 宝石加速完成施工。
func speedup(http, token: String, building: String) -> Dictionary:
	return await _do(http, token, "speedup", building)


## 王国 GM 门面（开发作弊）：改服务器王国 DB → 回新快照刷新缓存 + 广播。
func gm_apply(http, token: String, ops: Dictionary) -> Dictionary:
	if not _can_write():
		return _offline_error()
	var res: Dictionary = await _client.gm_apply(http, token, ops)
	_observe_result(res, "kingdom gm")
	if bool(res.get("ok", false)):
		_apply(res["state"])
		Log.i("[V5][kingdom][GM] apply ok ops=%s → res=%s" % [str(ops), str(cache.get("resources", {}))])
	else:
		last_error = res
		Log.w("[V5][kingdom][GM] apply 失败 status=%d" % int(res.get("status_code", 0)))
	return res


func _do(http, token: String, op: String, building: String) -> Dictionary:
	if not _can_write():
		return _offline_error()
	var res: Dictionary
	match op:
		"upgrade": res = await _client.upgrade(http, token, building)
		"collect": res = await _client.collect(http, token)
		_: res = await _client.speedup(http, token, building)
	_observe_result(res, op)
	if bool(res.get("ok", false)):
		_apply(res["state"])
		Log.i("[V5][kingdom] %s %s ok → res=%s" % [op, building, str(cache.get("resources", {}))])
	else:
		last_error = res
		Log.w("[V5][kingdom] %s %s 失败 status=%d code=%d"
				% [op, building, int(res.get("status_code", 0)), int(res.get("error_code", 0))])
	return res


## 建筑剩余施工秒数（显示用插值：服务器基准 + 本地流逝）。0 = 未施工/已到点。
func remaining_s(building: String) -> int:
	var b: Dictionary = (cache.get("buildings", {}) as Dictionary).get(building, {})
	var end := int(b.get("upgrade_end_ts", 0))
	if end <= 0:
		return 0
	var now := int(cache.get("server_now_ts", 0)) + (Time.get_ticks_msec() - _recv_local_ms) / 1000
	return maxi(0, end - now)


func building_level(building: String) -> int:
	return int(((cache.get("buildings", {}) as Dictionary).get(building, {}) as Dictionary).get("level", 0))


func get_cache() -> Dictionary:
	return cache


func _apply(state_dict: Dictionary) -> void:
	cache = state_dict
	_recv_local_ms = Time.get_ticks_msec()
	is_loaded = true
	last_error = {}
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var ev = (ml as SceneTree).root.get_node_or_null("Events")
		if ev != null:
			ev.kingdom_changed.emit(self)


func _can_write() -> bool:
	return not online_guard.is_valid() or bool(online_guard.call())


func _offline_error() -> Dictionary:
	last_error = {"ok": false, "status_code": 0, "error_code": 0, "error": "online session not ready"}
	Log.w("[V5][kingdom] 在线会话未 ready，拒绝写操作")
	return last_error


func _observe_result(result: Dictionary, operation: String) -> void:
	if bool(result.get("ok", false)):
		return
	var status := int(result.get("status_code", 0))
	if (status == 0 or status >= 500) and transport_failure_reporter.is_valid():
		transport_failure_reporter.call("%s unavailable (status=%d)" % [operation, status])
