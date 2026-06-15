# V3-4d 测试：SaveSystem —— user:// 存读档往返一致（meta 持久 + run 可续跑）。
# 用临时路径并在 setup/teardown 清理，避免污染真实存档与跨测试串档。
extends "res://tests/test_case.gd"

const SaveScript = preload("res://logic/save_system.gd")
const MetaScript = preload("res://logic/meta_progress.gd")
const RunStateScript = preload("res://logic/run_state.gd")
const RunMapScript = preload("res://logic/run_map.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const BattleScript = preload("res://logic/battle.gd")

const META_TMP := "user://test_meta_save.json"
const RUN_TMP := "user://test_run_save.json"

func setup() -> void:
	SaveScript.clear_run_save(META_TMP)
	SaveScript.clear_run_save(RUN_TMP)

func teardown() -> void:
	SaveScript.clear_run_save(META_TMP)
	SaveScript.clear_run_save(RUN_TMP)

func _run_cfg() -> Dictionary:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return loader.get_run("default")

func _make_run():
	var cfg := _run_cfg()
	var map = RunMapScript.new()
	map.build(cfg)
	return RunStateScript.new(map, cfg.get("starter_deck", []), 99)

func test_meta_round_trip() -> void:
	var m = MetaScript.new()
	m.record_run_start()
	m.record_run_end(true)
	m.record_boss_defeated()
	SaveScript.save_meta(m, META_TMP)
	var loaded = SaveScript.load_meta(META_TMP)
	assert_eq(loaded.runs_started, 1, "runs_started 落盘往返")
	assert_eq(loaded.runs_won, 1, "runs_won 落盘往返")
	assert_eq(loaded.bosses_defeated, 1, "bosses_defeated 落盘往返")

func test_load_meta_missing_is_fresh() -> void:
	var loaded = SaveScript.load_meta(META_TMP)   # setup 已清空
	assert_eq(loaded.runs_started, 0, "无存档 → fresh meta（全 0）")

func test_run_round_trip() -> void:
	var run = _make_run()
	run.advance(BattleScript.RESULT_PLAYER_WIN)   # cursor→1, wins→1
	run.add_card("mini_pekka")                    # draft 后卡组增长
	run.add_relic("elixir_surge")
	SaveScript.save_run(run, RUN_TMP)
	assert_true(SaveScript.has_run_save(RUN_TMP), "存在 run 存档")
	var loaded = SaveScript.load_run(_run_cfg(), RUN_TMP)
	assert_not_null(loaded, "读回 run")
	assert_eq(loaded.cursor, 1, "进度 cursor 一致")
	assert_eq(loaded.wins, 1, "wins 一致")
	assert_eq(loaded.seed, 99, "seed 一致")
	assert_eq(loaded.deck, run.deck, "卡组一致（含 draft 增长的 mini_pekka）")
	assert_eq(loaded.relics, run.relics, "relic 一致")
	assert_eq(String(loaded.current_node().get("level_id")), String(run.current_node().get("level_id")), "地图重建后当前节点一致")

func test_clear_run_save() -> void:
	var run = _make_run()
	SaveScript.save_run(run, RUN_TMP)
	assert_true(SaveScript.has_run_save(RUN_TMP), "存档已写入")
	SaveScript.clear_run_save(RUN_TMP)
	assert_false(SaveScript.has_run_save(RUN_TMP), "清档后无存档")
	assert_null(SaveScript.load_run(_run_cfg(), RUN_TMP), "无档 load 返回 null")
