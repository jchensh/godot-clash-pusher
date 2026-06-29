# V5-S3：闯关线性推进 + 解锁 + 星级判定 + Match 接 stage（coef/encounter/ai_difficulty）。
extends "res://tests/test_case.gd"

const StageProgressScript = preload("res://logic/stage_progress.gd")
const PlayerDataScript = preload("res://logic/player_data.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const UnitScript = preload("res://logic/unit.gd")

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

func _new_pd(config):
	var ids: Array = []
	for cid in config.cards:
		ids.append(cid)
	var p = PlayerDataScript.new()
	p.init_new(ids)
	return p

# —— 排序 + 解锁 + 推进 ——
func test_ordering_and_unlock() -> void:
	var config = _config()
	var sp = StageProgressScript.new(config.stages)
	var ids = sp.ordered_ids()
	assert_eq(ids[0], "stage_1_1", "首关 1_1")
	assert_eq(ids[1], "stage_1_2", "次关 1_2")
	var pd = _new_pd(config)
	assert_true(sp.is_unlocked("stage_1_1", pd), "首关恒解锁")
	assert_false(sp.is_unlocked("stage_1_2", pd), "次关初始锁定")
	assert_eq(sp.next_stage(pd), "stage_1_1", "下一关=首关")
	assert_false(sp.is_all_cleared(pd), "初始未全通关")

func test_apply_result_unlocks_next() -> void:
	var config = _config()
	var sp = StageProgressScript.new(config.stages)
	var pd = _new_pd(config)
	sp.apply_result("stage_1_1", 2, pd)
	assert_eq(int(pd.stages["stage_1_1"]["stars"]), 2, "星数记录")
	assert_true(bool(pd.stages["stage_1_1"]["cleared"]), "通关标记")
	assert_eq(pd.highest_cleared, "stage_1_1", "最高通关推进")
	assert_true(sp.is_unlocked("stage_1_2", pd), "1_1 通关 → 1_2 解锁")
	assert_eq(sp.next_stage(pd), "stage_1_2", "下一关推进")
	assert_eq(sp.chapter_stars(1, pd), 2, "章 1 星数累计")

func test_apply_result_star_max_not_regress() -> void:
	var config = _config()
	var sp = StageProgressScript.new(config.stages)
	var pd = _new_pd(config)
	sp.apply_result("stage_1_1", 3, pd)
	sp.apply_result("stage_1_1", 1, pd)   # 重打拿 1 星不应降级
	assert_eq(int(pd.stages["stage_1_1"]["stars"]), 3, "星数取 max 不回退")

func test_apply_result_zero_stars_noop() -> void:
	var config = _config()
	var sp = StageProgressScript.new(config.stages)
	var pd = _new_pd(config)
	sp.apply_result("stage_1_1", 0, pd)   # 未取胜
	assert_false(pd.stages.has("stage_1_1"), "未胜不推进")
	assert_eq(pd.highest_cleared, "", "未胜最高通关不变")

# —— 星级判定 ——
func test_judge_stars() -> void:
	var cfg = [{"goal": "win"}, {"goal": "king_hp_pct", "min": 0.5}, {"goal": "time_under", "sec": 120}]
	assert_eq(StageProgressScript.judge_stars(cfg, {"won": false}), 0, "败=0 星")
	assert_eq(StageProgressScript.judge_stars(cfg, {"won": true, "king_hp_pct": 0.2, "duration_sec": 150}), 1, "惨胜=1 星")
	assert_eq(StageProgressScript.judge_stars(cfg, {"won": true, "king_hp_pct": 0.8, "duration_sec": 150}), 2, "保塔慢=2 星")
	assert_eq(StageProgressScript.judge_stars(cfg, {"won": true, "king_hp_pct": 0.8, "duration_sec": 90}), 3, "完美=3 星")

# —— Match 接 stage：coef→敌方乘区、encounter→敌方卡组、ai_difficulty→AI ——
# 配置驱动（S8c 后 stages.json 由生成器铺 100 关，勿钉具体 coef/encounter/单位）：
# 验证 setup_stage 把 coef→敌方乘区、ai_difficulty→AI 档、encounter→敌方卡组 正确接线。
func test_match_setup_stage_wires_coef_deck_ai() -> void:
	var config = _config()
	var sid := "stage_1_2"
	var stage = config.get_stage(sid)
	var coef := float(stage["difficulty_coef"])
	var m = MatchScript.new(config)
	m.setup_stage(sid)
	assert_almost_eq(m.opponent.unit_stat_mult, coef, 0.0001, "敌方乘区=coef")
	assert_almost_eq(m.player.unit_stat_mult, 1.0, 0.0001, "我方默认 1.0")
	assert_eq(m.ai_difficulty, String(stage["ai_difficulty"]), "AI 档来自 stage")
	# headless 跑通：敌方出手牌里第一张 spawn 兵，验证 hp 被 coef 放大。
	m.opponent.elixir.tick(50.0)
	var hand: Array = m.opponent.deck.get_hand()
	var played := false
	for i in hand.size():
		var cid := String(hand[i])
		var spawn_uid := ""
		for sk in (config.get_card(cid).get("skills", []) as Array):
			if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
				spawn_uid = String(sk.get("unit_id", ""))
				break
		if spawn_uid == "":
			continue
		if not m.opponent.try_play_card(i, Vector2(9, 11)):
			continue
		var base_hp := float(config.get_unit(spawn_uid).get("hp", 0.0))
		var eu = null
		for u in m.battle.arena.units:
			if u.owner_id == UnitScript.OWNER_OPPONENT and u.unit_id == spawn_uid:
				eu = u
		assert_not_null(eu, "敌方生成单位 %s" % spawn_uid)
		assert_almost_eq(eu.max_hp, base_hp * coef, 1.0, "%s hp 被 coef 放大" % spawn_uid)
		played = true
		break
	assert_true(played, "敌方出了一张 spawn 兵并验证缩放")

# V5-S8d：敌塔 HP 随 coef 放大、我方塔不缩放。
func test_setup_stage_scales_enemy_towers_by_coef() -> void:
	var config = _config()
	var sid := "stage_5_5"   # coef > 1
	var stage = config.get_stage(sid)
	var coef := float(stage["difficulty_coef"])
	assert_true(coef > 1.0, "选个 coef>1 的关 (%.3f)" % coef)
	var base_level := String(stage.get("base_level", "ladder_01"))
	var base_king := float((config.get_level(base_level)["tower_hp"] as Dictionary)["king"])
	var m = MatchScript.new(config)
	m.setup_stage(sid)
	assert_almost_eq(m.battle.opponent_king.max_hp, base_king * coef, 1.0, "敌王塔 max_hp 随 coef 放大")
	assert_almost_eq(m.battle.opponent_king.hp, base_king * coef, 1.0, "敌王塔满血开局")
	assert_almost_eq(m.battle.player_king.max_hp, base_king, 1.0, "我方王塔不缩放")
	assert_almost_eq(m.battle.player_king.hp, base_king, 1.0, "我方王塔满血不缩放")

# 零回归：coef=1.0 的关（stage_1_1）敌塔不变。
func test_setup_stage_coef_one_towers_unchanged() -> void:
	var config = _config()
	var base_king := float((config.get_level("ladder_01")["tower_hp"] as Dictionary)["king"])
	var m = MatchScript.new(config)
	m.setup_stage("stage_1_1")   # coef 1.0
	assert_almost_eq(m.battle.opponent_king.max_hp, base_king, 1.0, "coef1.0 敌塔不缩放")
