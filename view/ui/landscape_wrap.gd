# LandscapeWrap —— 全局横屏模式的页面适配壳（L2，2026-07-26）。
#
# 原理：页面装进 720×1280 的 SubViewport——页面代码完全零改动（get_viewport_rect、
# 绝对坐标、DragScroll 全部照旧，它以为自己还在竖屏）；壳负责在 1280×720 主视口里呈现：
# - mode="scroll"（菜单页）：居中 720 宽立柱 + 竖向裁剪窗，滚轮/两侧边距拖拽上下滚动，
#   右缘画滚动指示条；两侧留边 = 拇指操作区 + 夜色装饰。
# - mode="fit"（战斗类，L3 真横屏投影落地前的过渡）：整页等比缩放居中（405×720 pillarbox）。
# 输入：SubViewportContainer 自动转发鼠标/触摸（含缩放变换）；键盘在外层无焦点时手动
#   push_input 进子视口（登录页打字）。滚轮走前置 _input 拦截（页面区域也能滚）——
#   遵守 UI 铁律：前置拦截器必须查 UI.modal_open() 对弹窗让路。
extends Control

const CANVAS := Vector2(720.0, 1280.0)   # 竖版设计画布（全项目 UI 基准）

var _mode := "scroll"
var _scroll := 0.0
var _dragging := false
var _clip: Control
var _holder: SubViewportContainer
var _vp: SubViewport


static func wrap(page: Node, mode: String) -> Control:
	var w = load("res://view/ui/landscape_wrap.gd").new()
	w._mode = mode
	w._adopt(page)
	return w


func _adopt(page: Node) -> void:
	name = "LandscapeWrap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.size = Vector2i(CANVAS)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_holder = SubViewportContainer.new()
	_holder.stretch = true
	_holder.size = CANVAS
	_holder.add_child(_vp)
	_vp.add_child(page)
	if _mode == "scroll":
		_clip = Control.new()
		_clip.clip_contents = true
		_clip.mouse_filter = Control.MOUSE_FILTER_PASS   # 事件穿给 holder，自己不吃
		_clip.add_child(_holder)
		add_child(_clip)
	else:
		add_child(_holder)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _layout() -> void:
	var vs := size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	if _mode == "fit":
		var s: float = minf(vs.x / CANVAS.x, vs.y / CANVAS.y)
		_holder.scale = Vector2(s, s)
		_holder.position = (vs - CANVAS * s) * 0.5
	else:
		_clip.position = Vector2((vs.x - CANVAS.x) * 0.5, 0.0)
		_clip.size = Vector2(CANVAS.x, vs.y)
		_scroll = clampf(_scroll, 0.0, _max_scroll())
		_holder.position = Vector2(0.0, -_scroll)
	queue_redraw()


func _max_scroll() -> float:
	return maxf(0.0, CANVAS.y - size.y)


func _set_scroll(v: float) -> void:
	_scroll = clampf(v, 0.0, _max_scroll())
	_holder.position.y = -_scroll
	queue_redraw()


# 前置滚轮拦截：让「鼠标悬在页面内容上滚轮」也能滚立柱（SubViewportContainer 会吞掉
# 转发进子视口的事件，靠 _gui_input 收不到）。弹窗开着时让路（UI 铁律）。
func _input(event: InputEvent) -> void:
	if _mode != "scroll" or _max_scroll() <= 0.0 or UI.modal_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_scroll(_scroll + 90.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_scroll(_scroll - 90.0)
			get_viewport().set_input_as_handled()


# 两侧边距 = 壳自己的 GUI 命中区（中间被 clip/holder 盖住）：按住上下拖 = 滚动。
func _gui_input(event: InputEvent) -> void:
	if _mode != "scroll":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_set_scroll(_scroll - event.relative.y)


# 键盘转发：外层视口没有焦点控件时，把按键送进子视口（登录/创号页打字）。
# 外层有焦点（理论上只有壳系控件）则由引擎正常分发，避免双投。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and get_viewport().gui_get_focus_owner() == null:
		_vp.push_input(event)


func _draw() -> void:
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), Color("d8ecfa"))   # 夜色底（两侧边距/缩放留边）
	if _mode != "scroll":
		return
	var x0: float = (vs.x - CANVAS.x) * 0.5
	# 立柱两缘细描边（分隔装饰边与页面）
	draw_rect(Rect2(x0 - 3.0, 0.0, 3.0, vs.y), Color("dceefc"))
	draw_rect(Rect2(x0 + CANVAS.x, 0.0, 3.0, vs.y), Color("dceefc"))
	if _max_scroll() > 0.0:   # 右缘滚动指示条
		var track_h: float = vs.y - 16.0
		var bar_h: float = maxf(40.0, track_h * vs.y / CANVAS.y)
		var bar_y: float = 8.0 + (track_h - bar_h) * (_scroll / _max_scroll())
		draw_rect(Rect2(x0 + CANVAS.x + 6.0, bar_y, 6.0, bar_h), Color(0.65, 0.62, 0.78, 0.55))
