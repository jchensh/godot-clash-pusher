# V3-1g 测试：AIController 2D（攻防结合 + 按侧选向 + 难度分级）。确定性、无随机。
extends "res://tests/test_case.gd"

const MatchScript = preload("res://logic/match.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const ElixirScript = preload("res://logic/elixir.gd")
const UnitScript = preload("res://logic/unit.gd")

var _loader

func setup() -> void:
	_loader = ConfigLoaderScript.new()
	_loader.load_all()

func _match(level_id: String = "level_01"):
	var m = MatchScript.new(_loader)
	m.setup(level_id)
	return m

func _set_opp_elixir(m, amount: float) -> void:
	m.opponent.elixir = ElixirScript.new(10.0, 1.0, amount)

func _opp_units(m) -> Array:
	var out: Array = []
	for u in m.battle.arena.get_units():
		if u.owner_id == UnitScript.OWNER_OPPONENT and u.is_alive():
			out.append(u)
	return out

func _add_player_unit(m, pos: Vector2):
	var cfg := {
		"hp": 300.0, "damage": 0.0, "attack_speed": 1.0, "move_speed": 0.0,
		"attack_range": 1.0, "aggro_radius": 0.0, "body_radius": 0.0, "target_type": "ground",
	}
	var u = UnitScript.new("p_threat", UnitScript.OWNER_PLAYER, cfg, pos)
	m.battle.arena.add_unit(u)
	return u

func test_resolves_difficulty_from_match_or_override() -> void:
	var hard = _match("level_03")
	assert_eq(AIControllerScript.new(hard, _loader).get_difficulty(), "hard", "从关卡解析难度")
	var m = _match("level_01")
	assert_eq(AIControllerScript.new(m, _loader, "easy").get_difficulty(), "easy", "构造参数覆盖")

func test_threshold_gates_play() -> void:
	var m = _match()
	_set_opp_elixir(m, 5.0)                       # normal 阈值 7 > 5
	var ai = AIControllerScript.new(m, _loader, "normal")
	ai.tick(0.1)
	assert_eq(_opp_units(m).size(), 0, "圣水不足阈值 → 不出牌")
	assert_almost_eq(m.opponent.elixir.get_amount(), 5.0, 0.0001, "圣水未动")

func test_plays_most_expensive_troop_when_enough() -> void:
	var m = _match()
	_set_opp_elixir(m, 10.0)
	var ai = AIControllerScript.new(m, _loader, "normal")
	ai.tick(0.1)
	assert_eq(_opp_units(m).size(), 1, "出最贵可用兵（giant 费 5）入场")
	assert_almost_eq(m.opponent.elixir.get_amount(), 5.0, 0.0001, "扣 5 圣水(giant)")

func test_cooldown_between_plays() -> void:
	var m = _match()
	_set_opp_elixir(m, 10.0)
	var ai = AIControllerScript.new(m, _loader, "normal")
	ai.tick(0.1)
	var n := _opp_units(m).size()
	ai.tick(0.1)                                  # 冷却中（2.5s 未过）
	assert_eq(_opp_units(m).size(), n, "冷却期内不再出牌")

func test_easy_higher_threshold_than_hard() -> void:
	var hard = _match()
	_set_opp_elixir(hard, 5.0)
	AIControllerScript.new(hard, _loader, "hard").tick(0.1)
	assert_eq(_opp_units(hard).size(), 1, "hard 阈值 5 ≤ 5 → 出牌")
	var easy = _match()
	_set_opp_elixir(easy, 5.0)
	AIControllerScript.new(easy, _loader, "easy").tick(0.1)
	assert_eq(_opp_units(easy).size(), 0, "easy 阈值 9 > 5 → 不出牌")

func test_defends_threat_in_own_half() -> void:
	var m = _match()
	_set_opp_elixir(m, 10.0)
	_add_player_unit(m, Vector2(9, 12))          # 玩家单位越河进 AI 半场(y<=14 威胁线)
	var ai = AIControllerScript.new(m, _loader, "normal")
	ai.tick(0.1)
	assert_eq(_opp_units(m).size(), 1, "受威胁 → 空投拦截兵")
	assert_true(absf(_opp_units(m)[0].pos.x - 9.0) < 1.5, "拦截兵投在威胁单位 x 附近")

func test_smart_targets_weakest_tower_side() -> void:
	var m = _match()
	_set_opp_elixir(m, 10.0)
	# 削弱玩家右公主塔(13.5,24) → 智能 AI 集火该侧。
	for t in m.battle.player_towers:
		if not t.is_king() and absf(t.pos.x - 13.5) < 0.6:
			t.take_damage(t.max_hp - 100.0)
	var ai = AIControllerScript.new(m, _loader, "hard")
	ai.tick(0.1)
	assert_eq(_opp_units(m).size(), 1, "进攻出兵")
	assert_true(absf(_opp_units(m)[0].pos.x - 13.5) < 1.5, "集火最弱塔侧(x≈13.5)部署")
