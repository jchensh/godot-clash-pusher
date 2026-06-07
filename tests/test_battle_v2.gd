# V2-1 测试：3-lane 拓扑 + 侧路公主塔倒后转打王塔（纯逻辑）。
# 验收：3 条 lane 各自独立推进/碰撞；中路通王塔、侧路通公主；
#       侧路公主毁后单位转打该端王塔；王塔归零判负、超时比塔血规则不变。
extends "res://tests/test_case.gd"

const BattleScript = preload("res://logic/battle.gd")
const TowerScript = preload("res://logic/tower.gd")
const LaneScript = preload("res://logic/lane.gd")
const UnitScript = preload("res://logic/unit.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _unit_config(
		hp: float = 100.0,
		damage: float = 50.0,
		attack_speed: float = 1.0,
		move_speed: float = 0.5,
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

func _level(match_duration: float = 180.0, king_hp: float = 2400.0, princess_hp: float = 1400.0) -> Dictionary:
	return {"match_duration": match_duration, "tower_hp": {"king": king_hp, "princess": princess_hp}}

# ---- 拓扑 ----

func test_build_v2_creates_three_lanes_and_six_towers() -> void:
	var battle = BattleScript.new()
	var lanes = battle.build_v2_three_lanes(_level())
	assert_eq(lanes.size(), 3, "三条 lane")
	assert_eq(battle.player_towers.size(), 3, "玩家 1 王 + 2 公主")
	assert_eq(battle.opponent_towers.size(), 3, "对手 1 王 + 2 公主")
	assert_not_null(battle.get_lane(0), "存在 lane 0")
	assert_not_null(battle.get_lane(1), "存在 lane 1")
	assert_not_null(battle.get_lane(2), "存在 lane 2")
	assert_null(battle.get_lane(3), "无 lane 3")

func test_center_lane_connects_kings_sides_connect_princess() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level())
	var mid = battle.get_lane(1)
	assert_true(mid.tower_at_start.is_king(), "中路 start 是玩家王塔")
	assert_true(mid.tower_at_end.is_king(), "中路 end 是对手王塔")
	for li in [0, 2]:
		var side = battle.get_lane(li)
		assert_false(side.tower_at_start.is_king(), "侧路 start 是公主塔")
		assert_false(side.tower_at_end.is_king(), "侧路 end 是公主塔")
		assert_true(side.king_at_end.is_king(), "侧路挂对手王塔兜底")
		assert_true(side.king_at_start.is_king(), "侧路挂玩家王塔兜底")

# ---- 中路 / 侧路目标 ----

func test_center_lane_unit_hits_king() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level())
	var mid = battle.get_lane(1)
	mid.add_unit(UnitScript.new("p", UnitScript.OWNER_PLAYER, 1, _unit_config(100, 50, 1.0, 0.5, 0.1), 0.95))
	battle.step(0.1)
	assert_almost_eq(battle.opponent_king.hp, 2350.0, 0.0001, "中路单位削对手王塔")

func test_side_lane_unit_hits_princess_not_king() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level())
	var left = battle.get_lane(0)
	var o_princess = left.tower_at_end
	left.add_unit(UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(100, 50, 1.0, 0.5, 0.1), 0.95))
	battle.step(0.1)
	assert_almost_eq(o_princess.hp, o_princess.max_hp - 50.0, 0.0001, "侧路单位先削公主塔")
	assert_almost_eq(battle.opponent_king.hp, battle.opponent_king.max_hp, 0.0001, "公主塔在场时王塔不受伤")

# ---- 核心：公主塔倒后转打王塔 ----

func test_side_princess_destroyed_unit_redirects_to_king() -> void:
	var battle = BattleScript.new()
	# 侧路公主塔仅 200 血，几次攻击即可摧毁；王塔满血，验证转火。
	battle.build_v2_three_lanes(_level(180.0, 2400.0, 200.0))
	var left = battle.get_lane(0)
	var o_princess = left.tower_at_end
	left.add_unit(UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(100, 50, 1.0, 0.5, 0.1), 0.0))
	for i in 120:   # 推到边界 → 拆公主 → 转打王塔
		battle.step(0.1)
	assert_true(o_princess.is_destroyed(), "侧路公主塔被摧毁")
	assert_true(battle.opponent_king.hp < battle.opponent_king.max_hp, "公主塔倒后单位转打王塔")
	assert_false(battle.is_over(), "公主塔毁本身不结束对局")

func test_shared_king_takes_damage_from_center_and_breached_side() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level(180.0, 2400.0, 100.0))
	# 中路单位直接打王塔；侧路单位拆完公主后也转打同一座王塔。
	battle.get_lane(1).add_unit(UnitScript.new("m", UnitScript.OWNER_PLAYER, 1, _unit_config(100, 50, 1.0, 0.5, 0.1), 0.95))
	battle.get_lane(2).add_unit(UnitScript.new("r", UnitScript.OWNER_PLAYER, 2, _unit_config(100, 50, 1.0, 0.5, 0.1), 0.0))
	var before: float = battle.opponent_king.hp
	for i in 120:
		battle.step(0.1)
		if battle.is_over():
			break
	assert_true(battle.opponent_king.hp < before, "同一座王塔承接中路与破侧路的双重伤害")

# ---- lane 相互独立 ----

func test_three_lanes_advance_independently() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level())
	# 仅 lane 0 放一个己方单位，lane 1/2 应毫无单位、毫无结算。
	battle.get_lane(0).add_unit(UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(100, 10, 1.0, 0.5, 0.1), 0.0))
	for i in 30:   # 走到 0.9（1.8s）并至少出手一次
		battle.step(0.1)
	assert_eq(battle.get_lane(0).get_units().size(), 1, "lane 0 有单位")
	assert_eq(battle.get_lane(1).get_units().size(), 0, "lane 1 无单位")
	assert_eq(battle.get_lane(2).get_units().size(), 0, "lane 2 无单位")
	# lane 0 的单位推进了，且只削 lane 0 对应公主塔。
	assert_true(battle.get_lane(0).tower_at_end.hp < battle.get_lane(0).tower_at_end.max_hp, "lane 0 公主塔被削")
	assert_almost_eq(battle.get_lane(2).tower_at_end.hp, battle.get_lane(2).tower_at_end.max_hp, 0.0001, "lane 2 公主塔未被波及")

func test_enemy_units_collide_only_within_same_lane() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level())
	# lane 0 放玩家单位，lane 2 放对手单位：分属不同 lane，互不交战。
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(100, 50, 1.0, 0.0, 0.1), 0.5)
	var o = UnitScript.new("o", UnitScript.OWNER_OPPONENT, 2, _unit_config(100, 50, 1.0, 0.0, 0.1), 0.5)
	battle.get_lane(0).add_unit(p)
	battle.get_lane(2).add_unit(o)
	for i in 5:
		battle.step(0.1)
	assert_almost_eq(p.hp, 100.0, 0.0001, "跨 lane 不交战：玩家单位满血")
	assert_almost_eq(o.hp, 100.0, 0.0001, "跨 lane 不交战：对手单位满血")

# ---- 胜负规则不变 ----

func test_destroying_king_via_center_lane_wins() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level(180.0, 100.0, 1400.0))   # 王塔仅 100 血
	battle.get_lane(1).add_unit(UnitScript.new("p", UnitScript.OWNER_PLAYER, 1, _unit_config(100, 60, 1.0, 0.5, 0.1), 0.95))
	for i in 31:
		battle.step(0.1)
	assert_true(battle.opponent_king.is_destroyed(), "对手王塔归零")
	assert_eq(battle.result, BattleScript.RESULT_PLAYER_WIN, "中路破王 → 玩家胜")

func test_timeout_compares_total_tower_hp_with_six_towers() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level(0.5, 2400.0, 1400.0))   # 0.5s 短局
	battle.opponent_towers[2].take_damage(500.0)               # 对手少 500 塔血
	for i in 6:
		battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_PLAYER_WIN, "超时比 6 塔血总和，玩家多者胜")

func test_timeout_equal_six_towers_is_draw() -> void:
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(_level(0.5))
	for i in 6:
		battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_DRAW, "6 塔血相等判平")

# ---- 真实配置烟雾 ----

func test_real_config_three_lanes() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	battle.build_v2_three_lanes(loader.get_level("level_01"))
	var knight = UnitScript.new("knight_body", UnitScript.OWNER_PLAYER, 1, loader.get_unit("knight_body"), 0.97)
	battle.get_lane(1).add_unit(knight)
	battle.step(0.1)
	assert_true(battle.opponent_king.hp < battle.opponent_king.max_hp, "真实配置：中路骑士削敌王塔")
