# PlayerData —— V5 单机玩家存档数据（钱包 + 卡牌养成 + 关卡进度 + 挂机）。
#
# V5-S0 草案：只定义数据结构 + 默认新档 + to_dict/load_dict 往返。
# 完整的 SaveSystem 接线、战力计算、解锁解算留 V5-S2；升级/升阶改值留 V5-S4/S5。
# 纯逻辑、确定性、可 headless 单测。存读档由 SaveSystem 落 user://（V5-S2）。
#
# 踩坑遵循（V3-4d）：to_dict/load_dict/init_new 全为**实例方法、不引用自身 class_name**，
# 避免新脚本在 .uid/全局注册前被 test runner 预检判失败。调用方用 `PlayerData.new()` 后再调。
extends RefCounted
class_name PlayerData

# 默认新档解锁的初始 8 张（= levels.json level_01 默认卡组 / card_progression starter=true）。
const STARTER_CARDS := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]

var gold: int = 0
var gems: int = 0
# card_id -> { level:int, rank:int, shards:int, unlocked:bool }
var cards: Dictionary = {}
# stage_id -> { stars:int, cleared:bool }
var stages: Dictionary = {}
var highest_cleared: String = ""
var idle_last_collect_ts: int = 0

# 构造一份全新玩家档：传入全部 card_id（来自 cards.json / card_progression.json），
# 每卡建 level1/rank1/shards0，starter 集合内的 unlocked=true、其余 false。
func init_new(all_card_ids: Array) -> void:
	gold = 0
	gems = 0
	cards = {}
	stages = {}
	highest_cleared = ""
	idle_last_collect_ts = 0
	for cid in all_card_ids:
		cards[String(cid)] = {
			"level": 1,
			"rank": 1,
			"shards": 0,
			"unlocked": STARTER_CARDS.has(String(cid)),
		}

func is_unlocked(card_id: String) -> bool:
	var c = cards.get(card_id, {})
	return typeof(c) == TYPE_DICTIONARY and bool(c.get("unlocked", false))

func card_state(card_id: String) -> Dictionary:
	var c = cards.get(card_id, {})
	return c if typeof(c) == TYPE_DICTIONARY else {}

func unlocked_card_ids() -> Array:
	var out: Array = []
	for cid in cards:
		if is_unlocked(String(cid)):
			out.append(String(cid))
	return out

# —— 存档往返（schema 见 PLAN_V5 §9；实例方法不引用自身 class_name） ——
func to_dict() -> Dictionary:
	return {
		"wallet": { "gold": gold, "gems": gems },
		"cards": cards.duplicate(true),
		"stages": stages.duplicate(true),
		"highest_cleared": highest_cleared,
		"idle": { "last_collect_ts": idle_last_collect_ts },
	}

func load_dict(d: Dictionary) -> void:
	var w = d.get("wallet", {})
	if typeof(w) != TYPE_DICTIONARY:
		w = {}
	gold = int(w.get("gold", 0))
	gems = int(w.get("gems", 0))
	var c = d.get("cards", {})
	cards = (c as Dictionary).duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}
	var s = d.get("stages", {})
	stages = (s as Dictionary).duplicate(true) if typeof(s) == TYPE_DICTIONARY else {}
	highest_cleared = String(d.get("highest_cleared", ""))
	var idle = d.get("idle", {})
	if typeof(idle) != TYPE_DICTIONARY:
		idle = {}
	idle_last_collect_ts = int(idle.get("last_collect_ts", 0))
