# T2 建筑索敌（target_priority:"buildings"）测试：只拆塔的 win-con。
# 覆盖：无视 aggro 内敌兵直锁敌塔 / 攻塔不打身边兵 / 朝塔推进不被侧兵勾走 / 缺省 nearest 仍分心（零回归）。
extends "res://tests/test_case.gd"

const ArenaScript = preload("res://logic/arena.gd")
const BattleScript = preload("res://logic/battle.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

func _battle_arena():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	var arena = battle.build_arena(loader.get_level("level_01"), loader.get_arena("default"))
	return [battle, arena]

func _unit(arena, owner: int, pos: Vector2, cfg: Dictionary):
	var u = UnitScript.new("u", owner, cfg, pos)
	arena.add_unit(u)
	return u

# 只拆塔兵（building-target）；move 可覆写。
func _bt_cfg(move: float = 0.0) -> Dictionary:
	return {
		"hp": 1000.0, "damage": 50.0, "attack_speed": 1.0, "move_speed": move,
		"attack_range": 1.5, "aggro_radius": 5.0, "body_radius": 0.0,
		"target_type": "ground", "attack_targets": "ground", "target_priority": "buildings",
	}

# 普通兵（缺省 nearest）：与上同参但不设 target_priority。
func _normal_cfg(move: float = 0.0) -> Dictionary:
	return {
		"hp": 1000.0, "damage": 50.0, "attack_speed": 1.0, "move_speed": move,
		"attack_range": 1.5, "aggro_radius": 5.0, "body_radius": 0.0,
		"target_type": "ground", "attack_targets": "ground",
	}

func _still_enemy(arena, pos: Vector2, hp: float = 300.0):
	var cfg := {
		"hp": hp, "damage": 0.0, "attack_speed": 1.0, "move_speed": 0.0,
		"attack_range": 1.0, "aggro_radius": 0.0, "body_radius": 0.0, "target_type": "ground",
	}
	return _unit(arena, UnitScript.OWNER_OPPONENT, pos, cfg)

func test_building_targeter_ignores_unit_locks_tower() -> void:
	var arena = _battle_arena()[1]
	var hog = _unit(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20), _bt_cfg())
	_still_enemy(arena, Vector2(9, 18))   # 敌兵在 aggro 内(dist 2<5)
	arena.tick(0.1)
	assert_true(arena.towers.has(hog.current_target), "建筑索敌兵无视 aggro 内敌兵、直锁敌塔")

func test_normal_unit_still_distracted_regression() -> void:
	var arena = _battle_arena()[1]
	var n = _unit(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20), _normal_cfg())
	var e = _still_enemy(arena, Vector2(9, 18))
	arena.tick(0.1)
	assert_eq(n.current_target, e, "普通兵(target_priority 缺省)仍被 aggro 内敌兵分心（零回归）")

func test_building_targeter_attacks_tower_not_adjacent_unit() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	# 站敌方左公主塔(4.5,8)前射程内(dist 2 ≤ 1.5+塔半径1.5)，身边紧贴一敌兵。
	var hog = _unit(arena, UnitScript.OWNER_PLAYER, Vector2(4.5, 10.0), _bt_cfg())
	var e = _still_enemy(arena, Vector2(4.5, 10.6))   # 紧贴 hog、在 aggro 内
	var before: float = battle.total_tower_hp(battle.opponent_towers)
	arena.tick(0.1)
	assert_true(arena.towers.has(hog.current_target), "锁敌塔而非身边敌兵")
	assert_true(battle.total_tower_hp(battle.opponent_towers) < before, "攻击敌塔（敌方总塔血下降）")
	assert_almost_eq(e.hp, 300.0, 0.0001, "身边敌兵不被攻击（只拆塔）")

func test_building_targeter_advances_to_tower_ignoring_side_unit() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	var hog = _unit(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20), _bt_cfg(3.0))
	_still_enemy(arena, Vector2(6, 20))   # 侧边敌兵(dist 3 < aggro 5)
	var y0: float = hog.pos.y
	for i in 30:
		battle.step(0.1)
	assert_true(hog.pos.y < y0 - 2.0, "建筑索敌兵朝敌塔推进(y 减小)、不被侧边敌兵勾走; y0=%.1f y=%.1f" % [y0, hog.pos.y])
