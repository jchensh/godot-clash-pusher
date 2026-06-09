# MainMenu —— 主菜单场景（显示层 / 场景层）。V2-5a 场景闭环骨架。
#
# START → 进入对局（battle_scene）；QUIT → 退出。
# 全英文 UI（延续 7b 决定，零中文字体依赖）；纯程序化绘制、零外部素材；与逻辑层零关联。
extends Control

const DIFFICULTY_SCENE := "res://view/difficulty_select.tscn"

func _ready() -> void:
	_build()

func _build() -> void:
	# 背景：与对局同色系深草绿
	_rect(Color(0.09, 0.12, 0.10, 1.0), Vector2(0, 0), Vector2(720, 1280))
	# 装饰：三条 lane 暗条（呼应 3-lane 玩法）
	for lx in [160.0, 360.0, 560.0]:
		_rect(Color(0.16, 0.20, 0.16, 1.0), Vector2(lx - 70.0, 120), Vector2(140, 1040))
	# 标题区上下色带
	_rect(Color(0.16, 0.42, 0.62, 0.85), Vector2(0, 296), Vector2(720, 6))
	_rect(Color(0.16, 0.42, 0.62, 0.85), Vector2(0, 560), Vector2(720, 6))
	# 标题 / 副标题
	_center_label("CLASH PUSHER", 348, 84, Color(1.0, 0.92, 0.5))
	_center_label("3-LANE TOWER RUSH", 470, 30, Color(0.8, 0.85, 0.85))
	# 主按钮
	_menu_button("START", 720, _on_start_pressed)
	_menu_button("QUIT", 866, _on_quit_pressed)
	# 脚注
	_center_label("V2 prototype - white-box", 1186, 20, Color(0.55, 0.6, 0.55))

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(DIFFICULTY_SCENE)   # 先选难度，再进对局

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

func _menu_button(text: String, y: float, cb: Callable) -> Button:
	var bw := 300.0
	var bh: float = 96.0 if text == "START" else 80.0
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, bh)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 36)
	btn.pressed.connect(cb)
	add_child(btn)
	return btn
