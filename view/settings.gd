# Settings —— 设置场景（V3 UI 像素设计系统）。语言切换（中/英），未来放音量等。
#
# 切换语言 = I18n.set_language（即时 set_locale + 存 user://settings.cfg）→ 重载本页重建。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const MENU_SCENE := "res://view/main_menu.tscn"

func _ready() -> void:
	_build()

func _build() -> void:
	PixelUI.add_background(self)
	_title(tr("settings_title"), 150, 60)
	_center_label(tr("settings_language"), 420, 34, PixelUI.COL_MUTED)
	var cur := I18n.current_locale()
	_lang_button(tr("lang_zh"), "zh", 150, 500, cur.begins_with("zh"))
	_lang_button(tr("lang_en"), "en", 390, 500, cur.begins_with("en"))
	_back_button(1080)

func _lang_button(text: String, loc: String, x: float, y: float, active: bool) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(180, 104)
	btn.pivot_offset = Vector2(90, 52)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "gold" if active else "stone", 34)
	btn.pressed.connect(_set_lang.bind(loc))
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)

func _set_lang(loc: String) -> void:
	I18n.set_language(loc)
	get_tree().reload_current_scene()   # 以新语言重建本页（即时见效）

func _back_button(y: float) -> void:
	var bw := 240.0
	var btn := Button.new()
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, 80)
	btn.text = tr("btn_back")
	btn.pivot_offset = Vector2(bw / 2.0, 40.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "dark", 30)
	btn.pressed.connect(_on_back)
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _scale_to(c: Control, s: float) -> void:
	create_tween().tween_property(c, "scale", Vector2(s, s), 0.07)

func _title(text: String, y: float, fs: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		var s := _center_label(text, y, fs, PixelUI.COL_OUTLINE)
		s.position += off
	_center_label(text, y, fs, PixelUI.COL_GOLD)

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
