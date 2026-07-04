# UILayers（autoload `UI`）—— 客户端 UI 层级骨架（PLAN_V5_UIFRAME F1，KAN-97）。
#
# 全局 CanvasLayer 栈：场景自身在 layer 0，MODAL=50（弹窗/结算/覆盖层）< TOAST=90（提示，恒不挡手）。
# Godot 分发 GUI 输入按 CanvasLayer 从高到低：modal 开着时场景层**从机制上**收不到点击——
# 不再依赖各弹窗自觉 STOP / 兄弟树序压层（KAN-98 教训：Control 输入命中按树序，与 z_index 无关）。
# 入口：UI.modal(node) 推弹窗（配 view/ui/modal.gd 基类）；UI.toast(msg) 打提示。
# 规约（F3 固化）：覆盖类 UI 一律走 UI.modal，禁止手搓全屏 Control 靠树序当层级。
extends Node

const PixelUI := preload("res://view/ui/pixel_ui.gd")

const MODAL_LAYER := 50
const TOAST_LAYER := 90

var _modal_layer: CanvasLayer
var _toast_layer: CanvasLayer

func _init() -> void:
	# 用 _init 而非 _ready 装配：headless 单测手动实例化（autoload 在 --script 模式下晚于测试加载）同样可用。
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = MODAL_LAYER
	add_child(_modal_layer)
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = TOAST_LAYER
	add_child(_toast_layer)

# 推入弹窗层；绑定当前场景——场景切换（旧场景 free）时弹窗自动清，防跨场景残留。
func modal(m: Control) -> void:
	_modal_layer.add_child(m)
	if m.has_method("_assemble"):
		m._assemble()   # Modal 基类幂等装配兜底（离线树不触发 _ready 时仍完成装配）
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	if scene != null:
		scene.tree_exiting.connect(func() -> void:
			if is_instance_valid(m):
				m.queue_free()
		, CONNECT_ONE_SHOT)

func modal_open() -> bool:
	for c in _modal_layer.get_children():
		if not c.is_queued_for_deletion():
			return true
	return false

# 统一 toast：居中提示，1s 停留 + 0.5s 淡出（手感对齐既有各场景 _toast；F2 迁移替换 4 处复制粘贴）。
func toast(msg: String, col: Color = PixelUI.COL_GOLD, y: float = 1080.0) -> void:
	var l := Label.new()
	l.text = msg
	l.position = Vector2(0, y)
	l.size = Vector2(720, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
