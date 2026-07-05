# SceneRouter 单测（框架地基#1，KAN-99）。
#
# 覆盖：路由表完整性（路径存在 + view/ 根下 tscn 全登记）/ resolve 纯函数 / params 存取与
# 深拷贝隔离 / 转场幕布层结构（=100 恒压 MODAL/TOAST，静止不挡手）/ 规约扫描
# （view/net/ai 禁直调引擎切场景 API，唯一豁免 scene_router.gd）/ view 层脚本编译扫描
# （收编路径常量后防残留引用——对齐 test_runner 对 logic/ 的预检思想）。
# 注意：goto/reload 的换场行为需活树+渲染，headless 测不了——走真人验收（KAN-99 验收用例）。
extends "res://tests/test_case.gd"

const RouterScript = preload("res://view/scene_router.gd")
const UILayersScript = preload("res://view/ui/ui_layers.gd")

func test_routes_paths_exist() -> void:
	var r = RouterScript.new()
	for key in r.ROUTES:
		assert_true(FileAccess.file_exists(String(r.ROUTES[key])), "路由 %s 的场景文件存在" % key)
	r.free()

func test_view_root_scenes_all_registered() -> void:
	# 防「加了新场景忘登记路由」：view/ 根下每个 tscn 都必须在 ROUTES 里（子目录不管）。
	var r = RouterScript.new()
	var registered := {}
	for key in r.ROUTES:
		registered[String(r.ROUTES[key])] = true
	var d := DirAccess.open("res://view")
	assert_not_null(d, "view/ 可打开")
	if d != null:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir() and f.ends_with(".tscn"):
				assert_true(registered.has("res://view/" + f), "view/%s 已登记进 ROUTES" % f)
			f = d.get_next()
	r.free()

func test_resolve() -> void:
	var r = RouterScript.new()
	assert_eq(r.resolve("main_menu"), "res://view/main_menu.tscn", "路由名解析")
	assert_eq(r.resolve("res://view/settings.tscn"), "res://view/settings.tscn", "res:// 路径直通")
	assert_eq(r.resolve("no_such_route"), "", "未知路由返回空")
	r.free()

func test_params_roundtrip_and_isolation() -> void:
	var r = RouterScript.new()
	assert_eq(r.current_route(), "", "初始无路由历史")
	var p := {"stage_id": "s1", "nested": {"a": 1}}
	r._begin_route("stage_map", p)
	assert_eq(r.current_route(), "stage_map", "路由名记录")
	assert_eq(r.param("stage_id"), "s1", "param 取值")
	assert_eq(r.param("missing", "def"), "def", "param 默认值")
	p["stage_id"] = "s2"
	(p["nested"] as Dictionary)["a"] = 99
	assert_eq(r.param("stage_id"), "s1", "顶层深拷贝隔离：调用方改字典不影响路由参数")
	assert_eq((r.param("nested") as Dictionary)["a"], 1, "嵌套深拷贝隔离")
	r.free()

func test_curtain_layer_structure() -> void:
	var r = RouterScript.new()
	assert_true(r._layer is CanvasLayer, "幕布宿主是 CanvasLayer")
	assert_eq(r._layer.layer, 100, "幕布层=100")
	assert_true(r._layer.layer > UILayersScript.TOAST_LAYER, "恒高于 TOAST(90)")
	assert_true(r._layer.layer > UILayersScript.MODAL_LAYER, "恒高于 MODAL(50)")
	assert_almost_eq(r._dim.modulate.a, 0.0, 0.001, "静止时幕布全透明")
	assert_eq(r._dim.mouse_filter, Control.MOUSE_FILTER_IGNORE, "静止时不挡手")
	assert_almost_eq(r._dim.anchor_right, 1.0, 0.001, "幕布全屏锚 右")
	assert_almost_eq(r._dim.anchor_bottom, 1.0, 0.001, "幕布全屏锚 下")
	r.free()

func test_curtain_rect_resolved_in_tree() -> void:
	# 2026-07-06 P0 回归网：set_anchors_preset 只改锚点、保留当前矩形（新节点 0×0 → 幕布隐形且不挡输入）。
	# offline 测试树无视口尺寸（解析恒 0）则跳过——稳定防线是下方的源码封禁扫描；真实运行时几何
	# 已由 headless 实跑探针钉死（modal rect 720×1280）。
	var root := (Engine.get_main_loop() as SceneTree).root
	var r = RouterScript.new()
	root.add_child(r)
	var vp: Viewport = r._dim.get_viewport()
	var vps: Vector2 = vp.get_visible_rect().size if vp != null else Vector2.ZERO
	if vps.x > 1.0:
		var rs: Vector2 = r._dim.get_global_rect().size
		assert_true(rs.x > 1.0 and rs.y > 1.0, "转场幕布实际矩形已铺开（实测=%s）" % rs)
	root.remove_child(r)
	r.free()

func test_no_bare_set_anchors_preset_in_view() -> void:
	# 2026-07-06 P0 根因封禁：set_anchors_preset 只改锚点且保留当前矩形（新建节点=0×0 →
	# 弹层拦不到点击、幕布隐形——教程弹层 P0 的根因）。view 层想铺满一律 set_anchors_and_offsets_preset。
	var offenders: Array = []
	_scan_api_ban("res://view", offenders)
	assert_eq(offenders.size(), 0, "禁用裸 set_anchors_preset，违规: %s" % str(offenders))

func _scan_api_ban(dir_path: String, offenders: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."):
				_scan_api_ban(p, offenders)
		elif f.ends_with(".gd"):
			if FileAccess.get_file_as_string(p).contains("set_anchors_preset("):
				offenders.append(p)
		f = d.get_next()

func test_busy_queues_pending_last_wins() -> void:
	# 真人实测踩坑（2026-07-06 创号→引导战卡死）：转场中到达的 goto 不能丢，须暂存接力。
	# busy 分支在首个 await 之前同步返回，headless 可直接测；接力执行本身走真人验收。
	var r = RouterScript.new()
	r._busy = true
	r.goto("main_menu")
	assert_eq(r._pending, ["main_menu", {}], "转场中 goto 暂存待接力")
	r.goto("battle", {"x": 1})
	assert_eq(r._pending[0], "battle", "后到的重定向覆盖先到的（只接力最后一个）")
	assert_eq((r._pending[1] as Dictionary)["x"], 1, "params 一并暂存")
	r.free()

func test_no_direct_engine_scene_switch_in_client_code() -> void:
	# 规约（KAN-99）：切场景一律 Router.goto/reload；唯一豁免 = scene_router.gd 本体。
	var offenders: Array = []
	for dir in ["res://view", "res://net", "res://ai"]:
		_scan_banned(dir, offenders)
	assert_eq(offenders.size(), 0, "禁直调引擎切场景 API，违规文件: %s" % str(offenders))

func _scan_banned(dir_path: String, offenders: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."):
				_scan_banned(p, offenders)
		elif f.ends_with(".gd") and f != "scene_router.gd":
			var src := FileAccess.get_file_as_string(p)
			if src.contains("change_scene_to_file(") or src.contains("change_scene_to_packed(") \
					or src.contains("reload_current_scene("):
				offenders.append(p)
		f = d.get_next()

func test_view_scripts_compile() -> void:
	# 收编各文件路径常量后防残留引用：view 根 + view/ui 全量 load（编译失败 = can_instantiate false）。
	for dir_path in ["res://view", "res://view/ui"]:
		var d := DirAccess.open(dir_path)
		assert_not_null(d, dir_path + " 可打开")
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir() and f.ends_with(".gd"):
				var s = load(dir_path + "/" + f)
				assert_not_null(s, f + " 可加载")
				if s != null:
					assert_true((s as GDScript).can_instantiate(), f + " 编译通过（可实例化）")
			f = d.get_next()
