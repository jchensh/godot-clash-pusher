# V5-S8c：生成的 100 关 stages.json 内容校验（连续/线性序/系数曲线/boss/奖励）。
# 生成器 tools/build_stages.py 的运行时守护：结构性不变量在此把关；逐位 spec 一致由 `--check` 守。
extends "res://tests/test_case.gd"

const StageProgressScript = preload("res://logic/stage_progress.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

const STAGES_PER_CHAPTER := 10
const CHAPTERS := 10
const BOSS_MULT := 1.1

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

func test_config_loads_clean() -> void:
	var c = _config()
	assert_true(c.errors.is_empty(), "全配置（含 100 关）校验无误: %s" % str(c.errors))

# 恰好 100 关、章 1..10 × 关 1..10 连续无缺。
func test_exactly_100_continuous_stages() -> void:
	var c = _config()
	var present := {}
	var n := 0
	for sid in c.stages:
		if String(sid).begins_with("_"):
			continue
		n += 1
		var st = c.stages[sid]
		present["%d_%d" % [int(st["chapter"]), int(st["index"])]] = true
	assert_eq(n, CHAPTERS * STAGES_PER_CHAPTER, "共 100 关")
	for ch in range(1, CHAPTERS + 1):
		for idx in range(1, STAGES_PER_CHAPTER + 1):
			assert_true(present.has("%d_%d" % [ch, idx]), "stage_%d_%d 存在" % [ch, idx])

# 线性序：StageProgress 排序 stage_1_1 → stage_10_10，全局关序单调。
func test_linear_order() -> void:
	var c = _config()
	var sp = StageProgressScript.new(c.stages)
	var ids = sp.ordered_ids()
	assert_eq(ids.size(), 100, "有序 100 关")
	assert_eq(ids[0], "stage_1_1", "首关 stage_1_1")
	assert_eq(ids[99], "stage_10_10", "末关 stage_10_10")
	var prev := -1
	for sid in ids:
		var st = c.stages[sid]
		var g := int(st["chapter"]) * 100 + int(st["index"])
		assert_true(g > prev, "全局关序严格递增 @%s" % sid)
		prev = g

# 系数曲线：base coef(剥离 boss ×1.1) 沿全局关序严格递增 1.0→>2.5；boss(idx10) 系数 > 下一章首关（saw-tooth）。
func test_coef_curve_and_boss_spike() -> void:
	var c = _config()
	var base_by_gidx := {}
	for sid in c.stages:
		if String(sid).begins_with("_"):
			continue
		var st = c.stages[sid]
		var idx := int(st["index"])
		var gidx := (int(st["chapter"]) - 1) * STAGES_PER_CHAPTER + idx
		var coef := float(st["difficulty_coef"])
		assert_true(coef >= 1.0, "%s coef≥1.0" % sid)
		var is_boss := idx == STAGES_PER_CHAPTER
		base_by_gidx[gidx] = coef / (BOSS_MULT if is_boss else 1.0)
	var prev := 0.0
	for g in range(1, 101):
		var b := float(base_by_gidx[g])
		assert_true(b > prev, "base 系数严格递增 @gidx %d (%.3f>%.3f)" % [g, b, prev])
		prev = b
	assert_almost_eq(float(base_by_gidx[1]), 1.0, 0.001, "首关 base=1.0")
	assert_true(float(base_by_gidx[100]) > 2.5, "末关 base>2.5 (实 %.3f)" % float(base_by_gidx[100]))
	# boss 尖峰：每章 boss(idx10) > 下一章首关(idx1)。
	for ch in range(1, CHAPTERS):
		var boss = c.stages["stage_%d_10" % ch]
		var next1 = c.stages["stage_%d_1" % (ch + 1)]
		assert_true(float(boss["difficulty_coef"]) > float(next1["difficulty_coef"]),
			"ch%d boss 系数 > ch%d 首关（saw-tooth）" % [ch, ch + 1])

# 推荐战力：非 boss 关沿全局关序不降（boss 系数尖峰单独跳，跳过）。
func test_recommended_power_non_decreasing() -> void:
	var c = _config()
	var rec_by_gidx := {}
	for sid in c.stages:
		if String(sid).begins_with("_"):
			continue
		var st = c.stages[sid]
		var idx := int(st["index"])
		if idx == STAGES_PER_CHAPTER:
			continue
		rec_by_gidx[(int(st["chapter"]) - 1) * STAGES_PER_CHAPTER + idx] = int(st["recommended_power"])
	var prev := -1
	for g in range(1, 101):
		if not rec_by_gidx.has(g):
			continue
		assert_true(int(rec_by_gidx[g]) >= prev, "rec 不降 @gidx %d" % g)
		prev = int(rec_by_gidx[g])

# 每关字段齐：首通/重复金>0、3 星目标、encounter 存在、recommended_power>0。
func test_every_stage_has_rewards_and_stars() -> void:
	var c = _config()
	for sid in c.stages:
		if String(sid).begins_with("_"):
			continue
		var st = c.stages[sid]
		assert_true(int((st["first_clear"] as Dictionary)["gold"]) > 0, "%s 首通金>0" % sid)
		assert_true(int((st["repeat"] as Dictionary)["gold"]) > 0, "%s 重复金>0" % sid)
		assert_eq((st["stars"] as Array).size(), 3, "%s 3 星目标" % sid)
		assert_true(c.has_encounter(String(st["encounter"])), "%s encounter 存在" % sid)
		assert_true(int(st["recommended_power"]) > 0, "%s rec>0" % sid)

# A4(KAN-93)：全 48 卡在 100 关奖励里都有获取源（首通碎片 ∪ 概率掉落）——
# 锁死「32 张新卡 PvE 零获取」断层不复发。
func test_all_48_cards_obtainable_via_stage_rewards() -> void:
	var c = _config()
	var covered := {}
	for sid in c.stages:
		if String(sid).begins_with("_"):
			continue
		var st = c.stages[sid]
		for cid in ((st["first_clear"] as Dictionary).get("shards", {}) as Dictionary):
			covered[str(cid)] = true
		for cid in (st.get("shard_drop", {}) as Dictionary):
			covered[str(cid)] = true
	for cid in c.cards:
		assert_true(covered.has(str(cid)), "卡 %s 在 100 关奖励中有获取源" % str(cid))
	assert_eq(covered.size(), c.cards.size(), "奖励覆盖数 == 卡池数（48）")

# A4(KAN-93)：三国章节名——i18n zh/en 各有 chapter_1..10，且 zh 与 stages_spec 章名一致。
func test_chapter_names_i18n_complete_and_consistent() -> void:
	var i18n_raw = JSON.parse_string(FileAccess.get_file_as_string("res://config/i18n.json"))
	var spec = JSON.parse_string(FileAccess.get_file_as_string("res://config/stages_spec.json"))
	assert_true(typeof(i18n_raw) == TYPE_DICTIONARY and typeof(spec) == TYPE_DICTIONARY, "i18n/spec 可解析")
	var spec_names := {}
	for ch in (spec["chapters"] as Array):
		spec_names[int(ch["chapter"])] = str(ch["name"])
	for n in range(1, CHAPTERS + 1):
		var key := "chapter_%d" % n
		assert_true((i18n_raw["zh"] as Dictionary).has(key), "i18n zh 有 %s" % key)
		assert_true((i18n_raw["en"] as Dictionary).has(key), "i18n en 有 %s" % key)
		assert_eq(str((i18n_raw["zh"] as Dictionary)[key]), str(spec_names[n]),
				"章 %d i18n zh 与 spec 章名一致" % n)
