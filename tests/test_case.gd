# 极简单元测试基类。各测试文件用 `extends "res://tests/test_case.gd"`，
# 测试方法以 test_ 开头；断言失败时把信息推入 _failures，由 test_runner 收集。
# 逻辑层测试不依赖 Godot 渲染，可在 --headless 下运行。
extends RefCounted

# 每个测试方法运行前由 runner 清空；非空即代表该测试失败。
var _failures: Array = []

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		_failures.append("assert_true 失败: %s" % msg)

func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		_failures.append("assert_false 失败: %s" % msg)

func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		_failures.append("assert_eq 失败: 实际=%s, 期望=%s. %s" % [str(actual), str(expected), msg])

func assert_ne(actual, unexpected, msg: String = "") -> void:
	if actual == unexpected:
		_failures.append("assert_ne 失败: 两值相等=%s. %s" % [str(actual), msg])

func assert_almost_eq(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		_failures.append("assert_almost_eq 失败: 实际=%f, 期望=%f, eps=%f. %s" % [actual, expected, eps, msg])

func assert_null(value, msg: String = "") -> void:
	if value != null:
		_failures.append("assert_null 失败: 值=%s. %s" % [str(value), msg])

func assert_not_null(value, msg: String = "") -> void:
	if value == null:
		_failures.append("assert_not_null 失败: 值为 null. %s" % msg)
