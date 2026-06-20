# SkillSystem —— 解析卡牌技能积木数组并执行（V3 2D 重构）。
#
# 三种积木：spawn_unit（生成单位）/ direct_damage（点单伤）/ aoe_damage（范围伤）。
# 结算规则（HISTORY 决策 17–21，2D 化）：
#   - 多积木：按数组从上到下、逐个同步结算。
#   - spawn_unit：在出牌点 pos 生成 count 个单位（多个时做微小确定性散布，避免完全重叠）。
#   - direct_damage：命中最逼近出牌点 pos 的敌方单位；无敌方则空放。
#   - aoe_damage：命中 |pos - 目标| <= radius（tile 欧氏）的敌方单位；圆心 = 出牌点 pos。
#   - 伤害类积木只打敌方单位、不打塔；不校验/扣圣水（上层职责）。
# 出牌指令统一为 (card_id, owner_id, pos:Vector2)。
extends RefCounted
class_name SkillSystem

const UnitScript = preload("res://logic/unit.gd")

const _EPSILON := 0.000001
# count>1 时的确定性散布偏移（tile），围绕出牌点小范围铺开。
const _SPREAD := [
	Vector2(0, 0), Vector2(0.7, 0), Vector2(-0.7, 0), Vector2(0, 0.7),
	Vector2(0, -0.7), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7),
]

var config        # ConfigLoader：读卡牌与单位配置
var battle        # Battle：提供 arena（单位集合）

func _init(config_ = null, battle_ = null) -> void:
	config = config_
	battle = battle_

# 出一张牌：按 skills 数组顺序执行每个积木。卡不存在返回 false。不校验/扣圣水（上层职责）。
func play_card(card_id: String, owner_id: int, pos: Vector2 = Vector2.ZERO) -> bool:
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
			_execute_block(block, owner_id, pos)
	return true

func _execute_block(block: Dictionary, owner_id: int, pos: Vector2) -> void:
	match str(block.get("type", "")):
		"spawn_unit":
			_spawn_unit(block, owner_id, pos)
		"direct_damage":
			_direct_damage(block, owner_id, pos)
		"aoe_damage":
			_aoe_damage(block, owner_id, pos)
		"aoe_heal":
			_aoe_heal(block, owner_id, pos)
		_:
			pass   # 未知积木类型：忽略

func _spawn_unit(block: Dictionary, owner_id: int, pos: Vector2) -> void:
	var arena = _arena()
	if arena == null:
		return
	var unit_id := str(block.get("unit_id", ""))
	var unit_cfg: Dictionary = config.get_unit(unit_id)
	if unit_cfg.is_empty():
		return
	var count := maxi(int(block.get("count", 1)), 0)
	for i in count:
		var offset: Vector2 = _SPREAD[i % _SPREAD.size()]
		var u = UnitScript.new(unit_id, owner_id, unit_cfg, pos + offset)
		# 亡语召唤（V3-3）：注入被召唤单位的配置模板，使 Arena 死亡时无需 ConfigLoader 即可生成。
		if u.death_spawn_id != "":
			u.death_spawn_config = config.get_unit(u.death_spawn_id)
		arena.add_unit(u)

func _direct_damage(block: Dictionary, owner_id: int, pos: Vector2) -> void:
	var target = _nearest_enemy_to(pos, owner_id)
	if target == null:
		return   # 无敌方单位 → 空放
	target.take_damage(float(block.get("damage", 0.0)))

func _aoe_damage(block: Dictionary, owner_id: int, center: Vector2) -> void:
	var arena = _arena()
	if arena == null:
		return
	var radius := float(block.get("radius", 0.0))
	var damage := float(block.get("damage", 0.0))
	for u in arena.get_units():
		if u.owner_id == owner_id or not u.is_alive():
			continue   # 只打存活敌方
		if u.pos.distance_to(center) <= radius + _EPSILON:
			u.take_damage(damage)

# 治疗术（V3-3）：治疗范围内存活友军（damage 字段复用为治疗量）。
func _aoe_heal(block: Dictionary, owner_id: int, center: Vector2) -> void:
	var arena = _arena()
	if arena == null:
		return
	var radius := float(block.get("radius", 0.0))
	var amount := float(block.get("damage", 0.0))
	for u in arena.get_units():
		if u.owner_id != owner_id or not u.is_alive():
			continue   # 只治友军
		if u.pos.distance_to(center) <= radius + _EPSILON:
			u.heal(amount)

# 最逼近 pos 的存活敌方单位；无则 null。
func _nearest_enemy_to(pos: Vector2, owner_id: int):
	var arena = _arena()
	if arena == null:
		return null
	var best = null
	var best_d := INF
	for u in arena.get_units():
		if u.owner_id == owner_id or not u.is_alive():
			continue
		var d: float = u.pos.distance_to(pos)
		if d < best_d:
			best_d = d
			best = u
	return best

func _arena():
	return battle.arena if battle != null else null
