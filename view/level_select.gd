# LevelSelect —— 选关界面（V2-7b）。每个关卡 = 独立遭遇战，自带 AI 难度。
#
# 选一关 → 写入 GameState.level_id 进对局；BACK 回主菜单。取代旧的难度选择界面
# （难度内嵌进每关，决策 34）。关卡列表从 ConfigLoader 动态读取——加关卡只改
# config/levels.json，本界面自动出现。
# 全英文 UI（延续零 CJK 字体决定）：不显示中文 name，用难度档英文标题 + 难度徽章 +
# 数值行（圣水节奏/时长/塔血）。与逻辑零关联，关卡仅经 GameState.level_id 传递。
extends Control

const GameStateScript = preload("res://view/game_state.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const DECK_BUILDER_SCENE := "res://view/deck_builder.tscn"
const MENU_SCENE := "res://view/main_menu.tscn"

# 难度 → 排序权重 / 配色 / 一句说明（与旧难度界面一致）。
const DIFF_RANK := {"easy": 0, "normal": 1, "hard": 2}
const DIFF_BG := {
	"easy": Color(0.20, 0.45, 0.28), "normal": Color(0.22, 0.34, 0.55), "hard": Color(0.52, 0.24, 0.26),
}
const DIFF_BORDER := {
	"easy": Color(0.45, 0.85, 0.55), "normal": Color(0.50, 0.66, 1.0), "hard": Color(1.0, 0.50, 0.50),
}
const DIFF_DESC := {
	"easy": "slow - no defense", "normal": "defends - hits weak tower", "hard": "fast - relentless",
}

func _ready() -> void:
	_build()

func _build() -> void:
	_rect(Color(0.09, 0.12, 0.10, 1.0), Vector2(0, 0), Vector2(720, 1280))
	for lx in [160.0, 360.0, 560.0]:                       # 三 lane 暗条背景（呼应玩法）
		_rect(Color(0.16, 0.20, 0.16, 1.0), Vector2(lx - 70.0, 120), Vector2(140, 1040))
	_center_label("SELECT STAGE", 150, 54, Color(1.0, 0.92, 0.5))

	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var y := 270.0
	for level_id in _sorted_level_ids(loader):
		_level_button(loader.get_level(level_id), level_id, y)
		y += 200.0
	_back_button(y + 4.0)

# 关卡按难度档由易到难排，同档按 id 升序——读成「难度阶梯」。
func _sorted_level_ids(loader) -> Array:
	var ids: Array = loader.levels.keys()
	ids.sort_custom(func(a, b):
		var ra: int = DIFF_RANK.get(String(loader.get_level(a).get("ai_difficulty", "normal")), 1)
		var rb: int = DIFF_RANK.get(String(loader.get_level(b).get("ai_difficulty", "normal")), 1)
		if ra != rb:
			return ra < rb
		return String(a) < String(b))
	return ids

# 英文标题（无 CJK 字体）：按难度档命名；hard 再按圣水节奏分 BLITZ(快) / CHAMPION。
func _level_title(level: Dictionary) -> String:
	var diff := String(level.get("ai_difficulty", "normal"))
	var fast: bool = float(level.get("elixir_regen_rate", 1.0)) >= 1.5
	match diff:
		"easy": return "TRAINING"
		"normal": return "ARENA"
		"hard": return "BLITZ" if fast else "CHAMPION"
	return "STAGE"

func _choose(level_id: String) -> void:
	GameStateScript.level_id = level_id
	get_tree().change_scene_to_file(DECK_BUILDER_SCENE)   # 选关后先组卡，再进对局

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# ---------- 关卡卡片 ----------
func _level_button(level: Dictionary, level_id: String, y: float) -> void:
	var diff := String(level.get("ai_difficulty", "normal"))
	var bg: Color = DIFF_BG.get(diff, DIFF_BG["normal"])
	var border: Color = DIFF_BORDER.get(diff, DIFF_BORDER["normal"])
	var bw := 480.0
	var bh := 160.0
	var x := (720.0 - bw) / 2.0
	# 整块彩色圆角按钮 = 点击区
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(bw, bh)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _sbflat(bg, 12, 3, border))
	btn.add_theme_stylebox_override("hover", _sbflat(bg.lightened(0.15), 12, 3, border))
	btn.add_theme_stylebox_override("pressed", _sbflat(bg.darkened(0.12), 12, 3, border))
	btn.pressed.connect(_choose.bind(level_id))
	add_child(btn)
	# 标题
	_pin_label(_level_title(level), Vector2(x + 26, y + 20), Vector2(bw - 200, 50), 40, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_LEFT)
	# 难度徽章（右上）
	var badge := Panel.new()
	badge.position = Vector2(x + bw - 168, y + 24)
	badge.size = Vector2(140, 40)
	badge.add_theme_stylebox_override("panel", _sbflat(border, 10, 0, border))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	_pin_label(diff.to_upper(), badge.position, badge.size, 22, Color(0.06, 0.08, 0.07), HORIZONTAL_ALIGNMENT_CENTER)
	# 数值行：圣水节奏 / 时长 / 王塔血
	var regen: float = float(level.get("elixir_regen_rate", 1.0))
	var dur: int = int(level.get("match_duration", 180))
	var king: int = int((level.get("tower_hp", {}) as Dictionary).get("king", 0))
	_pin_label("ELIXIR x%.1f    %ds    TOWER %d" % [regen, dur, king],
		Vector2(x + 26, y + 86), Vector2(bw - 52, 28), 22, Color(0.86, 0.90, 0.92), HORIZONTAL_ALIGNMENT_LEFT)
	# 说明行
	_pin_label(String(DIFF_DESC.get(diff, "")),
		Vector2(x + 26, y + 120), Vector2(bw - 52, 26), 18, Color(0.70, 0.78, 0.72), HORIZONTAL_ALIGNMENT_LEFT)

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

# 固定位置标签（子节点不挡按钮点击）。
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

func _sbflat(bg: Color, radius: float, border_w: float, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.set_border_width_all(int(border_w))
	sb.border_color = border_col
	return sb
