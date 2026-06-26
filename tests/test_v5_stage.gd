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
func test_match_setup_stage_wires_coef_deck_ai() -> void:
	var config = _config()
	var m = MatchScript.new(config)
	m.setup_stage("stage_1_2")   # encounter=tank_push_a, coef=1.05, ai_difficulty=rookie
	assert_almost_eq(m.opponent.unit_stat_mult, 1.05, 0.0001, "敌方乘区=coef")
	assert_almost_eq(m.player.unit_stat_mult, 1.0, 0.0001, "我方默认 1.0")
	assert_eq(m.ai_difficulty, "rookie", "AI 档来自 stage")
	# headless 跑通一关：敌方出 giant（tank_push_a 含），被 coef 放大。
	m.opponent.elixir.tick(50.0)
	var idx: int = m.opponent.deck.get_hand().find("giant")
	assert_true(idx >= 0, "giant 在敌方手牌")
	var ok: bool = m.opponent.try_play_card(idx, Vector2(9, 11))
	assert_true(ok, "敌方出 giant 成功")
	var eu = null
	for u in m.battle.arena.units:
		if u.owner_id == UnitScript.OWNER_OPPONENT:
			eu = u
	assert_not_null(eu, "敌方生成单位")
	assert_almost_eq(eu.max_hp, 2100.0, 1.0, "giant 2000*1.05 被 coef 放大")
