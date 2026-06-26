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
		return res
	# 服务器快照 → PlayerData（apply_server_state 用服务器 schema 重建）。
	if cache == null:
		cache = PlayerDataScript.new()
	cache.apply_server_state(res["state"], all_card_ids)
	is_loaded = true
	last_error = {}
	return {"ok": true}


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
