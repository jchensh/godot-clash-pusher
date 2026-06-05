# 轻量 headless 测试 runner（零外部依赖）。
# 运行: godot --headless --script res://tests/test_runner.gd
# 自动发现 tests/ 下 test_*.gd（排除本文件与 test_case.gd），
# 执行其中 test_* 方法，汇总通过/失败，按结果 quit(0/1)。
extends SceneTree

func _initialize() -> void:
	var total := 0
	var passed := 0
	var failed := 0
	var failure_msgs: Array = []

	print("==== 开始测试 ====")
	for path in _discover_tests():
		var script: GDScript = load(path)
		if script == null:
			push_error("无法加载测试脚本: " + path)
			total += 1
			failed += 1
			failure_msgs.append("%s -> 无法加载测试脚本" % path.get_file())
			continue
		var file_name := path.get_file()
		var seen := {}
		for m in script.get_script_method_list():
			var method_name: String = m.name
			if not method_name.begins_with("test_"):
				continue
			if seen.has(method_name):
				continue
			seen[method_name] = true

			var instance = script.new()
			if instance.has_method("setup"):
				instance.call("setup")
			instance._failures.clear()
			instance.call(method_name)
			if instance.has_method("teardown"):
				instance.call("teardown")

			total += 1
			if instance._failures.is_empty():
				passed += 1
				print("  [PASS] %s::%s" % [file_name, method_name])
			else:
				failed += 1
				print("  [FAIL] %s::%s" % [file_name, method_name])
				for f in instance._failures:
					failure_msgs.append("%s::%s -> %s" % [file_name, method_name, f])

	print("\n==== 测试汇总: 共 %d, 通过 %d, 失败 %d ====" % [total, passed, failed])
	for f in failure_msgs:
		print("  ! " + f)

	quit(0 if failed == 0 else 1)

func _discover_tests() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		push_error("无法打开 res://tests 目录")
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() \
				and fname.begins_with("test_") and fname.ends_with(".gd") \
				and fname != "test_runner.gd" and fname != "test_case.gd":
			result.append("res://tests/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
