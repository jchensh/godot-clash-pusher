# DragScroll —— 给 ScrollContainer 补「鼠标按住拖动」滚动（2026-07-04，组卡验收反馈）。
#
# 背景：ScrollContainer 原生只支持触摸拖动(InputEventScreenDrag)与滚轮；桌面鼠标按住拖动无效，
# 试过 emulate_touch_from_mouse 仍不可靠（按下被子按钮捕获，drag 到不了容器）→ 自写前置拦截层。
# 机制：挂为 ScrollContainer 子节点，Node._input 在 gui 之前收事件——
#   · 真实鼠标左键按在滚动区 → 本层代管：位移≤阈值松手=轻点 → 命中测试内容里的 BaseButton 派发 pressed；
#     超过阈值=拖动 → 直接改 scroll_vertical 并吞掉事件（按钮不误触、不残留按压态）。
#   · 触摸模拟出的鼠标事件(DEVICE_ID_EMULATION)跳过 → 真机交给引擎原生触摸拖动，防双重滚动。
#   · 滚轮/右键不拦截，行为不变。
# 用法：const DragScroll := preload(".../drag_scroll.gd")；建好 ScrollContainer 后 DragScroll.attach(sc)。
extends Node

const DRAG_THRESHOLD := 14.0   # px：位移阈值内=点击，超出=滚动（拇指微抖不误滚、轻拖不误点）

var _sc: ScrollContainer
var _pressing := false
var _moved := 0.0

static func attach(sc: ScrollContainer) -> Node:
	var n = new()
	n._sc = sc
	sc.add_child(n)
	return n

func _input(event: InputEvent) -> void:
	if _sc == null or not _sc.is_visible_in_tree():
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return   # 真机触摸→模拟鼠标：交给 ScrollContainer 原生触摸拖动
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _sc.get_global_rect().has_point(event.position):
				_pressing = true
				_moved = 0.0
				get_viewport().set_input_as_handled()   # press 由本层代管；tap 时再派发点击
		elif _pressing:
			_pressing = false
			get_viewport().set_input_as_handled()
			if _moved <= DRAG_THRESHOLD:
				_dispatch_tap(event.position)
	elif event is InputEventMouseMotion and _pressing:
		_moved += absf(event.relative.y) + absf(event.relative.x)
		if _moved > DRAG_THRESHOLD:
			_sc.scroll_vertical -= int(round(event.relative.y))
		get_viewport().set_input_as_handled()

# 轻点：命中滚动内容里最上层的可见可用 BaseButton，派发 pressed（语义等价点击）。
func _dispatch_tap(pos: Vector2) -> void:
	var hit := _hit_button(_sc, pos)
	if hit != null:
		hit.pressed.emit()

func _hit_button(node: Node, pos: Vector2) -> BaseButton:
	var found: BaseButton = null
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		var sub := _hit_button(child, pos)
		if sub != null:
			found = sub   # 树序靠后=绘制在上层，后命中者优先
		if child is BaseButton:
			var b := child as BaseButton
			if not b.disabled and b.get_global_rect().has_point(pos):
				found = b
	return found
