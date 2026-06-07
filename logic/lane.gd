# Lane —— 一条 lane 的单位列表、推进与碰撞/攻击结算。
#
# 纯逻辑队列判断，不使用 Godot 物理引擎。每个 tick：
#   1. 冷却推进；
#   2. 已在攻击范围内的单位停下并按冷却出手；
#   3. 其他单位沿 lane 进度推进，并在接近前方敌人时停在攻击范围边界；
#   4. 统一结算伤害并移除死亡单位。
extends RefCounted
class_name Lane

const _EPSILON := 0.000001

var lane_index: int = 0
var units: Array = []

# 防守两端的塔（可空）：start 守 progress 0（玩家端），end 守 progress 1（对手端）。
# 不接塔时为 null，lane 行为与 Step 4 完全一致。由 Battle 负责接线。
var tower_at_start = null
var tower_at_end = null

# 兜底王塔（V2-1，可空）：当本端主塔（侧路公主）被摧毁后，该 lane 的单位转打这座王塔
# （皇室战争式「拆侧塔开路、威胁王塔」）。中路 lane 主塔本就是王塔，无需兜底。
var king_at_start = null
var king_at_end = null

func _init(lane_index_: int = 0) -> void:
	lane_index = lane_index_

func set_towers(start_tower, end_tower) -> void:
	tower_at_start = start_tower
	tower_at_end = end_tower

func set_king_fallback(start_king, end_king) -> void:
	king_at_start = start_king
	king_at_end = end_king

func add_unit(unit) -> void:
	if unit == null:
		return
	unit.lane_index = lane_index
	units.append(unit)

func get_units() -> Array:
	return units.duplicate()

func tick(dt: float) -> void:
	if dt <= 0.0:
		return

	for unit in units:
		unit.tick_cooldown(dt)

	var attacks: Array = []
	for unit in units:
		if not unit.is_alive():
			continue
		var target = _find_enemy_in_range(unit)
		if target == null:
			target = _find_enemy_tower_in_range(unit)
		if target != null:
			if unit.can_attack():
				attacks.append({
					"target": target,
					"damage": unit.damage,
				})
				unit.mark_attacked()
			continue
		_move_unit(unit, dt)

	for attack in attacks:
		attack["target"].take_damage(attack["damage"])

	_remove_dead()

func _move_unit(unit, dt: float) -> void:
	var direction: int = int(unit.get_direction())
	var desired: float = float(unit.progress) + float(direction) * float(unit.move_speed) * dt
	desired = clampf(desired, 0.0, 1.0)

	var blocker = _find_nearest_enemy_ahead(unit)
	if blocker != null:
		if direction > 0:
			var limit: float = float(blocker.progress) - float(unit.attack_range)
			if desired > limit:
				desired = maxf(float(unit.progress), limit)
		else:
			var limit: float = float(blocker.progress) + float(unit.attack_range)
			if desired < limit:
				desired = minf(float(unit.progress), limit)

	# 别走进尽头的敌塔：停在自身攻击范围边界（塔比任何敌方单位都更靠后，
	# 因此此处只会在没有更近的单位阻挡时收紧 desired）。
	var tower = _enemy_tower_for(unit)
	if tower != null and tower.is_alive():
		var tpos: float = _enemy_tower_end(unit)
		if direction > 0:
			var t_limit: float = tpos - float(unit.attack_range)
			if desired > t_limit:
				desired = maxf(float(unit.progress), t_limit)
		else:
			var t_limit: float = tpos + float(unit.attack_range)
			if desired < t_limit:
				desired = minf(float(unit.progress), t_limit)

	unit.move_to(desired)

func _find_enemy_in_range(unit):
	var best = null
	var best_distance := INF
	for other in units:
		if other == unit or not other.is_alive() or not unit.is_enemy(other):
			continue
		var distance := absf(other.progress - unit.progress)
		if distance <= float(unit.attack_range) + _EPSILON and distance < best_distance:
			best = other
			best_distance = distance
	return best

func _find_nearest_enemy_ahead(unit):
	var best = null
	var best_distance := INF
	for other in units:
		if other == unit or not other.is_alive() or not unit.is_enemy(other):
			continue
		if not _is_ahead(unit, other):
			continue
		var distance := absf(other.progress - unit.progress)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best

func _is_ahead(unit, other) -> bool:
	if unit.get_direction() > 0:
		return other.progress >= unit.progress
	return other.progress <= unit.progress

# 单位前方尽头的敌塔在攻击范围内则返回它，否则 null。
func _find_enemy_tower_in_range(unit):
	var tower = _enemy_tower_for(unit)
	if tower == null or not tower.is_alive():
		return null
	var distance := absf(_enemy_tower_end(unit) - float(unit.progress))
	if distance <= float(unit.attack_range) + _EPSILON:
		return tower
	return null

# 该单位推进方向尽头当前应攻击的敌方塔：先打该端主塔（侧路公主 / 中路王塔）；
# 主塔被摧毁后转打该端兜底王塔（V2-1）；都不可打则返回 null。
func _enemy_tower_for(unit):
	var forward: bool = unit.get_direction() > 0
	var primary = tower_at_end if forward else tower_at_start
	if primary != null and primary.is_alive() and primary.owner_id != unit.owner_id:
		return primary
	var king = king_at_end if forward else king_at_start
	if king != null and king.is_alive() and king.owner_id != unit.owner_id:
		return king
	return null

# 单位推进方向尽头的 lane 进度：向 1 推进打 end(1.0)，向 0 推进打 start(0.0)。
# 主塔与兜底王塔同处该端，故按方向取位置（不依赖塔对象身份）。
func _enemy_tower_end(unit) -> float:
	return 1.0 if unit.get_direction() > 0 else 0.0

func _remove_dead() -> void:
	for i in range(units.size() - 1, -1, -1):
		if not units[i].is_alive():
			units.remove_at(i)
