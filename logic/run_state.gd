# RunState —— Roguelite 一条 run 的可变状态与胜负流转（V3-4a）。
#
# 持有：本 run 的工作卡组 + 节点地图(RunMap) + 当前进度(cursor) + run 状态。
# 流转规则（V3-4a 决策 = 二元永久死亡）：
#   - 仅【玩家胜】(Battle.RESULT_PLAYER_WIN) 推进到下一节点；走完最后节点 → 通关(RUN_WON)。
#   - 【对手胜】或【平局】→ 整局立即失败(RUN_LOST)：必须取胜才过关（draw 视为未胜）。
#   - 战斗未结束(RESULT_ONGOING) → 不推进（防御，调用方应在 battle.is_over() 后才喂结果）。
# 纯逻辑、确定性、可 headless 单测：advance(battle_result) 喂入 Battle.RESULT_*。
# relics 预留 V3-4c、seed 预留后续程序化地图/draft；本步不实际使用随机。
extends RefCounted
class_name RunState

const BattleScript = preload("res://logic/battle.gd")

const RUN_ONGOING := 0
const RUN_WON := 1
const RUN_LOST := 2

var deck: Array = []        # 本 run 工作卡组（card_id 列表；draft 在 V3-4b 改写它）
var map = null              # RunMap（节点链）
var cursor: int = 0         # 当前待打节点在 map 中的下标
var status: int = RUN_ONGOING
var wins: int = 0           # 已取胜场数（统计 / run 结算用）
var seed: int = 0           # 预留：后续程序化地图/draft 的确定性种子
var relics: Array = []      # 预留：V3-4c relic（本 run 数值修正器）

func _init(map_ = null, deck_: Array = [], seed_: int = 0) -> void:
	map = map_
	deck = deck_.duplicate()
	seed = seed_

func is_over() -> bool:
	return status != RUN_ONGOING

# 当前待打节点；run 已结束 / 无地图 / 越界 → 空字典。
func current_node() -> Dictionary:
	if is_over() or map == null:
		return {}
	return map.node_at(cursor)

# 喂入刚结束战斗的结果（Battle.RESULT_*），推进 run 状态。
func advance(battle_result: int) -> void:
	if is_over():
		return
	if battle_result == BattleScript.RESULT_ONGOING:
		return   # 战斗未结束，不推进（防御）
	if battle_result == BattleScript.RESULT_PLAYER_WIN:
		wins += 1
		cursor += 1
		if map == null or cursor >= map.size():
			status = RUN_WON
	else:
		status = RUN_LOST   # 对手胜 / 平局 → 二元永久死亡
