# Step 8 测试：AIController 规则 AI（简单进攻型，纯逻辑）。
extends "res://tests/test_case.gd"

const AIControllerScript = preload("res://ai/ai_controller.gd")
const MatchScript = preload("res://logic/match.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")
const DeckScript = preload("res://logic/deck.gd")
const BattleScript = preload("res://logic/battle.gd")

# 返回 [loader, match, ai]
func _setup():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var m = MatchScript.new(loader)
	m.setup("level_01")
	var ai = AIControllerScript.new(m, loader)
	return [loader, m, ai]

# AI V2-2 固定中路（lane 1）出兵，故在中路 lane 统计对手单位。
func _opponent_units(m) -> Array:
	var arr := []
	for u in m.battle.get_lane(1).get_units():
		if u.owner_id == UnitScript.OWNER_OPPONENT:
			arr.append(u)
	return arr

func test_waits_below_threshold() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.elixir.current = 5.0          # < 6
	ai.tick(0.1)
	assert_eq(_opponent_units(m).size(), 0, "圣水不足阈值不出牌")

func test_plays_most_expensive_affordable_troop() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)
	var us = _opponent_units(m)
	assert_eq(us.size(), 1, "出了一个兵")
	assert_eq(us[0].unit_id, "giant_body", "出最贵的能出的兵（巨人，费 5）")
	assert_eq(us[0].owner_id, UnitScript.OWNER_OPPONENT, "owner=对手")
	assert_almost_eq(us[0].progress, 0.9, 0.0001, "部署在自家塔前（progress 0.9）")
	assert_almost_eq(m.opponent.elixir.get_amount(), 5.0, 0.0001, "扣 5 圣水")

func test_respects_cooldown() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)                              # 出巨人，进入冷却
	m.opponent.elixir.current = 10.0          # 回满，验证冷却仍拦着
	ai.tick(0.1)
	assert_eq(_opponent_units(m).size(), 1, "冷却中不再出牌")
	for i in 12:                              # 过完冷却（1.0s）
		ai.tick(0.1)
	assert_true(_opponent_units(m).size() >= 2, "冷却结束后再次出牌")

func test_skips_spell_when_no_enemy() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.deck = DeckScript.new(["fireball", "arrows", "zap", "knight", "giant", "goblins", "minions", "archers"])
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)
	var us = _opponent_units(m)
	assert_eq(us.size(), 1, "出兵而非空放法术")
	assert_eq(us[0].unit_id, "knight_body", "跳过法术、出唯一的兵 knight")
	assert_almost_eq(m.opponent.elixir.get_amount(), 7.0, 0.0001, "扣 3(knight) 而非 4(fireball)")

func test_casts_spell_when_enemy_present() -> void:
	var ctx = _setup()
	var loader = ctx[0]
	var m = ctx[1]
	var ai = ctx[2]
	# 手牌里最贵的可用牌是法术（fireball 4 > knight 3 > goblins/zap 2）
	m.opponent.deck = DeckScript.new(["fireball", "knight", "goblins", "zap", "archers", "minions", "arrows", "giant"])
	m.opponent.elixir.current = 10.0
	var enemy = UnitScript.new("knight_body", UnitScript.OWNER_PLAYER, 1, loader.get_unit("knight_body"), 0.5)
	m.battle.get_lane(1).add_unit(enemy)   # 敌方单位放中路，AI 才会感知并放火球
	ai.tick(0.1)
	assert_true(enemy.hp < enemy.max_hp, "对面有敌方单位→AI 放火球削它")
	assert_eq(_opponent_units(m).size(), 0, "本次出的是法术，不是兵")

func test_full_match_with_ai_resolves() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.set_opponent_controller(ai)
	# 玩家（人类）不出牌；AI 自己推。跑到结束或上限。
	var ticks := 0
	while not m.is_over() and ticks < 2000:
		m.update(0.1)
		ticks += 1
	assert_true(m.is_over(), "一局能正常结束（不会永远不分胜负）")
	assert_true(m.battle.player_king.hp < m.battle.player_king.max_hp, "AI 主动出牌、单位削到了玩家王塔（确实在对抗）")
