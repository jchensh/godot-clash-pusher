# V5-S5：卡牌升阶（碎片+金币）+ 技能积木解锁（CardProgression ops）+ 战斗内生效。
extends "res://tests/test_case.gd"

const PlayerDataScript = preload("res://logic/player_data.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const CardProgressionScript = preload("res://logic/card_progression.gd")
const MatchScript = preload("res://logic/match.gd")
const UnitScript = preload("res://logic/unit.gd")

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

func _pd(config):
	var ids: Array = []
	for cid in config.cards:
		ids.append(cid)
	var p = PlayerDataScript.new()
	p.init_new(ids)
	return p

# —— CardProgression.effective_skills（ops 应用） ——
func test_effective_skills_count_add() -> void:
	var config = _config()
	var base = config.get_card("goblins").get("skills")
	var unlocks = config.get_card_progression("goblins").get("rank_unlocks")
	var eff = CardProgressionScript.effective_skills(base, unlocks, 2)
	assert_eq(int(eff[0]["count"]), 4, "goblins rank2 count 3→4")
	assert_eq(int(config.get_card("goblins").get("skills")[0]["count"]), 3, "base 不被改")

func test_effective_skills_rank1_no_change() -> void:
	var config = _config()
	var base = config.get_card("goblins").get("skills")
	var unlocks = config.get_card_progression("goblins").get("rank_unlocks")
	assert_eq(int(CardProgressionScript.effective_skills(base, unlocks, 1)[0]["count"]), 3, "rank1 不变")

func test_effective_skills_num_add_fireball() -> void:
	var config = _config()
	var base = config.get_card("fireball").get("skills")   # aoe_damage radius 3.0
	var unlocks = config.get_card_progression("fireball").get("rank_unlocks")
	assert_almost_eq(float(CardProgressionScript.effective_skills(base, unlocks, 2)[0]["radius"]), 3.5, 0.001, "fireball rank2 radius +0.5")

func test_effective_skills_unit_field_golem() -> void:
	var config = _config()
	var base = config.get_card("golem").get("skills")
	var unlocks = config.get_card_progression("golem").get("rank_unlocks")
	var ov = CardProgressionScript.effective_skills(base, unlocks, 2)[0].get("_unit_override", {})
	assert_eq(int(ov.get("death_spawn_count", 0)), 3, "golem rank2 死兵 → 3")

# —— 升阶动作 ——
func test_rank_up_spends_shards_and_gold() -> void:
	var config = _config()
	var p = _pd(config)
	p.gold = 10000
	p.cards["knight"]["shards"] = 100   # common rank_up[0] = {shards:20, gold:2000}
	assert_true(p.rank_up_card("knight", config), "升阶成功")
	assert_eq(int(p.card_state("knight").get("rank")), 2, "rank → 2")
	assert_eq(int(p.card_state("knight").get("shards")), 80, "扣 20 碎片")
	assert_eq(p.gold, 8000, "扣 2000 金币")

func test_rank_up_raises_level_cap() -> void:
	var config = _config()
	var p = _pd(config)
	p.gold = 100000
	p.cards["knight"]["shards"] = 1000
	p.cards["knight"]["level"] = 4   # rank1 上限 4
	assert_false(p.upgrade_card("knight", config), "rank1 满级不能升")
	assert_true(p.rank_up_card("knight", config), "升阶")
	assert_true(p.upgrade_card("knight", config), "升阶后可继续升级")
	assert_eq(int(p.card_state("knight").get("level")), 5, "level → 5")

func test_rank_up_blocked_at_max_and_insufficient() -> void:
	var config = _config()
	var p = _pd(config)
	p.gold = 100000
	p.cards["knight"]["shards"] = 10000
	p.cards["knight"]["rank"] = 3   # 已最高阶
	assert_false(p.rank_up_card("knight", config), "已达最高阶")
	var p2 = _pd(config)
	p2.gold = 100000
	p2.cards["knight"]["shards"] = 5   # < 20
	assert_false(p2.rank_up_card("knight", config), "碎片不足拒绝")
	assert_eq(int(p2.card_state("knight").get("rank")), 1, "rank 不变")

# —— 战斗内生效 ——
func test_rank_unlock_in_battle_goblins_count() -> void:
	var config = _config()
	var p = _pd(config)
	p.cards["goblins"]["rank"] = 2
	var m = MatchScript.new(config)
	m.setup_stage("stage_1_1", [], p)
	m.player.elixir.tick(50.0)
	var idx: int = m.player.deck.get_hand().find("goblins")
	assert_true(idx >= 0, "goblins 在手")
	assert_true(m.player.try_play_card(idx, Vector2(9, 20)), "出 goblins")
	var n := 0
	for u in m.battle.arena.units:
		if u.owner_id == UnitScript.OWNER_PLAYER and u.unit_id == "goblin_body":
			n += 1
	assert_eq(n, 4, "rank2 goblins 出 4 只（3+1）")

func test_unit_override_applies_in_spawn() -> void:
	var config = _config()
	var m = MatchScript.new(config)
	m.setup_stage("stage_1_1")
	var base = config.get_card("golem").get("skills")
	var unlocks = config.get_card_progression("golem").get("rank_unlocks")
	var eff = CardProgressionScript.effective_skills(base, unlocks, 2)
	m.skill_system.play_card("golem", UnitScript.OWNER_PLAYER, Vector2(9, 20), 1.0, eff)
	var g = null
	for u in m.battle.arena.units:
		if u.unit_id == "golem_body":
			g = u
	assert_not_null(g, "golem 入场")
	assert_eq(g.death_spawn_count, 3, "_unit_override 生效：死兵 2→3")
