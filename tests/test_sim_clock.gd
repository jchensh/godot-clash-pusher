# Step 2 测试：SimClock 固定时间步长累加器（时间走逻辑 tick，不绑帧率）。
extends "res://tests/test_case.gd"

const SimClockScript = preload("res://logic/sim_clock.gd")
const ElixirScript = preload("res://logic/elixir.gd")

func test_one_full_tick() -> void:
	var c = SimClockScript.new()
	assert_eq(c.advance(0.1), 1, "0.1s = 1 tick")
	assert_eq(c.tick_count, 1, "总 tick 计数=1")

func test_accumulates_partial() -> void:
	var c = SimClockScript.new()
	assert_eq(c.advance(0.05), 0, "0.05s 不足一 tick")
	assert_eq(c.advance(0.05), 1, "再 0.05s 累计达 0.1 → 1 tick")

func test_multiple_ticks_with_remainder() -> void:
	var c = SimClockScript.new()
	assert_eq(c.advance(0.35), 3, "0.35s → 3 个 tick（0.3），余 0.05")
	assert_eq(c.advance(0.05), 1, "余 0.05 + 0.05 = 0.1 → 1 tick")

func test_zero_and_negative_dt() -> void:
	var c = SimClockScript.new()
	assert_eq(c.advance(0.0), 0, "dt=0 → 0 tick")
	assert_eq(c.advance(-5.0), 0, "dt<0 → 0 tick")

func test_spiral_protection() -> void:
	var c = SimClockScript.new()
	var n = c.advance(1000.0)
	assert_eq(n, SimClockScript.MAX_TICKS_PER_ADVANCE, "超大 dt 被钳制到上限")
	# 钳制后积压被清空：再喂正常 dt 不会爆量追帧
	assert_eq(c.advance(0.1), 1, "钳制后恢复正常节奏")

# 关键：帧率无关性 —— 相同真实时长、不同帧节奏，应得到相同的 tick 数与圣水。
func test_frame_rate_independence() -> void:
	# 跑法 A：10 帧 × 0.1s
	var clock_a = SimClockScript.new()
	var elixir_a = ElixirScript.new(10.0, 1.0, 0.0)
	for i in 10:
		var n = clock_a.advance(0.1)
		for t in n:
			elixir_a.tick(SimClockScript.TICK_DELTA)

	# 跑法 B：40 帧 × 0.025s（同样 1.0s 真实时长，帧率更高）
	var clock_b = SimClockScript.new()
	var elixir_b = ElixirScript.new(10.0, 1.0, 0.0)
	for i in 40:
		var n = clock_b.advance(0.025)
		for t in n:
			elixir_b.tick(SimClockScript.TICK_DELTA)

	assert_eq(clock_a.tick_count, clock_b.tick_count, "相同真实时长 → 相同 tick 数")
	assert_eq(clock_a.tick_count, 10, "1.0s @10Hz = 10 tick")
	assert_almost_eq(elixir_a.get_amount(), elixir_b.get_amount(), 0.0001, "圣水结果与帧率无关")
	assert_almost_eq(elixir_a.get_amount(), 1.0, 0.0001, "1.0s @1.0/s = 1.0 圣水")
