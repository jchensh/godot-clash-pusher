# V3-4c 测试：RunModifiers —— relic/节点 数值修正器引擎（叠加正确、不污染 base）。
extends "res://tests/test_case.gd"

const RunModifiersScript = preload("res://logic/run_modifiers.gd")

func _base() -> Dictionary:
	return {
		"elixir_regen_rate": 1.0,
		"elixir_max": 10,
		"match_duration": 180,
		"tower_hp": {"king": 2400, "princess": 1400},
	}

func test_empty_mods_passthrough_plus_default_start() -> void:
	var eff := RunModifiersScript.effective_level(_base(), [])
	assert_almost_eq(float(eff["elixir_regen_rate"]), 1.0, 0.0001, "regen 不变")
	assert_almost_eq(float(eff["tower_hp"]["king"]), 2400.0, 0.0001, "king hp 不变")
	assert_almost_eq(float(eff.get("elixir_start", -1.0)), 0.0, 0.0001, "缺省起手圣水补 0")

func test_add_and_mult_single_source() -> void:
	var eff := RunModifiersScript.effective_level(_base(), [{"elixir_regen_rate": {"add": 0.3}, "tower_hp_king": {"mult": 1.5}}])
	assert_almost_eq(float(eff["elixir_regen_rate"]), 1.3, 0.0001, "+0.3 regen")
	assert_almost_eq(float(eff["tower_hp"]["king"]), 3600.0, 0.0001, "×1.5 king hp")
	assert_almost_eq(float(eff["tower_hp"]["princess"]), 1400.0, 0.0001, "princess 不受影响")

func test_stacking_two_sources() -> void:
	var mods := [{"elixir_regen_rate": {"add": 0.3}}, {"elixir_regen_rate": {"add": 0.2}}, {"tower_hp_princess": {"mult": 1.2}}]
	var eff := RunModifiersScript.effective_level(_base(), mods)
	assert_almost_eq(float(eff["elixir_regen_rate"]), 1.5, 0.0001, "两次 add 顺序叠加 = +0.5")
	assert_almost_eq(float(eff["tower_hp"]["princess"]), 1680.0, 0.0001, "×1.2 princess")

func test_does_not_mutate_base() -> void:
	var base := _base()
	RunModifiersScript.effective_level(base, [{"tower_hp_king": {"mult": 2.0}, "elixir_max": {"add": 5}}])
	assert_almost_eq(float(base["tower_hp"]["king"]), 2400.0, 0.0001, "base king hp 不被污染")
	assert_eq(int(base["elixir_max"]), 10, "base elixir_max 不被污染")

func test_elixir_start_modifier() -> void:
	var eff := RunModifiersScript.effective_level(_base(), [{"elixir_start": {"add": 4}}])
	assert_almost_eq(float(eff["elixir_start"]), 4.0, 0.0001, "起手圣水 +4")

func test_relic_mods_resolves_defs() -> void:
	var defs := {"r1": {"mods": {"elixir_max": {"add": 2}}}, "r2": {"mods": {"elixir_regen_rate": {"add": 0.3}}}, "bad": {}}
	var srcs := RunModifiersScript.relic_mods(["r1", "r2", "bad", "missing"], defs)
	assert_eq(srcs.size(), 2, "只解析含 mods 的 relic（bad/missing 跳过）")

func test_node_mod_lookup() -> void:
	var cfg := {"node_modifiers": {"boss": {"tower_hp_king": {"mult": 1.5}}}}
	assert_eq(RunModifiersScript.node_mod(cfg, "boss"), {"tower_hp_king": {"mult": 1.5}}, "boss 节点修正命中")
	assert_true(RunModifiersScript.node_mod(cfg, "battle").is_empty(), "battle 无修正 → 空")
	assert_true(RunModifiersScript.node_mod({}, "boss").is_empty(), "无 node_modifiers → 空")
