# CampaignState —— 短战役一条线性进度（V3-5a）。
#
# 持有教学关序列（从 campaign.json 展开的 [{level_id, focus}]）+ 当前进度 + 状态。
# 流转规则（战役 = 新手教学，可重试，区别于 roguelite 的二元永久死亡 [[run_state]]）：
#   - 【玩家胜】(Battle.RESULT_PLAYER_WIN) 推进；走完最后一关 → 通关(CAMPAIGN_CLEARED)。
#   - 【对手胜 / 平局 / 未结束】→ 留在当前关，可重打（no-op：不失败、不回退）。
# 纯逻辑、确定性、可 headless 单测。存档只存进度，关卡序列由 config 重建后注入。
extends RefCounted
class_name CampaignState

const BattleScript = preload("res://logic/battle.gd")

const CAMPAIGN_ONGOING := 0
const CAMPAIGN_CLEARED := 1

var levels: Array = []      # [{level_id, focus}]（从 campaign.json 展开）
var cursor: int = 0         # 当前待打关下标
var status: int = CAMPAIGN_ONGOING

func _init(level_list: Array = [], start_cursor: int = 0) -> void:
	levels = level_list.duplicate(true)
	cursor = clampi(start_cursor, 0, maxi(0, levels.size()))

func size() -> int:
	return levels.size()

func is_over() -> bool:
	return status != CAMPAIGN_ONGOING

# 当前待打关；已通关 / 越界 → 空字典。
func current() -> Dictionary:
	if is_over() or cursor < 0 or cursor >= levels.size():
		return {}
	return levels[cursor]

func current_level_id() -> String:
	return str(current().get("level_id", ""))

func current_focus() -> String:
	return str(current().get("focus", ""))

# 喂入刚结束战斗的结果（Battle.RESULT_*）：仅玩家胜推进；其余留在当前关可重打。
func advance(battle_result: int) -> void:
	if is_over():
		return
	if battle_result == BattleScript.RESULT_PLAYER_WIN:
		cursor += 1
		if cursor >= levels.size():
			status = CAMPAIGN_CLEARED

# —— 存档（关卡序列由 _init 重建后注入，只存进度；实例方法不引用自身 class_name） ——
func to_dict() -> Dictionary:
	return {"cursor": cursor, "status": status}

func load_dict(d: Dictionary) -> void:
	cursor = int(d.get("cursor", 0))
	status = int(d.get("status", CAMPAIGN_ONGOING))
