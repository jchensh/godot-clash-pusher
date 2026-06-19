# MainMenu —— 主菜单场景（显示层 / 场景层）。V2-5a 场景闭环骨架。
#
# START → 选关→对局；ROGUELITE → run 中枢；SETTINGS → 设置（语言）；QUIT → 退出。
# 文本走 i18n（② 多语言，tr(key)）；中文字体由 project.godot 默认主题字体提供。
extends Control

const LEVEL_SELECT_SCENE := "res://view/level_select.tscn"
const RUN_SCENE := "res://view/run_scene.tscn"
const SETTINGS_SCENE := "res://view/settings.tscn"

func _ready() -> void:
	_build()

func _build() -> void:
	# 背景：与对局同色系深草绿
	_rect(Color(0.09, 0.12, 0.10, 1.0), Vector2(0, 0), Vector2(720, 1280))
	# 装饰：暗条
	for lx in [160.0, 360.0, 560.0]:
		_rect(Color(0.16, 0.20, 0.16, 1.0), Vector2(lx - 70.0, 120), Vector2(140, 1040))
	# 标题区上下色带
	_rect(Color(0.16, 0.42, 0.62, 0.85), Vector2(0, 296), Vector2(720, 6))
	_rect(Color(0.16, 0.42, 0.62, 0.85), Vector2(0, 560), Vector2(720, 6))
	# 标题 / 副标题
	_center_label(tr("app_title"), 336, 84, Color(1.0, 0.92, 0.5))
	_center_label(tr("app_subtitle"), 460, 30, Color(0.8, 0.85, 0.85))
	# 主按钮
	_menu_button(tr("menu_start"), 632, _on_start_pressed, true)
	_menu_button(tr("menu_roguelite"), 752, _on_run_pressed)
	_menu_button(tr("btn_settings"), 864, _on_settings_pressed)
	_menu_button(tr("menu_quit"), 976, _on_quit_pressed)
	# 脚注
	_center_label(tr("app_footer"), 1186, 20, Color(0.55, 0.6, 0.55))

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_run_pressed() -> void:
	get_tree().change_scene_to_file(RUN_SCENE)

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()

# ---------- 小工具 ----------
func _rect(color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _center_label(text: String, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(720, float(font_size) + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _menu_button(text: String, y: float, cb: Callable, big: bool = false) -> Button:
	var bw := 300.0
	var bh: float = 96.0 if big else 80.0
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, bh)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 36)
	btn.pressed.connect(cb)
	add_child(btn)
	return btn
