# V5-S1：出兵数值乘区管线——Unit.apply_stat_mult + SkillSystem 透传 + Match 注入 + Player 透传。
# 验收：乘区缩放 hp/damage、不动 speed/range；乘区=1 时与现状逐位一致（零回归）。
extends "res://tests/test_case.gd"

const MatchScript = preload("res://logic/match.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

func _new_match():
	var c = ConfigLoaderScript.new()
	c.load_all()
	var m = MatchScript.new(c)
	m.setup("level_01")
	return m

func _units_of(m, owner_id: int) -> Array:
	var out: Array = []
	for u in m.battle.arena.units:
		if u.owner_id == owner_id:
			out.append(u)
	return out

# —— Unit.apply_stat_mult 直测：只缩放 hp/damage，其余不动 ——
func test_apply_stat_mult_scales_hp_and_damage_only() -> void:
	var cfg = {"hp": 100.0, "damage": 50.0, "attack_speed": 1.2, "move_speed": 1.6,
			"attack_range": 4.5, "aggro_radius": 5.0, "body_radius": 0.5}
	var u = UnitScript.new("x", 0, cfg, Vector2.ZERO)
	u.apply_stat_mult(2.0)
	assert_almost_eq(u.max_hp, 200.0, 0.001, "max_hp 翻倍")
	assert_almost_eq(u.hp, 200.0, 0.001, "hp 满到新 max")
	assert_almost_eq(u.damage, 100.0, 0.001, "damage 翻倍")
	assert_almost_eq(u.attack_speed, 1.2, 0.0001, "attack_speed 不缩放")
	assert_almost_eq(u.move_speed, 1.6, 0.0001, "move_speed 不缩放")
	assert_almost_eq(u.attack_range, 4.5, 0.0001, "attack_range 不缩放")
	assert_almost_eq(u.aggro_radius, 5.0, 0.0001, "aggro 不缩放")
	assert_almost_eq(u.body_radius, 0.5, 0.0001, "body 不缩放")

func test_apply_stat_mult_one_is_identity() -> void:
	var cfg = {"hp": 123.0, "damage": 45.0}
	var u = UnitScript.new("x", 0, cfg, Vector2.ZERO)
	u.apply_stat_mult(1.0)
	assert_eq(u.max_hp, 123.0, "mult=1 max_hp 逐位不变")
	assert_eq(u.hp, 123.0, "mult=1 hp 逐位不变")
	assert_eq(u.damage, 45.0, "mult=1 damage 逐位不变")

# —— SkillSystem.play_card 透传 stat_mult 到生成单位 ——
func test_play_card_scales_spawned_units() -> void:
	var m = _new_match()
	# units.json: knight_body hp=600 / damage=75 / move_speed=1.6
	m.skill_system.play_card("knight", UnitScript.OWNER_PLAYER, Vector2(9, 20), 2.0)
	var us = _units_of(m, UnitScript.OWNER_PLAYER)
	assert_eq(us.size(), 1, "生成 1 个 knight")
	assert_almost_eq(us[0].max_hp, 1200.0, 0.001, "600*2")
	assert_almost_eq(us[0].damage, 150.0, 0.001, "75*2")
	assert_almost_eq(us[0].move_speed, 1.6, 0.0001, "move_speed 不缩放")

func test_play_card_default_mult_unchanged() -> void:
	var m = _new_match()
	m.skill_system.play_card("knight", UnitScript.OWNER_PLAYER, Vector2(9, 20))  # 默认 mult=1
	var us = _units_of(m, UnitScript.OWNER_PLAYER)
	assert_eq(us.size(), 1)
	assert_almost_eq(us[0].max_hp, 600.0, 0.001, "默认不缩放 hp")
	assert_almost_eq(us[0].damage, 75.0, 0.001, "默认不缩放 damage")

# —— Match 注入双方乘区 ——
func test_match_set_stat_mults() -> void:
	var m = _new_match()
	m.set_stat_mults(1.5, 3.0)
	assert_almost_eq(m.player.unit_stat_mult, 1.5, 0.0001, "我方乘区注入")
	assert_almost_eq(m.opponent.unit_stat_mult, 3.0, 0.0001, "敌方乘区注入")

# —— Player.try_play_card 透传本方乘区（敌方缩放、我方不缩放）——
func test_try_play_card_threads_owner_mult() -> void:
	var m = _new_match()
	m.set_stat_mults(1.0, 3.0)        # 我方 1.0，敌方 3.0（模拟难度系数）
	m.opponent.elixir.tick(30.0)      # 充满敌方圣水
	var idx: int = m.opponent.deck.get_hand().find("knight")
	assert_true(idx >= 0, "knight 在敌方手牌")
	var ok: bool = m.opponent.try_play_card(idx, Vector2(9, 11))  # 敌方半场 y<=15
	assert_true(ok, "敌方出牌成功")
	var eus = _units_of(m, UnitScript.OWNER_OPPONENT)
	assert_eq(eus.size(), 1, "敌方生成 1 个 knight")
	assert_almost_eq(eus[0].max_hp, 1800.0, 0.1, "敌方 knight 600*3")
	assert_almost_eq(eus[0].damage, 225.0, 0.1, "敌方 dmg 75*3")
