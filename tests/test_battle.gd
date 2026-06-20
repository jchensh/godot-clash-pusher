# V3-1b 测试：Battle 胜负判定（2D arena 版）。
# 单位攻击塔在 V3-1d/e 接入，故这里用「直接削塔血」验证胜负规则本身，与移动/战斗解耦。
extends "res://tests/test_case.gd"

const BattleScript = preload("res://logic/battle.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

var _loader

func setup() -> void:
	_loader = ConfigLoaderScript.new()
	_loader.load_all()

func _level(match_duration: float = 180.0, king_hp: float = 2400.0, princess_hp: float = 1400.0) -> Dictionary:
	return {"match_duration": match_duration, "tower_hp": {"king": king_hp, "princess": princess_hp}}

func _battle(match_duration: float = 180.0, king_hp: float = 2400.0, princess_hp: float = 1400.0):
	var battle = BattleScript.new()
	battle.build_arena(_level(match_duration, king_hp, princess_hp), _loader.get_arena("default"))
	return battle

func test_build_arena_creates_three_towers_per_side() -> void:
	var battle = _battle()
	assert_eq(battle.player_towers.size(), 3, "玩家三塔")
	assert_eq(battle.opponent_towers.size(), 3, "对手三塔")
	assert_not_null(battle.player_king, "玩家王塔已识别")
	assert_not_null(battle.opponent_king, "对手王塔已识别")
	assert_eq(battle.result, BattleScript.RESULT_ONGOING, "开局进行中")
	assert_almost_eq(battle.match_duration, 180.0, 0.0001, "对局时长来自配置")
	assert_not_null(battle.arena, "arena 已建")

func test_destroying_enemy_king_player_wins() -> void:
	var battle = _battle()
	battle.opponent_king.take_damage(battle.opponent_king.max_hp)
	battle.step(0.1)
	assert_true(battle.opponent_king.is_destroyed(), "敌方王塔归零")
	assert_eq(battle.result, BattleScript.RESULT_PLAYER_WIN, "玩家胜")
	assert_true(battle.is_over(), "对局结束")

func test_destroying_player_king_opponent_wins() -> void:
	var battle = _battle()
	battle.player_king.take_damage(battle.player_king.max_hp)
	battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_OPPONENT_WIN, "对手胜")

func test_princess_destruction_does_not_end_game() -> void:
	var battle = _battle()
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
	var battle = _battle(0.5, 2400.0, 1400.0)   # 0.5s 短局
	battle.opponent_king.take_damage(500.0)     # 对手剩余塔血更少
	for i in 6:
		battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_PLAYER_WIN, "超时比塔血，玩家多者胜")
	assert_true(battle.is_over(), "对局结束")

func test_timeout_equal_tower_hp_is_draw() -> void:
	var battle = _battle(0.5)
	for i in 6:
		battle.step(0.1)
	assert_eq(battle.result, BattleScript.RESULT_DRAW, "塔血相等判平")

func test_no_advance_after_game_over() -> void:
	var battle = _battle(0.5)
	for i in 6:
		battle.step(0.1)
	assert_true(battle.is_over(), "已结束")
	var elapsed_snapshot: float = battle.elapsed
	battle.step(0.1)
	assert_almost_eq(battle.elapsed, elapsed_snapshot, 0.0001, "结束后 step 不再推进时间")

func test_real_config_arena() -> void:
	var battle = BattleScript.new()
	battle.build_arena(_loader.get_level("level_01"), _loader.get_arena("default"))
	assert_eq(battle.player_towers.size(), 3, "真实配置：玩家三塔")
	assert_almost_eq(battle.match_duration, 180.0, 0.0001, "对局时长来自 level_01")
