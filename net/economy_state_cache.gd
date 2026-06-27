extends RefCounted
## V5-N7（决策 48）：经济/养成状态的**非权威本地缓存**（瘦客户端化）。
## 持有最近一次服务器拉来的状态快照（PlayerData 形状），供：
## ①开战时给 Match.setup_stage 注入权威 level/rank（战斗数值来自服务器，不是本地存档）；
## ②UI 只读展示（秒启动/离线兜底，S7 接）。
## 权威永远在服务器；本地 player_save.json 降级为本缓存的落盘镜像（改了不影响开战）。
class_name EconomyStateCache

const PlayerDataScript = preload("res://logic/player_data.gd")
const EconomyClient = preload("res://net/economy_client.gd")

var _client               # EconomyClient（HTTP + protobuf）
var cache = null          # PlayerData：最近一次服务器快照（未加载则 null）
var is_loaded: bool = false   # 是否成功拉过至少一次服务器状态
var last_error: Dictionary = {}   # 最近一次 refresh 的失败信息（{ok:false,...}）

func _init(api_url: String = "") -> void:
	_client = EconomyClient.new(api_url)


## 从服务器拉状态并重建缓存。成功 → cache 更新 + is_loaded=true；失败 → last_error 记录、cache 不变。
## all_card_ids 用于 ensure 缺失卡（来自 config）。返回 {ok:true} 或 {ok:false,...}。
func refresh(http, token: String, all_card_ids: Array) -> Dictionary:
	var res: Dictionary = await _client.get_state(http, token)
	if not bool(res.get("ok", false)):
		last_error = res
		print("[V5][econ] 拉状态失败 status=%d" % int(res.get("status_code", 0)))
		return res
	# 服务器快照 → PlayerData（apply_server_state 用服务器 schema 重建）。
	if cache == null:
		cache = PlayerDataScript.new()
	cache.apply_server_state(res["state"], all_card_ids)
	is_loaded = true
	last_error = {}
	print("[V5][econ] 拉状态 ok gold=%d gems=%d 解锁=%d/%d highest=%s" % [cache.gold, cache.gems, cache.unlocked_card_ids().size(), cache.cards.size(), cache.highest_cleared])
	return {"ok": true}


## 把一次服务器返回的状态快照应用到缓存（refresh/动作共用）。
func _apply(state_dict: Dictionary, all_card_ids: Array) -> void:
	if cache == null:
		cache = PlayerDataScript.new()
	cache.apply_server_state(state_dict, all_card_ids)
	is_loaded = true
	last_error = {}


## V5-S7（决策48）动作门面：领取挂机金币。服务器算 (now−last_collect) 产出 + 落库，回新状态 → 更新缓存。
## 成功 → {ok:true}（缓存已刷新）；失败 → {ok:false,...}（缓存不变）。token=会话令牌；all_card_ids 来自 config。
func collect_idle(http, token: String, all_card_ids: Array) -> Dictionary:
	var before := int(cache.gold) if cache != null else 0
	var res: Dictionary = await _client.collect_idle(http, token)
	if bool(res.get("ok", false)):
		_apply(res["state"], all_card_ids)
		print("[V5][econ] 领挂机 ok gold %d→%d" % [before, cache.gold])
	else:
		last_error = res
		print("[V5][econ] 领挂机失败 status=%d code=%d" % [int(res.get("status_code", 0)), int(res.get("error_code", 0))])
	return res


## V5-S7d 养成动作门面：升级 / 升阶 / 解锁。服务器算成本+校验+落库 → 回新状态更新缓存。
func upgrade(http, token: String, card_id: String, all_card_ids: Array) -> Dictionary:
	return await _action(http, "upgrade", token, card_id, all_card_ids)

func rank_up(http, token: String, card_id: String, all_card_ids: Array) -> Dictionary:
	return await _action(http, "rank_up", token, card_id, all_card_ids)

func unlock(http, token: String, card_id: String, all_card_ids: Array) -> Dictionary:
	return await _action(http, "unlock", token, card_id, all_card_ids)

func _action(http, op: String, token: String, card_id: String, all_card_ids: Array) -> Dictionary:
	var res: Dictionary
	match op:
		"upgrade": res = await _client.upgrade(http, token, card_id)
		"rank_up": res = await _client.rank_up(http, token, card_id)
		_: res = await _client.unlock(http, token, card_id)
	if bool(res.get("ok", false)):
		_apply(res["state"], all_card_ids)
		var cs: Dictionary = cache.card_state(card_id)
		print("[V5][econ] %s %s ok → gold=%d level=%d rank=%d unlocked=%s" % [op, card_id, cache.gold, int(cs.get("level", 0)), int(cs.get("rank", 0)), str(cache.is_unlocked(card_id))])
	else:
		last_error = res
		print("[V5][econ] %s %s 失败 status=%d code=%d" % [op, card_id, int(res.get("status_code", 0)), int(res.get("error_code", 0))])
	return res

## V5-S7c 闯关上报门面：报 (stage_id, stars)，服务器 sanity + 发奖 + 记进度 → 回新状态更新缓存。
func report_stage_clear(http, token: String, stage_id: String, stars: int, all_card_ids: Array) -> Dictionary:
	var res: Dictionary = await _client.report_stage_clear(http, token, stage_id, stars)
	if bool(res.get("ok", false)):
		_apply(res["state"], all_card_ids)
		print("[V5][econ] 上报通关 %s stars=%d ok → gold=%d highest=%s" % [stage_id, stars, cache.gold, cache.highest_cleared])
	else:
		last_error = res
		print("[V5][econ] 上报通关 %s stars=%d 失败 status=%d code=%d" % [stage_id, stars, int(res.get("status_code", 0)), int(res.get("error_code", 0))])
	return res


## 返回适合注入 Match.setup_stage 的 PlayerData（开战用）。
## 已加载 → 返回缓存（权威来自服务器）；未加载 → 返回全默认新档（保证战斗能跑，数值=未养成 baseline）。
## all_card_ids 来自 config（确保卡池完整）。
func for_battle(all_card_ids: Array):
	if is_loaded and cache != null:
		return cache
	var fresh = PlayerDataScript.new()
	fresh.init_new(all_card_ids)
	return fresh


## 持有的缓存 PlayerData（可能 null / 未加载）。UI 只读展示用。
func get_cache():
	return cache


## 降级路径（离线/未登录）：用本地存档镜像初始化缓存（秒启动展示用；登录后被服务器覆盖）。
## 由 SaveSystem.load_player 读出的 player_data 传入。不改变 is_loaded（仍未从服务器确认）。
func seed_from_local(player_data) -> void:
	cache = player_data
