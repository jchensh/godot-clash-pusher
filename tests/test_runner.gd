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

	# 预检：逻辑层脚本编译/可实例化校验（防"假绿"，见 HISTORY「test runner 加固」）。
	# 坏脚本（解析/编译失败）被测试 preload 后，.new() 会返回 null，其后对 null 的调用
	# 抛出的是运行时 SCRIPT ERROR——不会写入 _failures——于是用例被误判为 PASS，或整个
	# 测试文件因解析失败而被静默跳过（不计数）。两种情况汇总都"全绿"，掩盖坏代码。
	# 故在跑测试前先整体校验 res://logic：发现坏脚本即判失败并以非 0 退出，绝不放行。
	var broken_logic := _validate_logic_scripts()
	if not broken_logic.is_empty():
		print("\n==== 预检失败：以下逻辑脚本无法编译/实例化（测试中止，先修复再跑）====")
		for b in broken_logic:
			print("  ! " + b)
		print("==== 测试汇总: 中止于预检, 失败 %d ====" % broken_logic.size())
		quit(1)
		return

	for path in _discover_tests():
		var script: GDScript = load(path)
		# 测试脚本自身加载失败（null）或无法实例化（解析失败的脚本 load 后非 null 但
		# can_instantiate()==false）都计为失败，避免坏测试文件被静默跳过。
		if script == null or not script.can_instantiate():
			push_error("无法加载/实例化测试脚本: " + path)
			total += 1
			failed += 1
			failure_msgs.append("%s -> 无法加载/实例化测试脚本（解析失败？）" % path.get_file())
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
			# 实例化失败（如基类/依赖问题导致 .new() 返回 null）计为失败，
			# 否则后续访问 instance._failures 会抛运行时错误并被静默吞掉。
			if instance == null:
				total += 1
				failed += 1
				failure_msgs.append("%s::%s -> 测试实例化失败（script.new() 返回 null）" % [file_name, method_name])
				continue
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

# 校验 res://logic 下所有脚本能否编译并实例化（防"假绿"的核心）。
# 返回坏脚本的描述列表（空数组=全部正常）。
# can_instantiate()==false 恰好等价于"被 preload 后 .new() 会返回 null"——正是假绿的根因，
# 故用它作判据；它读取首次 load() 的编译结果，无重新编译副作用。
func _validate_logic_scripts() -> Array[String]:
	var broken: Array[String] = []
	var dir := DirAccess.open("res://logic")
	if dir == null:
		return broken   # 无 logic 目录则跳过（不卡纯测试场景）
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".gd"):
			var path := "res://logic/" + fname
			var res = load(path)
			if res == null:
				broken.append("%s -> load() 返回 null（脚本无法加载）" % fname)
			elif res is GDScript and not res.can_instantiate():
				broken.append("%s -> 编译失败/不可实例化（preload 后 .new() 将返回 null）" % fname)
		fname = dir.get_next()
	dir.list_dir_end()
	broken.sort()
	return broken

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
