# LevelSelect —— 选关界面（V3 UI 像素设计系统：夜色背景 + 9-slice 难度卡片 + 金描边标题）。
#
# 选一关 → 写 GameState.level_id → 组卡；返回 → 主菜单。关卡列表从 ConfigLoader 动态读。
# 卡片 = 中性 card_tint 9-slice 按难度 modulate（5 档色）；徽章同法。文本走 i18n。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")
const GameStateScript = preload("res://view/game_state.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const DECK_BUILDER_SCENE := "res://view/deck_builder.tscn"
const MENU_SCENE := "res://view/main_menu.tscn"

# 5 档（V3-9）：rookie→extreme 由易到难；底色渐变 青绿→绿→蓝→琥珀→深红。
const DIFF_RANK := {"rookie": 0, "easy": 1, "normal": 2, "hard": 3, "extreme": 4}
const DIFF_BG := {
	"rookie": Color(0.18, 0.40, 0.38), "easy": Color(0.20, 0.45, 0.28), "normal": Color(0.22, 0.34, 0.55),
	"hard": Color(0.50, 0.34, 0.16), "extreme": Color(0.46, 0.16, 0.20),
}
const DIFF_BORDER := {
	"rookie": Color(0.48, 0.88, 0.80), "easy": Color(0.45, 0.85, 0.55), "normal": Color(0.50, 0.66, 1.0),
	"hard": Color(1.0, 0.68, 0.30), "extreme": Color(1.0, 0.34, 0.36),
}

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_title_text(tr("stage_select_title"), 80, 52)

	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var y := 206.0
	for level_id in _sorted_level_ids(loader):
		_level_button(loader.get_level(level_id), level_id, y)
		y += 182.0
	_back_button(y + 8.0)

# 关卡按难度档由易到难排，同档按 id 升序。
func _sorted_level_ids(loader) -> Array:
	var ids: Array = []
	for k in loader.levels.keys():
		if not String(k).begins_with("campaign_"):   # 战役教学关只走「新手战役」中枢，不进自由对战选关
			ids.append(k)
	ids.sort_custom(func(a, b):
		var ra: int = DIFF_RANK.get(String(loader.get_level(a).get("ai_difficulty", "normal")), 1)
		var rb: int = DIFF_RANK.get(String(loader.get_level(b).get("ai_difficulty", "normal")), 1)
		if ra != rb:
			return ra < rb
		return String(a) < String(b))
	return ids

func _level_title(level: Dictionary) -> String:
	match String(level.get("ai_difficulty", "normal")):
		"rookie": return tr("level_rookie")
		"easy": return tr("level_easy")
		"normal": return tr("level_normal")
		"hard": return tr("level_hard")
		"extreme": return tr("level_extreme")
	return tr("level_normal")

func _choose(level_id: String) -> void:
	GameStateScript.level_id = level_id
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# ---------- 关卡卡片 ----------
func _level_button(level: Dictionary, level_id: String, y: float) -> void:
	var diff := String(level.get("ai_difficulty", "normal"))
	var bg: Color = DIFF_BG.get(diff, DIFF_BG["normal"])
	var border: Color = DIFF_BORDER.get(diff, DIFF_BORDER["normal"])
	var bw := 528.0
	var bh := 160.0
	var x := (720.0 - bw) / 2.0
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(bw, bh)
	btn.pivot_offset = Vector2(bw / 2.0, bh / 2.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _sbpixel(bg, 3, border))
	btn.add_theme_stylebox_override("hover", _sbpixel(bg.lightened(0.14), 3, border.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", _sbpixel(bg.darkened(0.12), 3, border))
	btn.add_theme_stylebox_override("focus", _sbpixel(bg, 3, border))
	btn.pressed.connect(_choose.bind(level_id))
	btn.button_down.connect(_scale_to.bind(btn, 0.98))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	# 标题
	_pin_label(_level_title(level), Vector2(x + 30, y + 22), Vector2(bw - 210, 52), 42, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
	# 难度徽章（右上，亮难度色 9-slice）
	var badge := Panel.new()
	badge.position = Vector2(x + bw - 178, y + 26)
	badge.size = Vector2(148, 44)
	badge.add_theme_stylebox_override("panel", _sbpixel(border, 0, border))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	_pin_label(tr("diff_" + diff), badge.position, badge.size, 24, Color(0.06, 0.08, 0.07), HORIZONTAL_ALIGNMENT_CENTER)
	# 数值行：圣水节奏 / 时长 / 王塔血
	var regen: float = float(level.get("elixir_regen_rate", 1.0))
	var dur: int = int(level.get("match_duration", 180))
	var king: int = int((level.get("tower_hp", {}) as Dictionary).get("king", 0))
	_pin_label(tr("stage_stats") % [regen, dur, king],
		Vector2(x + 30, y + 90), Vector2(bw - 60, 28), 22, Color(0.90, 0.93, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	# 说明行
	_pin_label(tr("diff_desc_" + diff),
		Vector2(x + 30, y + 124), Vector2(bw - 60, 26), 18, Color(0.80, 0.86, 0.82), HORIZONTAL_ALIGNMENT_LEFT)

func _back_button(y: float) -> void:
	var bw := 240.0
	var btn := Button.new()
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, 76)
	btn.text = tr("btn_back")
	btn.pivot_offset = Vector2(bw / 2.0, 38.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, "dark", 30)
	btn.pressed.connect(_on_back)
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)

func _scale_to(c: Control, s: float) -> void:
	create_tween().tween_property(c, "scale", Vector2(s, s), 0.07)

# ---------- 小工具 ----------
func _title_text(text: String, y: float, fs: int) -> void:
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

func _sbpixel(bg: Color, border_w: int, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)   # 无圆角 = 像素方块
	sb.set_border_width_all(border_w)
	sb.border_color = border_col
	return sb

func _pin_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
