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

func _init(lane_index_: int = 0) -> void:
	lane_index = lane_index_

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

func _remove_dead() -> void:
	for i in range(units.size() - 1, -1, -1):
		if not units[i].is_alive():
			units.remove_at(i)
