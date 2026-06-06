# Step 5 测试：Battle 胜负判定 + 单位推塔（Lane↔Tower 接线，纯逻辑）。
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

func test_build_v1_creates_three_towers_per_side() -> void:
	var battle = BattleScript.new()
	battle.build_v1_single_lane(_level())
	assert_eq(battle.player_towers.size(), 3, "玩家三塔")
	assert_eq(battle.opponent_towers.size(), 3, "对手三塔")
	assert_not_null(battle.player_king, "玩家王塔已识别")
	assert_not_null(battle.opponent_king, "对手王塔已识别")
	assert_eq(battle.result, BattleScript.RESULT_ONGOING, "开局进行中")
	assert_almost_eq(battle.match_duration, 180.0, 0.0001, "对局时长来自配置")

func test_player_unit_damages_enemy_king() -> void:
	var battle = BattleScript.new()
	var lane = battle.build_v1_single_lane(_level())
	# 玩家单位放在接近敌方王塔（progress 1）处，开局即在攻击范围内。
	var u = UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(100, 50, 1.0, 0.5, 0.1), 0.95)
	lane.add_unit(u)
	battle.step(0.1)
	assert_almost_eq(battle.opponent_king.hp, 2350.0, 0.0001, "敌方王塔被削 50")
	assert_eq(battle.result, BattleScript.RESULT_ONGOING, "未结束")

func test_destroying_enemy_king_player_wins() -> void:
	var battle = BattleScript.new()
	var lane = battle.build_v1_single_lane(_level(180.0, 100.0, 1400.0))   # 王塔仅 100 血
	var u = UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(100, 60, 1.0, 0.5, 0.1), 0.95)
	lane.add_unit(u)
	battle.step(0.1)   # 第一次出手：100 -> 40
	assert_false(battle.is_over(), "一次攻击未摧毁王塔")
	for i in 30:       # 冷却满后再次出手，足以打穿 40 血
		battle.step(0.1)
	assert_true(battle.opponent_king.is_destroyed(), "敌方王塔归零")
	assert_eq(battle.result, BattleScript.RESULT_PLAYER_WIN, "玩家胜")
	assert_true(battle.is_over(), "对局结束")

func test_opponent_unit_destroys_player_king() -> void:
	var battle = BattleScript.new()
	var lane = battle.build_v1_single_lane(_level(180.0, 100.0, 1400.0))
	var u = UnitScript.new("o", UnitScript.OWNER_OPPONENT, 0, _unit_config(100, 60, 1.0, 0.5, 0.1), 0.05)
	lane.add_unit(u)
	for i in 31:
		battle.step(0.1)
	assert_true(battle.player_king.is_destroyed(), "玩家王塔归零")
	assert_eq(battle.result, BattleScript.RESULT_OPPONENT_WIN, "对手胜")

func test_princess_destruction_does_not_end_game() -> void:
	var battle = BattleScript.new()
	battle.build_v1_single_lane(_level())
	var princess = null
	for t in battle.player_towers:
		if not t.is_king():
			princess = t
			break
	princess.take_damage(princess.max_hp)
	assert_true(princess.is_destroyed(), "公主塔已摧毁")
	battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_ONGOING, "公主塔毁不结束对局")
	assert_false(battle.is_over(), "对局继续")

func test_timeout_more_tower_hp_wins() -> void:
	var battle = BattleScript.new()
	battle.build_v1_single_lane(_level(0.5, 2400.0, 1400.0))   # 0.5s 短局
	battle.opponent_king.take_damage(500.0)                    # 对手剩余塔血更少
	for i in 6:
		battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_PLAYER_WIN, "超时比塔血，玩家多者胜")
	assert_true(battle.is_over(), "对局结束")

func test_timeout_equal_tower_hp_is_draw() -> void:
	var battle = BattleScript.new()
	battle.build_v1_single_lane(_level(0.5))
	for i in 6:
		battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_DRAW, "塔血相等判平")

func test_no_advance_after_game_over() -> void:
	var battle = BattleScript.new()
	battle.build_v1_single_lane(_level(0.5))
	for i in 6:
		battle.step(0.1)
	assert_true(battle.is_over(), "已结束")
	var elapsed_snapshot: float = battle.elapsed
	battle.step(0.1)
	assert_almost_eq(battle.elapsed, elapsed_snapshot, 0.0001, "结束后 step 不再推进时间")

func test_unit_stops_at_enemy_tower_edge() -> void:
	var battle = BattleScript.new()
	var lane = battle.build_v1_single_lane(_level())
	var u = UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(100, 10, 1.0, 0.5, 0.1), 0.0)
	lane.add_unit(u)
	for i in 50:       # 5s 足够走到尽头并持续攻击
		battle.step(0.1)
	assert_almost_eq(u.progress, 0.9, 0.0001, "停在攻击范围边界(1.0 - attack_range)，不穿塔")
	assert_true(battle.opponent_king.hp < battle.opponent_king.max_hp, "持续削敌王塔")

func test_real_config_battle() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	var lane = battle.build_v1_single_lane(loader.get_level("level_01"))
	var knight = UnitScript.new("knight_body", UnitScript.OWNER_PLAYER, 0, loader.get_unit("knight_body"), 0.97)
	lane.add_unit(knight)
	battle.step(0.1)
	assert_true(battle.opponent_king.hp < battle.opponent_king.max_hp, "真实配置：骑士削敌王塔")
	assert_almost_eq(battle.match_duration, 180.0, 0.0001, "对局时长来自 level_01")
