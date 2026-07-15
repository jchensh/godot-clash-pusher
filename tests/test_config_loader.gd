# Step 1 测试：ConfigLoader 读入三张 JSON + 校验 + 打印验证。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _make_loaded():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return loader

func test_v3_campaign_config_loaded() -> void:
	var loader = _make_loaded()
	assert_true(loader.errors.is_empty(), "配置加载无错: %s" % str(loader.errors))
	var camp = loader.get_campaign("default")
	assert_false(camp.is_empty(), "campaign default 存在")
	var lv = camp.get("levels", [])
	assert_eq((lv as Array).size(), 6, "战役 6 关")
	assert_eq(str((lv[0] as Dictionary).get("level_id")), "campaign_01", "首关 campaign_01")
	assert_true(loader.has_level("campaign_06"), "教学关 campaign_06 已入 levels")

func test_load_all_succeeds() -> void:
	var loader = ConfigLoaderScript.new()
	var ok = loader.load_all()
	assert_true(ok, "load_all 应成功; errors=%s" % str(loader.errors))
	assert_true(loader.errors.is_empty(), "不应有错误")

func test_excel_source_workbook_exists() -> void:
	assert_true(FileAccess.file_exists("res://config/GameConfig.xlsx"), "策划源表 GameConfig.xlsx 应存在")

func test_cards_loaded() -> void:
	var loader = _make_loaded()
	assert_true(loader.cards.size() > 0, "cards 非空")
	assert_true(loader.has_card("knight"), "应包含 knight")
	var knight = loader.get_card("knight")
	assert_eq(knight.get("elixir_cost"), 3, "knight 圣水消耗=3")
	assert_true(knight.get("skills") is Array, "knight.skills 是数组")
	assert_eq(knight["skills"][0].get("type"), "spawn_unit", "第一个技能积木是 spawn_unit")

func test_units_loaded() -> void:
	var loader = _make_loaded()
	assert_true(loader.has_unit("knight_body"), "应包含 knight_body")
	var kb = loader.get_unit("knight_body")
	assert_eq(kb.get("hp"), 600, "knight_body hp=600")
	assert_eq(kb.get("target_type"), "ground", "knight_body 是地面单位")

func test_levels_loaded() -> void:
	var loader = _make_loaded()
	assert_true(loader.has_level("level_01"), "应包含 level_01")
	var lv = loader.get_level("level_01")
	assert_eq(lv.get("elixir_max"), 10, "elixir_max=10")
	assert_eq(lv.get("tower_hp").get("king"), 2400, "国王塔血量=2400")
	assert_true((lv.get("player_deck") as Array).size() >= 1, "player_deck 非空")

func test_v2_7a_expanded_pool() -> void:
	# V2-7a 扩卡池：卡池扩到 ~14 卡 / ~9 单位，新增内容仍走三积木、零回归。
	var loader = _make_loaded()
	assert_true(loader.cards.size() >= 14, "卡池应扩到 >=14 张; 实际=%d" % loader.cards.size())
	assert_true(loader.units.size() >= 9, "单位应扩到 >=9 个; 实际=%d" % loader.units.size())
	for cid in ["mini_pekka", "musketeer", "skeletons", "baby_dragon", "lightning", "log"]:
		assert_true(loader.has_card(cid), "应包含新卡 %s" % cid)
	for uid in ["mini_pekka_body", "musketeer_body", "skeleton_body", "baby_dragon_body"]:
		assert_true(loader.has_unit(uid), "应包含新单位 %s" % uid)

func test_v2_7a_new_cards_well_formed() -> void:
	# 新卡的技能积木结构正确：兵牌 spawn_unit + 数量；法术 direct/aoe。
	var loader = _make_loaded()
	var skeletons = loader.get_card("skeletons")
	assert_eq(skeletons["skills"][0].get("type"), "spawn_unit", "skeletons 是 spawn_unit")
	assert_eq(int(skeletons["skills"][0].get("count")), 4, "skeletons 生成 4 个骷髅")
	var lightning = loader.get_card("lightning")
	assert_eq(lightning["skills"][0].get("type"), "direct_damage", "lightning 是 direct_damage")
	assert_eq(lightning["skills"][0].get("target"), "first_enemy_in_lane", "lightning 目标=first_enemy_in_lane")
	var log_card = loader.get_card("log")
	assert_eq(log_card["skills"][0].get("type"), "aoe_damage", "log 是 aoe_damage")
	# 新单位关键数值（air 单位至少一个、近战反坦克 mini_pekka 高伤）。
	assert_eq(loader.get_unit("baby_dragon_body").get("target_type"), "air", "小龙是空中单位")
	assert_true(int(loader.get_unit("mini_pekka_body").get("damage")) >= 200, "迷你皮卡高单发伤害")

func test_v2_7b_multi_level() -> void:
	# V2-7b 多关卡：每关=独立遭遇战、自带难度。V3-9 平衡：扩 5 档（rookie→extreme），5 关一档一关、修复撞名+断层。
	var loader = _make_loaded()
	assert_true(loader.levels.size() >= 5, "关卡应扩到 >=5 个; 实际=%d" % loader.levels.size())
	var expect := {"level_01": "rookie", "level_02": "easy", "level_05": "normal", "level_03": "hard", "level_04": "extreme"}
	for lid in expect:
		assert_true(loader.has_level(lid), "应包含关卡 %s" % lid)
		var lv = loader.get_level(lid)
		assert_eq(String(lv.get("ai_difficulty")), expect[lid], "%s 难度=%s" % [lid, expect[lid]])
		assert_true(["rookie", "easy", "normal", "hard", "extreme"].has(String(lv.get("ai_difficulty"))), "%s 难度合法" % lid)
		assert_eq((lv.get("player_deck") as Array).size(), 8, "%s player_deck 8 张" % lid)
		assert_eq((lv.get("ai_deck") as Array).size(), 8, "%s ai_deck 8 张" % lid)
	# 关卡数值差异化（节奏/时长）确实生效。
	assert_almost_eq(float(loader.get_level("level_04").get("elixir_regen_rate")), 2.0, 0.0001, "生死战双倍圣水回速")
	assert_eq(int(loader.get_level("level_04").get("match_duration")), 120, "生死战时长更短")

func test_v3_arena_config_loaded() -> void:
	# V3：arena.json 纳入 ConfigLoader 统一入口，含 default 场地（grid/river/deploy/towers）。
	var loader = _make_loaded()
	assert_false(loader.arena.is_empty(), "arena.json 应被加载")
	var a = loader.get_arena("default")
	assert_false(a.is_empty(), "应有 default 场地")
	for f in ["grid", "river", "deploy", "towers"]:
		assert_true(a.has(f), "arena.default 应含 %s" % f)
	assert_true(int((a.get("grid") as Dictionary).get("w", 0)) > 0, "网格宽>0")
	assert_true(int((a.get("grid") as Dictionary).get("h", 0)) > 0, "网格高>0")

func test_v3_run_config_loaded() -> void:
	# V3-4a：run.json 纳入 ConfigLoader 统一入口，含 default（starter_deck + 非空 acts）。
	var loader = _make_loaded()
	assert_false(loader.run.is_empty(), "run.json 应被加载")
	var r = loader.get_run("default")
	assert_false(r.is_empty(), "应有 default run")
	assert_true((r.get("starter_deck") as Array).size() == 8, "starter_deck 8 张")
	var acts = r.get("acts") as Array
	assert_eq(acts.size(), 3, "3 个 act（决策 36）")
	# 每个节点引用的 level 必须真实存在（交叉校验已在 load_all 跑过，这里再断言无错）。
	assert_true(loader.errors.is_empty(), "run 交叉引用应有效; errors=%s" % str(loader.errors))

func test_v3_relics_config_loaded() -> void:
	# V3-4c：relics.json 纳入 ConfigLoader；每个 relic 含 mods 对象。
	var loader = _make_loaded()
	assert_false(loader.relics.is_empty(), "relics.json 应被加载")
	assert_true(loader.relics.has("elixir_surge"), "应含 elixir_surge")
	var r = loader.get_relic("elixir_surge")
	assert_true(typeof(r.get("mods")) == TYPE_DICTIONARY, "relic 含 mods 对象")
	assert_true(loader.errors.is_empty(), "relic 校验无错; errors=%s" % str(loader.errors))

func test_missing_dir_reports_error() -> void:
	var loader = ConfigLoaderScript.new()
	var ok = loader.load_all("res://config_does_not_exist")
	assert_false(ok, "不存在的目录应失败")
	assert_false(loader.errors.is_empty(), "应记录错误信息")

func test_cross_reference_valid() -> void:
	# load_all 已做交叉引用校验：spawn_unit→unit、deck→card 全部存在则 errors 为空。
	var loader = _make_loaded()
	assert_true(loader.errors.is_empty(), "交叉引用应全部有效; errors=%s" % str(loader.errors))


func _server_files(loader) -> Dictionary:
	return {
		"cards.json": loader.cards.duplicate(true),
		"units.json": loader.units.duplicate(true),
		"levels.json": loader.levels.duplicate(true),
		"arena.json": loader.arena.duplicate(true),
		"run.json": loader.run.duplicate(true),
		"relics.json": loader.relics.duplicate(true),
		"campaign.json": loader.campaign.duplicate(true),
		"tutorial.json": loader.tutorial.duplicate(true),
		"audio_assets.json": loader.audio_assets.duplicate(true),
		"stages.json": loader.stages.duplicate(true),
		"encounters.json": loader.encounters.duplicate(true),
		"economy.json": loader.economy.duplicate(true),
		"card_progression.json": loader.card_progression.duplicate(true),
	}


func test_server_bundle_loads_and_validates() -> void:
	var disk = _make_loaded()
	var server = ConfigLoaderScript.new()
	assert_true(server.load_from_files(_server_files(disk)), "服务器 bundle 应通过完整校验: %s" % str(server.errors))
	assert_eq(server.cards.size(), disk.cards.size(), "服务端 cards 全量应用")
	assert_eq(server.get_card("knight").get("elixir_cost"), 3, "服务端配置可供战斗读取")


func test_bad_server_bundle_does_not_pollute_previous_snapshot() -> void:
	var disk = _make_loaded()
	var target = ConfigLoaderScript.new()
	assert_true(target.load_from_files(_server_files(disk)), "先装入有效快照")
	var before: Dictionary = target.cards.duplicate(true)
	var broken := _server_files(disk)
	broken.erase("units.json")
	assert_false(target.load_from_files(broken), "缺文件 bundle 必须拒绝")
	assert_false(target.errors.is_empty(), "拒绝原因可诊断")
	assert_eq(target.cards, before, "坏包不污染上一份可用快照")

func test_print_loaded_summary() -> void:
	# 满足验收「读入内存并打印验证」。
	var loader = _make_loaded()
	print("    [info] 已加载 cards=%d, units=%d, levels=%d" % [loader.cards.size(), loader.units.size(), loader.levels.size()])
	print("    [info] card ids: %s" % str(loader.cards.keys()))
	print("    [info] unit ids: %s" % str(loader.units.keys()))
	print("    [info] level ids: %s" % str(loader.levels.keys()))
	assert_true(true)
