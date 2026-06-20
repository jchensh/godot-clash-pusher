# Settings —— 设置场景（② 多语言）。当前含语言切换（中/英），未来放音量等。
#
# 切换语言 = I18n.set_language（即时 set_locale + 存 user://settings.cfg）→ 重载本页以新语言重建。
extends Control

const MENU_SCENE := "res://view/main_menu.tscn"
const GOLD := Color(1.0, 0.84, 0.36)

func _ready() -> void:
	_build()

func _build() -> void:
	_rect(Color(0.09, 0.12, 0.10, 1.0), Vector2(0, 0), Vector2(720, 1280))
	_center_label(tr("settings_title"), 130, 64, GOLD)
	_center_label(tr("settings_language"), 380, 36, Color(0.86, 0.90, 0.92))
	var cur := I18n.current_locale()
	_lang_button(tr("lang_zh"), "zh", 190, 460, cur.begins_with("zh"))
	_lang_button(tr("lang_en"), "en", 390, 460, cur.begins_with("en"))
	_back_button(tr("btn_back"), 1080)

func _lang_button(text: String, loc: String, x: float, y: float, active: bool) -> void:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(140, 96)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 30)
	var border: Color = GOLD if active else Color(0.40, 0.45, 0.50)
	var bg: Color = Color(0.20, 0.34, 0.22) if active else Color(0.16, 0.18, 0.21)
	btn.add_theme_stylebox_override("normal", _sbflat(bg, 10, 3 if active else 2, border))
	btn.add_theme_stylebox_override("hover", _sbflat(bg.lightened(0.12), 10, 3, GOLD))
	btn.add_theme_stylebox_override("pressed", _sbflat(bg.darkened(0.10), 10, 2, border))
	btn.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
	btn.pressed.connect(_set_lang.bind(loc))
	add_child(btn)

func _set_lang(loc: String) -> void:
	I18n.set_language(loc)
	get_tree().reload_current_scene()   # 以新语言重建本页（即时见效）

func _back_button(text: String, y: float) -> void:
	var bw := 240.0
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, 80)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_stylebox_override("normal", _sbflat(Color(0.20, 0.22, 0.26), 8, 2, Color(0.45, 0.50, 0.56)))
	btn.add_theme_stylebox_override("hover", _sbflat(Color(0.26, 0.28, 0.33), 8, 2, Color(0.45, 0.50, 0.56)))
	btn.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	btn.pressed.connect(_on_back)
	add_child(btn)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

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

func _sbflat(bg: Color, radius: int, border_w: int, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border_col
	return sb
