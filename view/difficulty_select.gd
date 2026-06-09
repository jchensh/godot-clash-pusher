# DifficultySelect —— 难度选择界面。选 EASY/NORMAL/HARD 写入 GameState 后进入对局；BACK 回主菜单。
# 全英文 UI、纯程序化、零外部素材；与逻辑层零关联（难度仅经 GameState 传给 AIController）。
extends Control

const GameStateScript = preload("res://view/game_state.gd")
const BATTLE_SCENE := "res://view/battle_scene.tscn"
const MENU_SCENE := "res://view/main_menu.tscn"

func _ready() -> void:
	_build()

func _build() -> void:
	_rect(Color(0.09, 0.12, 0.10, 1.0), Vector2(0, 0), Vector2(720, 1280))
	for lx in [160.0, 360.0, 560.0]:                       # 三 lane 暗条背景（呼应玩法）
		_rect(Color(0.16, 0.20, 0.16, 1.0), Vector2(lx - 70.0, 120), Vector2(140, 1040))
	_center_label("SELECT DIFFICULTY", 250, 54, Color(1.0, 0.92, 0.5))
	_diff_button("EASY", "slow - no defense", 420, Color(0.20, 0.45, 0.28), Color(0.45, 0.85, 0.55), "easy")
	_diff_button("NORMAL", "defends - hits weak tower", 590, Color(0.22, 0.34, 0.55), Color(0.50, 0.66, 1.0), "normal")
	_diff_button("HARD", "fast - relentless", 760, Color(0.52, 0.24, 0.26), Color(1.0, 0.50, 0.50), "hard")
	_back_button(960)

func _choose(diff: String) -> void:
	GameStateScript.ai_difficulty = diff
	get_tree().change_scene_to_file(BATTLE_SCENE)

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

func _sbflat(bg: Color, radius: float, border_w: float, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(int(border_w))
	sb.border_color = border_col
	return sb

# 一个难度按钮：彩色圆角块（点击区）+ 上方标题 + 下方说明（子 Label 不挡点击）。
func _diff_button(title: String, desc: String, y: float, bg: Color, border: Color, diff: String) -> void:
	var bw := 400.0
	var bh := 120.0
	var x := (720.0 - bw) / 2.0
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(bw, bh)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _sbflat(bg, 12, 3, border))
	btn.add_theme_stylebox_override("hover", _sbflat(bg.lightened(0.15), 12, 3, border))
	btn.add_theme_stylebox_override("pressed", _sbflat(bg.darkened(0.12), 12, 3, border))
	btn.pressed.connect(_choose.bind(diff))
	add_child(btn)
	var t := Label.new()
	t.position = Vector2(x, y + 24)
	t.size = Vector2(bw, 50)
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color(1, 1, 1))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	var d := Label.new()
	d.position = Vector2(x, y + 78)
	d.size = Vector2(bw, 30)
	d.text = desc
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 20)
	d.add_theme_color_override("font_color", Color(0.86, 0.90, 0.92))
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(d)

func _back_button(y: float) -> void:
	var bw := 220.0
	var bh := 70.0
	var btn := Button.new()
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, bh)
	btn.text = "BACK"
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_stylebox_override("normal", _sbflat(Color(0.20, 0.22, 0.26), 8, 2, Color(0.45, 0.50, 0.56)))
	btn.add_theme_stylebox_override("hover", _sbflat(Color(0.26, 0.28, 0.33), 8, 2, Color(0.45, 0.50, 0.56)))
	btn.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	btn.pressed.connect(_on_back)
	add_child(btn)
