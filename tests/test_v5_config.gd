# V5-S0：ConfigLoader 读取 4 张新表（stages/encounters/economy/card_progression）+ 交叉引用校验。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func test_loads_v5_tables() -> void:
	var loader = ConfigLoaderScript.new()
	var ok = loader.load_all()
	assert_true(ok, "ConfigLoader.load_all 应无错误: %s" % str(loader.errors))
	assert_false(loader.stages.is_empty(), "stages 非空")
	assert_false(loader.encounters.is_empty(), "encounters 非空")
	assert_false(loader.economy.is_empty(), "economy 非空")
	assert_false(loader.card_progression.is_empty(), "card_progression 非空")

func test_card_progression_covers_all_cards() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	for cid in loader.cards:
		var cp = loader.get_card_progression(cid)
		assert_false(cp.is_empty(), "card '%s' 应有 progression 条目" % cid)
		assert_true(["common", "rare", "epic", "legendary"].has(str(cp.get("rarity", ""))), "card '%s' rarity 合法" % cid)
		assert_true(cp.has("base_power"), "card '%s' 有 base_power" % cid)

func test_stage_refs_valid() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var seen := 0
	for sid in loader.stages:
		if String(sid).begins_with("_"):
			continue
		seen += 1
		var st = loader.get_stage(sid)
		assert_true(loader.has_encounter(str(st.get("encounter", ""))), "stage '%s' encounter 存在" % sid)
		assert_true(["rookie", "easy", "normal", "hard", "extreme"].has(str(st.get("ai_difficulty", ""))), "stage '%s' ai_difficulty 合法" % sid)
		assert_true(float(st.get("difficulty_coef", 0.0)) >= 1.0, "stage '%s' coef ≥1.0" % sid)
	assert_true(seen >= 2, "至少 2 个样例关")

func test_validation_catches_bad_stage_ref() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	assert_true(loader.errors.is_empty(), "基线无错误: %s" % str(loader.errors))
	# _ 前缀键应被跳过；坏 encounter 引用应被抓出。
	loader.stages["_bad_test"] = {}
	loader.stages["bad_stage"] = {"chapter": 1, "index": 99, "encounter": "NOPE", "difficulty_coef": 1.0, "ai_difficulty": "rookie"}
	loader._validate()
	var found_nope := false
	for e in loader.errors:
		assert_true(String(e).find("_bad_test") == -1, "_ 前缀键不应被校验")
		if String(e).find("NOPE") != -1:
			found_nope = true
	assert_true(found_nope, "应检测出不存在的 encounter 引用")
