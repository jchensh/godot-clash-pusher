# Step 0 冒烟测试：仅用于验证测试闭环可用。
# Step 1 起会被真正的逻辑层测试替代/补充。
extends "res://tests/test_case.gd"

func test_harness_alive() -> void:
	assert_true(true, "测试 harness 正常运行")

func test_basic_math() -> void:
	assert_eq(2 + 2, 4, "基础算术")

func test_float_compare() -> void:
	assert_almost_eq(0.1 + 0.2, 0.3, 0.0001, "浮点近似比较")
