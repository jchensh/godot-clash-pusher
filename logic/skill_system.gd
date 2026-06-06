# SkillSystem —— 解析卡牌的技能积木数组并执行（PLAN §4 / §5.1，Step 6）。
#
# V1 三种积木：spawn_unit（生成单位）/ direct_damage（点单伤）/ aoe_damage（范围伤）。
# 结算规则（HISTORY 决策日志 17–21）：
#   - 多积木：按数组从上到下、逐个同步结算。
#   - direct_damage：target=first_enemy_in_lane → 最逼近出牌方自己塔的敌方单位；无则空放。
#   - aoe_damage：沿 lane 一维，命中 |progress-center|<=radius 的敌方单位；center 由出牌携带。
#   - 伤害类积木只打敌方单位、不打塔；不校验/扣圣水（那是上层职责）。
# 出牌指令统一为 (card_id, owner_id, lane_index, target_progress)。
#
# 跨脚本用 preload，不依赖 class_name 全局注册（见 HISTORY Step 4 踩坑）。
extends RefCounted
class_name SkillSystem

const UnitScript = preload("res://logic/unit.gd")

const _EPSILON := 0.000001

var config        # ConfigLoader：读卡牌与单位配置
var battle        # Battle：提供 get_lane(lane_index)

func _init(config_ = null, battle_ = null) -> void:
	config = config_
	battle = battle_

# 出一张牌：按 skills 数组顺序执行每个积木。找到并执行返回 true，卡不存在返回 false。
# 不校验/扣圣水（上层职责），只负责触发技能效果。
func play_card(card_id: String, owner_id: int, lane_index: int, target_progress: float = 0.0) -> bool:
	if config == null:
		return false
	var card: Dictionary = config.get_card(card_id)
	if card.is_empty():
		return false
	var skills = card.get("skills", [])
	if typeof(skills) != TYPE_ARRAY:
		return false
	for block in skills:
		if typeof(block) == TYPE_DICTIONARY:
			_execute_block(block, owner_id, lane_index, target_progress)
	return true

func _execute_block(block: Dictionary, owner_id: int, lane_index: int, target_progress: float) -> void:
	match str(block.get("type", "")):
		"spawn_unit":
			_spawn_unit(block, owner_id, lane_index, target_progress)
		"direct_damage":
			_direct_damage(block, owner_id, lane_index)
		"aoe_damage":
			_aoe_damage(block, owner_id, lane_index, target_progress)
		_:
			pass   # 未知积木类型：V1 忽略

func _spawn_unit(block: Dictionary, owner_id: int, lane_index: int, target_progress: float) -> void:
	var lane = _get_lane(lane_index)
	if lane == null:
		return
	var unit_id := str(block.get("unit_id", ""))
	var unit_cfg: Dictionary = config.get_unit(unit_id)
	if unit_cfg.is_empty():
		return
	var count := int(block.get("count", 1))
	for i in maxi(count, 0):
		lane.add_unit(UnitScript.new(unit_id, owner_id, lane_index, unit_cfg, target_progress))

func _direct_damage(block: Dictionary, owner_id: int, lane_index: int) -> void:
	var lane = _get_lane(lane_index)
	if lane == null:
		return
	var target = _first_enemy_in_lane(lane, owner_id)
	if target == null:
		return   # 该 lane 无敌方单位 → 空放
	target.take_damage(float(block.get("damage", 0.0)))

func _aoe_damage(block: Dictionary, owner_id: int, lane_index: int, center: float) -> void:
	var lane = _get_lane(lane_index)
	if lane == null:
		return
	var radius := float(block.get("radius", 0.0))
	var damage := float(block.get("damage", 0.0))
	for u in lane.get_units():
		if u.owner_id == owner_id:
			continue   # 只打敌方
		if absf(float(u.progress) - center) <= radius + _EPSILON:
			u.take_damage(damage)

# 最逼近出牌方自己塔的敌方单位：玩家(塔在 0)取 progress 最小，对手(塔在 1)取最大。
func _first_enemy_in_lane(lane, owner_id):
	var toward_zero: bool = owner_id == UnitScript.OWNER_PLAYER
	var best = null
	var best_progress := 0.0
	for u in lane.get_units():
		if u.owner_id == owner_id or not u.is_alive():
			continue
		var p := float(u.progress)
		if best == null \
				or (toward_zero and p < best_progress) \
				or (not toward_zero and p > best_progress):
			best = u
			best_progress = p
	return best

func _get_lane(lane_index: int):
	if battle == null:
		return null
	return battle.get_lane(lane_index)
