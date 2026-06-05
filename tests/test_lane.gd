# Step 4 测试：Lane 推进与碰撞/攻击结算（纯逻辑，无物理引擎）。
extends "res://tests/test_case.gd"

const UnitScript = preload("res://logic/unit.gd")
const LaneScript = preload("res://logic/lane.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _unit_config(
		hp: float = 100.0,
		damage: float = 10.0,
		attack_speed: float = 1.0,
		move_speed: float = 0.2,
		attack_range: float = 0.1,
		target_type: String = "ground"
) -> Dictionary:
	return {
		"hp": hp,
		"damage": damage,
		"attack_speed": attack_speed,
		"move_speed": move_speed,
		"attack_range": attack_range,
		"target_type": target_type,
	}

func _make_unit(id: String, owner: int, progress: float, cfg: Dictionary = {}):
	if cfg.is_empty():
		cfg = _unit_config()
	return UnitScript.new(id, owner, 0, cfg, progress)

func test_add_unit_assigns_lane() -> void:
	var lane = LaneScript.new(2)
	var u = _make_unit("p", UnitScript.OWNER_PLAYER, 0.0)
	lane.add_unit(u)
	assert_eq(lane.get_units().size(), 1, "加入单位")
	assert_eq(u.lane_index, 2, "单位 lane_index 跟随 Lane")

func test_units_move_without_enemy() -> void:
	var lane = LaneScript.new(0)
	var player_unit = _make_unit("p", UnitScript.OWNER_PLAYER, 0.0)
	var opponent_unit = _make_unit("o", UnitScript.OWNER_OPPONENT, 1.0)
	var player_only = LaneScript.new(0)
	var opponent_only = LaneScript.new(0)
	player_only.add_unit(player_unit)
	opponent_only.add_unit(opponent_unit)

	player_only.tick(1.0)
	opponent_only.tick(1.0)
	assert_almost_eq(player_unit.progress, 0.2, 0.0001, "玩家单位向 1 推进")
	assert_almost_eq(opponent_unit.progress, 0.8, 0.0001, "对手单位向 0 推进")

func test_units_in_range_stop_and_damage_each_other() -> void:
	var lane = LaneScript.new(0)
	var p = _make_unit("p", UnitScript.OWNER_PLAYER, 0.45, _unit_config(100.0, 10.0, 1.0, 0.2, 0.1))
	var o = _make_unit("o", UnitScript.OWNER_OPPONENT, 0.55, _unit_config(100.0, 20.0, 1.0, 0.2, 0.1))
	lane.add_unit(p)
	lane.add_unit(o)

	lane.tick(0.1)
	assert_almost_eq(p.progress, 0.45, 0.0001, "接敌后停止推进")
	assert_almost_eq(o.progress, 0.55, 0.0001, "接敌后停止推进")
	assert_almost_eq(p.hp, 80.0, 0.0001, "受到敌方伤害")
	assert_almost_eq(o.hp, 90.0, 0.0001, "受到己方伤害")

func test_attack_cooldown_prevents_damage_every_tick() -> void:
	var lane = LaneScript.new(0)
	var p = _make_unit("p", UnitScript.OWNER_PLAYER, 0.45, _unit_config(100.0, 10.0, 1.0, 0.2, 0.1))
	var o = _make_unit("o", UnitScript.OWNER_OPPONENT, 0.55, _unit_config(100.0, 10.0, 1.0, 0.2, 0.1))
	lane.add_unit(p)
	lane.add_unit(o)

	lane.tick(0.1)
	lane.tick(0.1)
	assert_almost_eq(p.hp, 90.0, 0.0001, "第二个小 tick 仍在冷却，不重复扣血")
	assert_almost_eq(o.hp, 90.0, 0.0001, "第二个小 tick 仍在冷却，不重复扣血")
	lane.tick(0.9)
	assert_almost_eq(p.hp, 80.0, 0.0001, "冷却满后再次互伤")
	assert_almost_eq(o.hp, 80.0, 0.0001, "冷却满后再次互伤")

func test_dead_units_removed_after_combat() -> void:
	var lane = LaneScript.new(0)
	var p = _make_unit("p", UnitScript.OWNER_PLAYER, 0.45, _unit_config(10.0, 15.0, 1.0, 0.2, 0.1))
	var o = _make_unit("o", UnitScript.OWNER_OPPONENT, 0.55, _unit_config(10.0, 15.0, 1.0, 0.2, 0.1))
	lane.add_unit(p)
	lane.add_unit(o)

	lane.tick(0.1)
	assert_eq(lane.get_units().size(), 0, "死亡单位从 lane 移除")

func test_units_approach_then_fight() -> void:
	var lane = LaneScript.new(0)
	var p = _make_unit("p", UnitScript.OWNER_PLAYER, 0.0, _unit_config(100.0, 10.0, 1.0, 0.2, 0.1))
	var o = _make_unit("o", UnitScript.OWNER_OPPONENT, 1.0, _unit_config(100.0, 10.0, 1.0, 0.2, 0.1))
	lane.add_unit(p)
	lane.add_unit(o)

	for i in 30:
		lane.tick(0.1)
	assert_true(p.progress > 0.0, "玩家单位已推进")
	assert_true(o.progress < 1.0, "对手单位已推进")
	assert_true(p.hp < 100.0 and o.hp < 100.0, "相遇后发生互伤")

func test_nearest_enemy_in_range_is_targeted() -> void:
	var lane = LaneScript.new(0)
	var p = _make_unit("p", UnitScript.OWNER_PLAYER, 0.5, _unit_config(100.0, 10.0, 1.0, 0.2, 0.2))
	var near = _make_unit("near", UnitScript.OWNER_OPPONENT, 0.6, _unit_config(100.0, 10.0, 1.0, 0.2, 0.1))
	var far = _make_unit("far", UnitScript.OWNER_OPPONENT, 0.7, _unit_config(100.0, 10.0, 1.0, 0.2, 0.1))
	lane.add_unit(p)
	lane.add_unit(far)
	lane.add_unit(near)

	lane.tick(0.1)
	assert_almost_eq(near.hp, 90.0, 0.0001, "优先打最近敌人")
	assert_almost_eq(far.hp, 100.0, 0.0001, "较远敌人未被攻击")

func test_lane_accepts_real_config_units() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var lane = LaneScript.new(0)
	var knight = UnitScript.new("knight_body", UnitScript.OWNER_PLAYER, 0, loader.get_unit("knight_body"), 0.4)
	var goblin = UnitScript.new("goblin_body", UnitScript.OWNER_OPPONENT, 0, loader.get_unit("goblin_body"), 0.45)
	lane.add_unit(knight)
	lane.add_unit(goblin)

	lane.tick(0.1)
	assert_true(knight.hp < knight.max_hp or goblin.hp < goblin.max_hp, "真实配置单位可进入 lane 结算")
