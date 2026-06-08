# Step 1 测试：ConfigLoader 读入三张 JSON + 校验 + 打印验证。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _make_loaded():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return loader

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

func test_missing_dir_reports_error() -> void:
	var loader = ConfigLoaderScript.new()
	var ok = loader.load_all("res://config_does_not_exist")
	assert_false(ok, "不存在的目录应失败")
	assert_false(loader.errors.is_empty(), "应记录错误信息")

func test_cross_reference_valid() -> void:
	# load_all 已做交叉引用校验：spawn_unit→unit、deck→card 全部存在则 errors 为空。
	var loader = _make_loaded()
	assert_true(loader.errors.is_empty(), "交叉引用应全部有效; errors=%s" % str(loader.errors))

func test_print_loaded_summary() -> void:
	# 满足验收「读入内存并打印验证」。
	var loader = _make_loaded()
	print("    [info] 已加载 cards=%d, units=%d, levels=%d" % [loader.cards.size(), loader.units.size(), loader.levels.size()])
	print("    [info] card ids: %s" % str(loader.cards.keys()))
	print("    [info] unit ids: %s" % str(loader.units.keys()))
	print("    [info] level ids: %s" % str(loader.levels.keys()))
	assert_true(true)
