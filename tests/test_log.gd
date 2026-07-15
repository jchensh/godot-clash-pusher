# Log 日志系统单测（框架地基#3，KAN-101）。
#
# 覆盖：级别过滤（min_level 门槛 + release 剥离语义）/ 输出格式（相对时间戳+级别标记）/
# sink 注入接管（单测捕获，w/e 不向引擎转发免噪声）/ 规约扫描（view/net/logic/ai 禁裸
# print；豁免 = view/log.gd 本体、net/proto/ godobuf 生成物；tests/tools/addons 不在扫描面）。
extends "res://tests/test_case.gd"

func teardown() -> void:
	# Log 是静态类：每个用例后还原全局态，防污染后续测试。
	Log._sink = Callable()
	Log.min_level = Log.DEBUG if OS.is_debug_build() else Log.INFO

func test_levels_filter() -> void:
	var got: Array = []
	Log._sink = func(line: String) -> void: got.append(line)
	Log.min_level = Log.INFO
	Log.d("debug 级应被剥离")
	assert_eq(got.size(), 0, "低于门槛不输出（release 剥离语义）")
	Log.i("info 通过")
	assert_eq(got.size(), 1, "达到门槛输出")
	Log.min_level = Log.DEBUG
	Log.d("debug 放行")
	assert_eq(got.size(), 2, "门槛降到 DEBUG 后 d 输出")

func test_warn_error_always_pass_gate() -> void:
	var got: Array = []
	Log._sink = func(line: String) -> void: got.append(line)
	Log.min_level = Log.INFO   # 两种构建的最高门槛
	Log.w("警告")
	Log.e("错误")
	assert_eq(got.size(), 2, "w/e 恒过门槛")
	assert_true(String(got[0]).contains("[W] 警告"), "W 级标记")
	assert_true(String(got[1]).contains("[E] 错误"), "E 级标记")

func test_format_timestamp_and_level() -> void:
	var got: Array = []
	Log._sink = func(line: String) -> void: got.append(line)
	Log.min_level = Log.DEBUG
	Log.i("你好")
	assert_eq(got.size(), 1, "输出一行")
	var line := String(got[0])
	assert_true(line.ends_with("[I] 你好"), "级别标记+原文在尾: " + line)
	var re := RegEx.new()
	re.compile("^\\[\\d{2,}:\\d{2}\\.\\d{3}\\]\\[I\\] ")
	assert_true(re.search(line) != null, "相对时间戳 [分:秒.毫秒]: " + line)

func test_no_bare_print_in_client_code() -> void:
	# 规约（KAN-101）：业务代码日志一律走 Log.d/i/w/e，禁裸 print 系。
	var re := RegEx.new()
	re.compile("\\bprint\\(|\\bprint_rich\\(|\\bprinterr\\(|\\bprint_debug\\(")
	var offenders: Array = []
	for dir in ["res://view", "res://net", "res://logic", "res://ai"]:
		_scan(dir, re, offenders)
	assert_eq(offenders.size(), 0, "禁裸 print，违规: %s" % str(offenders))

func _scan(dir_path: String, re: RegEx, offenders: Array) -> void:
	if dir_path == "res://net/proto":
		return   # godobuf 生成物：改了会被重新生成覆盖，豁免
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."):
				_scan(p, re, offenders)
		elif f.ends_with(".gd") and not (dir_path == "res://view" and f == "log.gd"):
			if re.search(FileAccess.get_file_as_string(p)) != null:
				offenders.append(p)
		f = d.get_next()
