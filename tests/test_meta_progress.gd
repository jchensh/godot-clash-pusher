# V3-4d 测试：MetaProgress —— 局间统计 + 解锁解算。
extends "res://tests/test_case.gd"

const MetaScript = preload("res://logic/meta_progress.gd")

func _defs() -> Dictionary:
	return {
		"base_a": {"mods": {}},
		"base_b": {"mods": {}},
		"locked_win": {"mods": {}, "unlock": {"runs_won": 1}},
		"locked_boss": {"mods": {}, "unlock": {"bosses_defeated": 1}},
	}

func test_fresh_available_excludes_locked() -> void:
	var m = MetaScript.new()
	var avail := m.available_relics(_defs())
	assert_true("base_a" in avail and "base_b" in avail, "无门控 relic 始终可用")
	assert_false("locked_win" in avail, "未满足 runs_won → 锁定")
	assert_false("locked_boss" in avail, "未满足 bosses → 锁定")
	assert_true(m.unlocked_ids(_defs()).is_empty(), "无已解锁门控项")

func test_run_win_unlocks() -> void:
	var m = MetaScript.new()
	m.record_run_end(true)
	assert_eq(m.runs_won, 1, "记一次通关")
	assert_true("locked_win" in m.available_relics(_defs()), "通关 1 次 → 解锁 locked_win")
	assert_true("locked_win" in m.unlocked_ids(_defs()), "解锁解算含 locked_win")
	assert_false("locked_boss" in m.available_relics(_defs()), "boss 条件仍未满足")

func test_run_loss_does_not_count_win() -> void:
	var m = MetaScript.new()
	m.record_run_end(false)
	assert_eq(m.runs_won, 0, "败北不计通关")
	assert_false("locked_win" in m.available_relics(_defs()), "仍锁定")

func test_boss_defeat_unlocks() -> void:
	var m = MetaScript.new()
	m.record_boss_defeated()
	assert_true("locked_boss" in m.available_relics(_defs()), "击败 boss → 解锁 locked_boss")

func test_round_trip_dict() -> void:
	var m = MetaScript.new()
	m.record_run_start()
	m.record_run_start()
	m.record_run_end(true)
	m.record_boss_defeated()
	var m2 = MetaScript.new()
	m2.load_dict(m.to_dict())
	assert_eq(m2.runs_started, 2, "runs_started 往返")
	assert_eq(m2.runs_won, 1, "runs_won 往返")
	assert_eq(m2.bosses_defeated, 1, "bosses_defeated 往返")
