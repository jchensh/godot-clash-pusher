extends RefCounted
##
## V4-S2 客户端档案层。配合 net/auth.gd 的 access_token 使用:
##   1. get_profile  —— 带 Bearer 令牌拉档 + 卡组; 成功落盘 user://profile.cfg
##                      网络不可达时回退到离线缓存 (offline=true)
##   2. update_deck  —— 带乐观锁 expected_version 推卡组
##                      409 冲突 -> 自动重取最新档覆盖本地 (服务端版本胜出)
##   3. 离线缓存 user://profile.cfg —— 在线时写, 离线时读, 档不丢
##
## 用法:
##   var prof = preload("res://net/profile.gd").new("http://localhost:8080")
##   var http := HTTPRequest.new(); add_child(http)
##   var res = await prof.get_profile(http, auth.access_token)
##   if res.ok: print(prof.nickname, prof.decks)
##
## 与 net/auth.gd 一样不耦合 SceneTree: HTTPRequest 由 caller add_child + 传入,
## 可在 headless 单测里 .new() (HTTP 部分走 V4-S2e 端到端验收).

const _PROFILE_PATH := "user://profile.cfg"
const _ProfilePb := preload("res://net/proto/profile.gd")

var server_url: String = "http://localhost:8080"
var request_timeout_s: float = 10.0   # 超时 -> 视为不可达 -> 离线缓存兜底 (0=不超时会永久卡)

# 上次已知档案 (内存态; 同时镜像到 user://profile.cfg).
var account_id: int = 0
var nickname: String = ""
var avatar_id: int = 0
var avatar_card_id: String = ""   # V5-S9：头像=怪物卡 id（服务器权威；空=尚未创号）
var tutorial_done: bool = false   # V5-S9：新手引导已完成
var level: int = 0
var exp: int = 0
var trophies: int = 0
var current_season_id: int = 0
var version: int = 0                  # 乐观锁版本
var updated_at: int = 0               # unix seconds
var decks: Array = []                 # [{id, slot, card_ids:Array[String], is_active}]
var unlocked_card_ids: Array = []     # 空 = 全卡解锁 (V4-S2 决策 1)
var from_cache: bool = false          # 最近一次 get_profile 是否走了离线缓存

## get_profile / update_deck 的结果. 不嵌 godobuf 类型, 避免外部碰生成代码.
class Result extends RefCounted:
	var ok: bool = false
	var error: String = ""        # 失败原因 (空=成功)
	var status_code: int = 0      # HTTP 状态码 (0=请求未送达)
	var conflict: bool = false    # true=版本冲突 409 (本地已重取服务端最新)
	var offline: bool = false     # true=网络不可达, 走了离线缓存


func _init(p_server_url: String = "http://localhost:8080") -> void:
	server_url = p_server_url


# ---------------- HTTP calls (await-based) ----------------

## 拉取档案 + 全部卡组. 成功 -> 更新内存态 + 落盘 + ok=true.
## 网络不可达 -> 若有缓存则 ok=true/offline=true, 否则 error.
func get_profile(http_req: HTTPRequest, access_token: String) -> Result:
	var req = _ProfilePb.ProfileGetReq.new()
	var body: PackedByteArray = req.to_bytes()
	var resp := await _post(http_req, "/v4/profile/get", access_token, body)

	if not resp.reached:
		# 网络不可达 -> 离线缓存兜底.
		var r := Result.new()
		if _load_cache():
			from_cache = true
			r.ok = true
			r.offline = true
		else:
			r.error = "offline and no cache: " + resp.error
		return r

	if resp.status_code != 200:
		var r := Result.new()
		r.error = "HTTP %d" % resp.status_code
		r.status_code = resp.status_code
		return r

	var r := Result.new()
	if not apply_get_resp_bytes(resp.body):
		r.error = "decode ProfileGetResp failed"
		r.status_code = 200
		return r
	from_cache = false
	r.ok = true
	r.status_code = 200
	return r


## 推送某槽卡组. 200 -> 更新版本 + 本地卡组 + 落盘.
## 409 -> conflict=true 且自动重取最新档 (服务端版本胜出).
func update_deck(http_req: HTTPRequest, access_token: String, slot: int, card_ids: Array, set_active: bool, expected_version: int) -> Result:
	var req = _ProfilePb.DeckUpdateReq.new()
	req.set_slot(slot)
	for c in card_ids:
		req.add_card_ids(c)
	req.set_set_active(set_active)
	req.set_expected_version(expected_version)
	var body: PackedByteArray = req.to_bytes()
	var resp := await _post(http_req, "/v4/profile/deck-update", access_token, body)

	if not resp.reached:
		var r := Result.new()
		r.error = "offline: " + resp.error
		r.offline = true
		return r

	if resp.status_code == 409:
		# 服务端版本胜出: 自动重取覆盖本地, 让 caller 拿到最新再决定是否重试.
		var r := Result.new()
		r.conflict = true
		r.status_code = 409
		await get_profile(http_req, access_token)
		r.error = "version mismatch; re-synced from server"
		return r

	if resp.status_code != 200:
		var r := Result.new()
		r.error = "HTTP %d" % resp.status_code
		r.status_code = resp.status_code
		return r

	var r := Result.new()
	if not apply_deck_resp_bytes(resp.body):
		r.error = "decode DeckUpdateResp failed"
		r.status_code = 200
		return r
	_upsert_local_deck(slot, card_ids, set_active)
	_save_cache()
	r.ok = true
	r.status_code = 200
	return r


## V5-S9 创号/改身份：推昵称+头像。200 → 更新本地档 + 落盘。
func update_identity(http_req: HTTPRequest, access_token: String, p_nickname: String, p_avatar_card_id: String) -> Result:
	var req = _ProfilePb.ProfileUpdateReq.new()
	req.set_nickname(p_nickname)
	req.set_avatar_card_id(p_avatar_card_id)
	var resp := await _post(http_req, "/v4/profile/update", access_token, req.to_bytes())
	return _apply_update_resp(resp)


## V5-S9 标记新手引导已完成。200 → 更新本地档（tutorial_done=true）+ 落盘。
func mark_tutorial_done(http_req: HTTPRequest, access_token: String) -> Result:
	var req = _ProfilePb.TutorialDoneReq.new()
	var resp := await _post(http_req, "/v4/profile/tutorial-done", access_token, req.to_bytes())
	return _apply_update_resp(resp)


# 解码 ProfileUpdateResp（update / tutorial-done 共用）→ 应用 profile + 落盘。
func _apply_update_resp(resp) -> Result:
	if not resp.reached:
		var r := Result.new()
		r.error = "offline: " + resp.error
		r.offline = true
		return r
	if resp.status_code != 200:
		var r := Result.new()
		r.error = "HTTP %d" % resp.status_code
		r.status_code = resp.status_code
		return r
	var pr = _ProfilePb.ProfileUpdateResp.new()
	if pr.from_bytes(resp.body) != _ProfilePb.PB_ERR.NO_ERRORS:
		var r := Result.new()
		r.error = "decode ProfileUpdateResp failed"
		r.status_code = 200
		return r
	var p = pr.get_profile()
	if p != null:
		_apply_profile(p)
		_save_cache()
	var r := Result.new()
	r.ok = true
	r.status_code = 200
	return r


# ---------------- wire decode (无需网络, 可单测) ----------------

## 解码 ProfileGetResp 字节 -> 填充内存态 + 落盘. 返回是否成功.
func apply_get_resp_bytes(body: PackedByteArray) -> bool:
	var pr = _ProfilePb.ProfileGetResp.new()
	if pr.from_bytes(body) != _ProfilePb.PB_ERR.NO_ERRORS:
		return false
	var p = pr.get_profile()
	if p != null:
		_apply_profile(p)
	decks.clear()
	for d in pr.get_decks():
		decks.append({
			"id": d.get_id(),
			"slot": d.get_slot(),
			"card_ids": d.get_card_ids().duplicate(),
			"is_active": d.get_is_active(),
		})
	unlocked_card_ids = pr.get_unlocked_card_ids().duplicate()
	_save_cache()
	return true


## 解码 DeckUpdateResp 字节 -> 更新 profile (版本号等). 返回是否成功.
func apply_deck_resp_bytes(body: PackedByteArray) -> bool:
	var dr = _ProfilePb.DeckUpdateResp.new()
	if dr.from_bytes(body) != _ProfilePb.PB_ERR.NO_ERRORS:
		return false
	var p = dr.get_profile()
	if p != null:
		_apply_profile(p)
	return true


func _apply_profile(p) -> void:
	account_id = p.get_account_id()
	nickname = p.get_nickname()
	avatar_id = p.get_avatar_id()
	avatar_card_id = p.get_avatar_card_id()   # V5-S9
	tutorial_done = p.get_tutorial_done()     # V5-S9
	level = p.get_level()
	exp = p.get_exp()
	trophies = p.get_trophies()
	current_season_id = p.get_current_season_id()
	version = p.get_version()
	updated_at = p.get_updated_at()


## 本地卡组缓存的 upsert: 改/插某槽; set_active 时把其它槽降为非激活 (镜像服务端).
## 新插入行的 id 暂置 0 (服务端真 id 等下次 get_profile 刷新).
func _upsert_local_deck(slot: int, card_ids: Array, set_active: bool) -> void:
	var found := false
	for d in decks:
		if int(d["slot"]) == slot:
			d["card_ids"] = card_ids.duplicate()
			d["is_active"] = set_active
			found = true
		elif set_active:
			d["is_active"] = false
	if not found:
		decks.append({
			"id": 0,
			"slot": slot,
			"card_ids": card_ids.duplicate(),
			"is_active": set_active,
		})


# ---------------- offline cache ----------------

func _save_cache() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "account_id", account_id)
	cfg.set_value("profile", "nickname", nickname)
	cfg.set_value("profile", "avatar_id", avatar_id)
	cfg.set_value("profile", "avatar_card_id", avatar_card_id)
	cfg.set_value("profile", "tutorial_done", tutorial_done)
	cfg.set_value("profile", "level", level)
	cfg.set_value("profile", "exp", exp)
	cfg.set_value("profile", "trophies", trophies)
	cfg.set_value("profile", "current_season_id", current_season_id)
	cfg.set_value("profile", "version", version)
	cfg.set_value("profile", "updated_at", updated_at)
	cfg.set_value("decks", "list", decks)
	cfg.set_value("unlocks", "ids", unlocked_card_ids)
	cfg.save(_PROFILE_PATH)


func _load_cache() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_PROFILE_PATH) != OK:
		return false
	account_id = cfg.get_value("profile", "account_id", 0)
	nickname = cfg.get_value("profile", "nickname", "")
	avatar_id = cfg.get_value("profile", "avatar_id", 0)
	avatar_card_id = cfg.get_value("profile", "avatar_card_id", "")
	tutorial_done = cfg.get_value("profile", "tutorial_done", false)
	level = cfg.get_value("profile", "level", 0)
	exp = cfg.get_value("profile", "exp", 0)
	trophies = cfg.get_value("profile", "trophies", 0)
	current_season_id = cfg.get_value("profile", "current_season_id", 0)
	version = cfg.get_value("profile", "version", 0)
	updated_at = cfg.get_value("profile", "updated_at", 0)
	decks = cfg.get_value("decks", "list", [])
	unlocked_card_ids = cfg.get_value("unlocks", "ids", [])
	return true


## 删缓存 (测试 / 切账号用).
func clear_cache() -> void:
	if FileAccess.file_exists(_PROFILE_PATH):
		DirAccess.remove_absolute(_PROFILE_PATH)


# ---------------- internal HTTP plumbing ----------------

class _HttpResult extends RefCounted:
	var reached: bool = false      # true=服务端给了 HTTP 响应 (任意状态码)
	var status_code: int = 0
	var body: PackedByteArray = PackedByteArray()
	var error: String = ""


## 内部: POST 二进制 protobuf, 带 Bearer 鉴权头. http_req 须已在 SceneTree 内.
func _post(http_req: HTTPRequest, path: String, access_token: String, body: PackedByteArray) -> _HttpResult:
	var hr := _HttpResult.new()
	var url := server_url + path
	var headers := PackedStringArray([
		"Content-Type: application/x-protobuf",
		"Accept: application/x-protobuf",
		"Authorization: Bearer " + access_token,
	])
	http_req.timeout = request_timeout_s  # 服务端不可达时不至于永久挂起
	var err := http_req.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		hr.error = "request_raw err=%d" % err
		return hr
	# request_completed (result, response_code, headers, body)
	var args: Array = await http_req.request_completed
	hr.status_code = args[1]
	hr.body = args[3]
	if args[0] != HTTPRequest.RESULT_SUCCESS:
		hr.error = "transport result=%d" % args[0]
		return hr
	hr.reached = true
	return hr
