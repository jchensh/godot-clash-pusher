# V2-6 测试：AIController 规则 AI（攻防结合 + 难度分级，纯逻辑）。
extends "res://tests/test_case.gd"

const AIControllerScript = preload("res://ai/ai_controller.gd")
const MatchScript = preload("res://logic/match.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")
const DeckScript = preload("res://logic/deck.gd")
const BattleScript = preload("res://logic/battle.gd")

# 返回 [loader, match, ai]；ai 默认读关卡难度（level_01 = normal）。
func _setup():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var m = MatchScript.new(loader)
	m.setup("level_01")
	var ai = AIControllerScript.new(m, loader)
	return [loader, m, ai]

# 某 lane 中对手（AI）单位。
func _units_in_lane(m, li: int) -> Array:
	var arr := []
	for u in m.battle.get_lane(li).get_units():
		if u.owner_id == UnitScript.OWNER_OPPONENT:
			arr.append(u)
	return arr

# 全 3 lane 的对手单位。
func _all_opponent_units(m) -> Array:
	var arr := []
	for li in [0, 1, 2]:
		arr.append_array(_units_in_lane(m, li))
	return arr

# 放一个玩家单位（敌方，对 AI 而言）到指定 lane / progress。
func _add_enemy(loader, m, lane_index: int, progress: float):
	var enemy = UnitScript.new("knight_body", UnitScript.OWNER_PLAYER, lane_index, loader.get_unit("knight_body"), progress)
	m.battle.get_lane(lane_index).add_unit(enemy)
	return enemy

# ---------- 基本出牌（normal 难度） ----------

func test_waits_below_threshold() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.elixir.current = 5.0          # normal 阈值 6
	ai.tick(0.1)
	assert_eq(_all_opponent_units(m).size(), 0, "圣水不足阈值不出牌")

func test_plays_most_expensive_affordable_troop() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)
	var us = _all_opponent_units(m)
	assert_eq(us.size(), 1, "出了一个兵")
	assert_eq(us[0].unit_id, "giant_body", "出最贵的能出的兵（巨人，费 5）")
	assert_eq(us[0].owner_id, UnitScript.OWNER_OPPONENT, "owner=对手")
	# 全塔满血时，最弱守军塔 = 公主(1400) < 王塔(2400)，集火取最小 index 的侧路 = lane 0。
	assert_eq(us[0].lane_index, 0, "集火最弱敌塔：起手打侧路公主（lane 0）")
	assert_almost_eq(us[0].progress, 0.9, 0.0001, "部署在自家塔前（progress 0.9）")
	assert_almost_eq(m.opponent.elixir.get_amount(), 5.0, 0.0001, "扣 5 圣水")

func test_respects_cooldown() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)                              # 出兵，进入冷却（normal 1.2s）
	m.opponent.elixir.current = 10.0          # 回满，验证冷却仍拦着
	ai.tick(0.1)
	assert_eq(_all_opponent_units(m).size(), 1, "冷却中不再出牌")
	for i in 13:                              # 过完 1.2s 冷却
		ai.tick(0.1)
	assert_true(_all_opponent_units(m).size() >= 2, "冷却结束后再次出牌")

func test_skips_spell_when_no_enemy() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.opponent.deck = DeckScript.new(["fireball", "arrows", "zap", "knight", "giant", "goblins", "minions", "archers"])
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)
	var us = _all_opponent_units(m)
	assert_eq(us.size(), 1, "出兵而非空放法术")
	assert_eq(us[0].unit_id, "knight_body", "跳过法术、出唯一的兵 knight")
	assert_almost_eq(m.opponent.elixir.get_amount(), 7.0, 0.0001, "扣 3(knight) 而非 4(fireball)")

func test_casts_spell_when_enemy_present() -> void:
	var ctx = _setup()
	var loader = ctx[0]
	var m = ctx[1]
	var ai = ctx[2]
	# 手牌里最贵可用是法术（fireball 4 > knight 3 > goblins/zap 2）
	m.opponent.deck = DeckScript.new(["fireball", "knight", "goblins", "zap", "archers", "minions", "arrows", "giant"])
	m.opponent.elixir.current = 10.0
	# 敌方单位放 progress 0.5（< 威胁线 0.55，不触发防守；用于验证进攻期法术削兵）
	var enemy = _add_enemy(loader, m, 1, 0.5)
	ai.tick(0.1)
	assert_true(enemy.hp < enemy.max_hp, "对面有敌方单位→AI 放火球削它")
	assert_eq(_all_opponent_units(m).size(), 0, "本次出的是法术，不是兵")

# ---------- 难度分级 ----------

func test_difficulty_threshold_differs_hard_vs_easy() -> void:
	# hard 阈值 4：圣水 5 即出牌。
	var ctx_h = _setup()
	var mh = ctx_h[1]
	var ai_h = AIControllerScript.new(mh, ctx_h[0], "hard")
	mh.opponent.elixir.current = 5.0
	ai_h.tick(0.1)
	assert_eq(_all_opponent_units(mh).size(), 1, "hard 阈值4：圣水5即出牌")
	# easy 阈值 8：圣水 5 不出牌。
	var ctx_e = _setup()
	var me = ctx_e[1]
	var ai_e = AIControllerScript.new(me, ctx_e[0], "easy")
	me.opponent.elixir.current = 5.0
	ai_e.tick(0.1)
	assert_eq(_all_opponent_units(me).size(), 0, "easy 阈值8：圣水5不出牌")

func test_difficulty_resolves_from_level() -> void:
	var ctx = _setup()
	var ai = ctx[2]
	assert_eq(ai.get_difficulty(), "normal", "未指定难度时读关卡 ai_difficulty（level_01=normal）")

# ---------- 防守（normal/hard 会防守，easy 不防守） ----------

func test_defends_threatened_lane() -> void:
	var ctx = _setup()
	var loader = ctx[0]
	var m = ctx[1]
	var ai = ctx[2]                           # normal
	_add_enemy(loader, m, 2, 0.6)             # 玩家单位越中线威胁 AI（lane 2, progress 0.6）
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)
	assert_eq(_units_in_lane(m, 2).size(), 1, "在受威胁 lane(2) 空投拦截兵")
	assert_eq(_units_in_lane(m, 0).size(), 0, "防守优先：未去进攻最弱塔的 lane 0")
	assert_almost_eq(_units_in_lane(m, 2)[0].progress, 0.9, 0.0001, "拦截兵部署在 AI 塔前")

func test_easy_ignores_threat_and_attacks_fixed_mid() -> void:
	var ctx = _setup()
	var loader = ctx[0]
	var m = ctx[1]
	var ai = AIControllerScript.new(m, loader, "easy")
	_add_enemy(loader, m, 2, 0.6)             # 威胁 lane 2
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)
	assert_eq(_units_in_lane(m, 1).size(), 1, "easy 不防守、固定中路出兵（lane 1）")
	assert_eq(_units_in_lane(m, 2).size(), 0, "easy 无视威胁，不在 lane 2 防守")

# ---------- 进攻选路：集火最弱敌塔 ----------

func test_smart_lane_focuses_weakest_tower() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]                           # normal
	m.battle.player_towers[2].hp = 100.0      # 右公主(lane 2)残血 → 最弱守军
	m.opponent.elixir.current = 10.0
	ai.tick(0.1)
	assert_eq(_units_in_lane(m, 2).size(), 1, "集火血量最低的敌塔所在 lane（lane 2）")
	assert_eq(_units_in_lane(m, 0).size(), 0, "不再选默认 lane 0")

# ---------- 整局自驱 ----------

func test_full_match_with_ai_resolves() -> void:
	var ctx = _setup()
	var m = ctx[1]
	var ai = ctx[2]
	m.set_opponent_controller(ai)
	var initial: float = m.battle.total_tower_hp(m.battle.player_towers)
	# 玩家（人类）不出牌；AI 自驱。跑到结束或上限（match_duration 180s = 1800 tick）。
	var ticks := 0
	while not m.is_over() and ticks < 2000:
		m.update(0.1)
		ticks += 1
	assert_true(m.is_over(), "一局能正常结束（不会永远不分胜负）")
	assert_true(m.battle.total_tower_hp(m.battle.player_towers) < initial, "AI 主动出牌、削到了玩家的塔（确实在对抗）")
