# UI 层级骨架单测（PLAN_V5_UIFRAME F1，KAN-97/98）。
#
# 覆盖：层值序 / modal 推入·开闭·closed 信号 / 暗幕装配 / **GUI 输入隔离**（modal 开着时
# 场景层按钮收不到点击，且与节点建立顺序无关——KAN-98 树序 bug 的机制级验证）/
# DragScroll 对 modal 让路（双保险①）/ toast 落层与不挡手。
# 注意：--script 模式下 autoload 晚于测试执行，UI 实例由本文件手动挂 root（同脚本，等价 autoload）。
extends "res://tests/test_case.gd"

const UILayersScript = preload("res://view/ui/ui_layers.gd")
const ModalScript = preload("res://view/ui/modal.gd")
const DragScrollScript = preload("res://view/ui/drag_scroll.gd")

var _made: Array = []   # 本用例挂到 root 的节点，teardown 统一清（防污染后续测试）

func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root

func _ui():
	var root := _root()
	var ui = root.get_node_or_null("UI")
	if ui == null:
		ui = UILayersScript.new()
		ui.name = "UI"
		root.add_child(ui)
	return ui

func _track(n: Node) -> Node:
	_made.append(n)
	return n

func teardown() -> void:
	var ui = _root().get_node_or_null("UI")
	if ui != null:
		for c in ui._modal_layer.get_children():
			c.free()
		for c in ui._toast_layer.get_children():
			c.free()
	for n in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()

func test_layer_stack_order() -> void:
	var ui = _ui()
	assert_true(ui._modal_layer is CanvasLayer, "modal 层是 CanvasLayer")
	assert_true(ui._toast_layer is CanvasLayer, "toast 层是 CanvasLayer")
	assert_eq(ui._modal_layer.layer, 50, "modal 层值 = 50")
	assert_eq(ui._toast_layer.layer, 90, "toast 层值 = 90")

func test_modal_push_open_close() -> void:
	var ui = _ui()
	assert_false(ui.modal_open(), "初始无弹窗")
	var m = ModalScript.new()
	ui.modal(m)
	assert_true(ui.modal_open(), "推入后 modal_open=true")
	assert_eq(m.get_parent(), ui._modal_layer, "弹窗挂在 modal 层")
	var got := []
	m.closed.connect(func() -> void: got.append(1))
	m.close()
	assert_eq(got.size(), 1, "close() 发 closed 信号")
	assert_true(m.is_queued_for_deletion(), "close() 后进入待删")
	assert_false(ui.modal_open(), "待删弹窗不再算开启")

func test_modal_dim_assembly() -> void:
	var ui = _ui()
	var m = ModalScript.new()   # 默认 dim_alpha=0.72
	ui.modal(m)
	assert_eq(m.mouse_filter, Control.MOUSE_FILTER_STOP, "根 STOP 兜底拦截")
	assert_true(m.get_child_count() > 0 and m.get_child(0) is ColorRect, "默认装暗幕 ColorRect 且垫底")
	var m2 = ModalScript.new()
	m2.dim_alpha = 0.0          # 结算层形态：演出黑幕由场景 _draw 渐入，本层无暗幕
	ui.modal(m2)
	var has_dim := false
	for c in m2.get_children():
		if c is ColorRect:
			has_dim = true
	assert_false(has_dim, "dim_alpha=0 不装暗幕")

func test_modal_isolation_structure() -> void:
	# KAN-98 结构级验证：输入隔离由「弹窗在更高 CanvasLayer + 根 full-rect STOP」两个事实保证
	# （Godot 对 GUI 输入按 CanvasLayer 从高到低分发是引擎行为）。真实点击分发需要激活树+渲染，
	# --script 离线树测不了——行为级验证走真人验收 F 组（net_battle 结算演出期点卡牌区无反应）。
	var ui = _ui()
	var m = ModalScript.new()
	m.dim_alpha = 0.0   # 最严苛形态（=结算层配置：无暗幕，纯靠层级+根 STOP）
	ui.modal(m)
	assert_eq((m.get_parent() as CanvasLayer).layer, 50, "弹窗宿主层=50，恒高于场景层 0（与创建顺序无关）")
	assert_eq(m.mouse_filter, Control.MOUSE_FILTER_STOP, "根 STOP：层内兜底拦截")
	assert_almost_eq(m.anchor_left, 0.0, 0.001, "全屏锚 左")
	assert_almost_eq(m.anchor_top, 0.0, 0.001, "全屏锚 上")
	assert_almost_eq(m.anchor_right, 1.0, 0.001, "全屏锚 右")
	assert_almost_eq(m.anchor_bottom, 1.0, 0.001, "全屏锚 下")

func test_dragscroll_yields_to_modal() -> void:
	# 双保险①：DragScroll 是 Node._input 前置拦截，CanvasLayer 挡不住它，必须自觉对 modal 让路。
	var root := _root()
	var ui = _ui()
	var sc := ScrollContainer.new()
	sc.position = Vector2(0, 0)
	sc.size = Vector2(720, 600)
	_track(sc)
	root.add_child(sc)
	var ds = DragScrollScript.attach(sc)
	assert_false(ds._covered(), "无弹窗（headless 无 hover）：正常可代管")
	var m = ModalScript.new()
	ui.modal(m)
	assert_true(ds._covered(), "modal 开着：DragScroll 让路不代管")

func test_toast_layer() -> void:
	var ui = _ui()
	var before: int = ui._toast_layer.get_child_count()
	ui.toast("测试提示")
	assert_eq(ui._toast_layer.get_child_count(), before + 1, "toast 落在 toast 层")
	var l = ui._toast_layer.get_child(before)
	assert_true(l is Label, "toast 是 Label")
	assert_eq(l.mouse_filter, Control.MOUSE_FILTER_IGNORE, "toast 不挡手")
