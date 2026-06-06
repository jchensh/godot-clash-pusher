# Step 7a 测试：Match 对局编排——双方对称 Player + 固定 tick 驱动（纯逻辑）。
extends "res://tests/test_case.gd"

const MatchScript = preload("res://logic/match.gd")
const BattleScript = preload("res://logic/battle.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

func _match():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var m = MatchScript.new(loader)
	m.setup("level_01")
	return m

func test_setup_builds_two_players_and_battle() -> void:
	var m = _match()
	assert_not_null(m.player, "玩家存在")
	assert_not_null(m.opponent, "对手存在")
	assert_eq(m.player.owner_id, UnitScript.OWNER_PLAYER, "玩家 owner")
	assert_eq(m.opponent.owner_id, UnitScript.OWNER_OPPONENT, "对手 owner")
	assert_not_null(m.battle, "battle 存在")
	assert_eq(m.player.deck.total(), 8, "玩家满 8 张牌组")
	assert_eq(m.opponent.deck.total(), 8, "对手满 8 张牌组")
	assert_false(m.is_over(), "开局进行中")
	assert_eq(m.get_result(), BattleScript.RESULT_ONGOING, "结果=进行中")

func test_starting_elixir_zero() -> void:
	var m = _match()
	assert_almost_eq(m.player.elixir.get_amount(), 0.0, 0.0001, "玩家起始圣水 0")
	assert_almost_eq(m.opponent.elixir.get_amount(), 0.0, 0.0001, "对手起始圣水 0")

func test_update_regens_both_players() -> void:
	var m = _match()
	m.update(1.0)                                   # 1s → 10 tick，各 +1.0 圣水
	assert_almost_eq(m.player.elixir.get_amount(), 1.0, 0.0001, "玩家回 1 圣水")
	assert_almost_eq(m.opponent.elixir.get_amount(), 1.0, 0.0001, "对手对称回 1 圣水")

func test_update_is_frame_rate_independent() -> void:
	# 同样 1 秒，一大帧 vs 多小帧 → 同样的圣水与对局时间（解耦渲染帧率）。
	var a = _match()
	var b = _match()
	a.update(1.0)
	for i in 10:
		b.update(0.1)
	assert_almost_eq(a.player.elixir.get_amount(), b.player.elixir.get_amount(), 0.0001, "圣水与帧率无关")
	assert_almost_eq(a.battle.elapsed, b.battle.elapsed, 0.0001, "对局时间与帧率无关")

func test_update_drives_battle_and_units_advance() -> void:
	var m = _match()
	m.update(5.0)                                   # 攒到 5 圣水
	var ok = m.player.try_play_card(0, 0, 0.1)      # 出骑士（费 3）
	assert_true(ok, "出牌成功")
	var lane = m.battle.get_lane(0)
	assert_eq(lane.get_units().size(), 1, "骑士入场")
	var p0: float = lane.get_units()[0].progress
	m.update(1.0)
	assert_true(lane.get_units()[0].progress > p0, "对局推进，骑士向敌塔前进")

func test_update_stops_when_over() -> void:
	var m = _match()
	m.battle.opponent_king.take_damage(m.battle.opponent_king.max_hp)
	m.battle.step(0.1)                              # 触发胜负判定 → 玩家胜
	assert_true(m.is_over(), "对局已结束")
	assert_eq(m.get_result(), BattleScript.RESULT_PLAYER_WIN, "玩家胜")
	var elapsed_before: float = m.battle.elapsed
	m.update(1.0)
	assert_almost_eq(m.battle.elapsed, elapsed_before, 0.0001, "结束后 update 不再推进")
