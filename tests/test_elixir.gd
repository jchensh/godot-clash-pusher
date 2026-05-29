# Step 2 测试：Elixir 圣水系统（回涨 / 扣除 / 封顶）。
extends "res://tests/test_case.gd"

const ElixirScript = preload("res://logic/elixir.gd")

func test_start_clamped() -> void:
	var e = ElixirScript.new(10.0, 1.0, 3.0)
	assert_almost_eq(e.get_amount(), 3.0, 0.0001, "起始值按 start 设置")

func test_start_clamped_to_max() -> void:
	var e = ElixirScript.new(10.0, 1.0, 15.0)
	assert_almost_eq(e.get_amount(), 10.0, 0.0001, "起始值不超过封顶")

func test_regen_over_time() -> void:
	var e = ElixirScript.new(10.0, 1.0, 0.0)
	e.tick(1.0)
	assert_almost_eq(e.get_amount(), 1.0, 0.0001, "1s @1.0/s = 1.0")
	e.tick(2.0)
	assert_almost_eq(e.get_amount(), 3.0, 0.0001, "再 2s = 3.0")

func test_regen_rate_scaling() -> void:
	var e = ElixirScript.new(10.0, 2.0, 0.0)
	e.tick(0.5)
	assert_almost_eq(e.get_amount(), 1.0, 0.0001, "0.5s @2.0/s = 1.0")

func test_regen_caps_at_max() -> void:
	var e = ElixirScript.new(10.0, 1.0, 0.0)
	e.tick(100.0)
	assert_almost_eq(e.get_amount(), 10.0, 0.0001, "回涨封顶到 maximum")
	assert_true(e.is_full(), "应为满")

func test_spend_success() -> void:
	var e = ElixirScript.new(10.0, 1.0, 5.0)
	var ok = e.spend(3.0)
	assert_true(ok, "圣水足够应扣除成功")
	assert_almost_eq(e.get_amount(), 2.0, 0.0001, "扣除后剩 2.0")

func test_spend_insufficient() -> void:
	var e = ElixirScript.new(10.0, 1.0, 2.0)
	var ok = e.spend(3.0)
	assert_false(ok, "圣水不足应失败")
	assert_almost_eq(e.get_amount(), 2.0, 0.0001, "失败不改变状态")

func test_spend_negative_rejected() -> void:
	var e = ElixirScript.new(10.0, 1.0, 5.0)
	assert_false(e.spend(-1.0), "负数扣除应拒绝")
	assert_almost_eq(e.get_amount(), 5.0, 0.0001, "状态不变")

func test_get_int_floors() -> void:
	var e = ElixirScript.new(10.0, 1.0, 0.0)
	e.tick(3.7)
	assert_eq(e.get_int(), 3, "3.7 圣水 → 可用整数 3")

func test_tick_ignores_nonpositive_dt() -> void:
	var e = ElixirScript.new(10.0, 1.0, 4.0)
	e.tick(0.0)
	e.tick(-1.0)
	assert_almost_eq(e.get_amount(), 4.0, 0.0001, "dt<=0 不推进")
