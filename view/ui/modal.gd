# Modal —— 弹窗基类（PLAN_V5_UIFRAME F1，KAN-97）。
#
# 用法：子类 extends 本类，覆写 _build() 搭内容（**勿覆写 _ready**，装配在基类）；
# 调用方 `UI.modal(实例)` 推入弹窗层（CanvasLayer 50，高于场景层——输入隔离由层级保证，
# 本层根的 STOP 只是兜底）。关闭走 close()：发 closed 信号 + queue_free。
# 点击空白处（未被内容按钮吃掉）回调 _on_bg_click()——默认按 close_on_bg_click 决定是否关闭；
# 子类可覆写做「跳过动画到末态」等语义（reward_chest 式，F2 迁移用）。
extends Control

signal closed

var dim_alpha := 0.72            # 暗幕不透明度；0 = 无暗幕（如结算层：演出黑幕由场景 _draw 渐入）
var close_on_bg_click := false   # 点空白即关闭（确认框类弹窗置 true）
var bg_click_cb: Callable = Callable()   # 点空白自定义回调（免建子类的轻量覆写；优先于 close_on_bg_click）
var _assembled := false

func _ready() -> void:
	_assemble()

# 幂等装配（_ready 与 UI.modal 双入口：headless 单测的离线树不触发 _ready，由 UI.modal 显式调）。
func _assemble() -> void:
	if _assembled:
		return
	_assembled = true
	# ⚠️ 必须用带 offsets 版：set_anchors_preset 只改锚点并保留当前矩形（新建节点=0×0 → 永远 0×0，
	# 根本拦不到输入）——2026-07-06 P0 实锤（教程弹层点不到、手牌照常可拖），勿回退。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if dim_alpha > 0.0:
		var d := ColorRect.new()
		d.color = Color(0.04, 0.03, 0.07, dim_alpha)   # 夜色石板调，对齐 PixelUI 暗幕语言
		d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 输入由本层根统一拦
		add_child(d)
		move_child(d, 0)
	_build()

func _build() -> void:
	pass   # 子类在此搭内容（标题/按钮/…），add_child 到 self

func close() -> void:
	closed.emit()
	queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Log.d("[UI] modal 收到点击 → _on_bg_click（%s）" % name)
		_on_bg_click()

func _on_bg_click() -> void:
	if bg_click_cb.is_valid():
		bg_click_cb.call()
	elif close_on_bg_click:
		close()
