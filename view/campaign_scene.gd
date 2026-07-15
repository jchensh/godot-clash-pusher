# CampaignScene —— 短战役中枢（V3-5a-view，V3 UI 像素设计系统）。
#
# 画教学关进度链 + 当前关，驱动「打当前关 → 回来推进(胜)/重打(败) → 下一关」，全通关弹结算。
# 战役流转走 CampaignState（可重试、无永久死亡）；与 battle_scene 经 GameState.campaign /
# campaign_last_result 握手。会话内进度（GameState.campaign static），落盘留后续。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const GameStateScript = preload("res://view/game_state.gd")
const CampaignStateScript = preload("res://logic/campaign_state.gd")

const C_DONE := Color(0.22, 0.40, 0.26)
const C_CURRENT := Color(0.50, 0.42, 0.16)
const C_FUTURE := Color(0.20, 0.20, 0.28)
const C_BOSS := Color(0.46, 0.18, 0.20)
const BORD_DONE := Color(0.45, 0.78, 0.52)
const BORD_CURRENT := Color(0.95, 0.78, 0.32)
const BORD_FUTURE := Color(0.40, 0.42, 0.52)
const BORD_BOSS := Color(1.0, 0.40, 0.38)

var _loader

func _ready() -> void:
	AudioManager.play_music("music_run_map")
	AudioManager.stop_ambience()
	_loader = GameStateScript.config()
	# campaign 为空或已通关 → 开新战役（清旧结果）；进行中 → 续。
	if GameStateScript.campaign == null or GameStateScript.campaign.is_over():
		GameStateScript.campaign = CampaignStateScript.new(_loader.get_campaign("default").get("levels", []))
		GameStateScript.campaign_last_result = 0
	_process_result()
	_build()

func _process_result() -> void:
	var res: int = GameStateScript.campaign_last_result
	if res == 0:
		return
	GameStateScript.campaign_last_result = 0
	GameStateScript.campaign.advance(res)

func _build() -> void:
	PixelUI.add_background(self)
	_title(tr("campaign_title"), 56, 50)
	var camp = GameStateScript.campaign
	var shown: int = mini(camp.cursor + 1, camp.size())
	_center_label(tr("campaign_progress") % [shown, camp.size()], 128, 22, PixelUI.COL_MUTED)

	# 教学关进度链
	var y := 186.0
	for i in camp.size():
		var node: Dictionary = camp.levels[i]
		var focus := str(node.get("focus", ""))
		var is_boss: bool = focus == "boss"
		var done: bool = i < camp.cursor
		var current: bool = i == camp.cursor and not camp.is_over()
		var bg: Color = C_DONE if done else (C_CURRENT if current else (C_BOSS if is_boss else C_FUTURE))
		var border: Color = BORD_DONE if done else (BORD_CURRENT if current else (BORD_BOSS if is_boss else BORD_FUTURE))
		var bw: int = 3 if (current or is_boss) else 2
		var panel := _panel(Vector2(80, y), Vector2(560, 76), bg, border, bw)
		var mark := "✓" if done else ("▶" if current else "·")
		_pin(panel, "%s  %s" % [mark, tr("campaign_node") % [i + 1, tr("focus_" + focus)]],
			Vector2(24, 0), Vector2(512, 76), 28, Color.WHITE if not done else Color(0.72, 0.86, 0.74), HORIZONTAL_ALIGNMENT_LEFT)
		y += 92.0

	if camp.is_over():
		_title(tr("campaign_cleared"), y + 30.0, 42)
		_button(tr("btn_back_menu"), Vector2((720.0 - 300.0) / 2.0, y + 120.0), Vector2(300, 80), "gold", _on_menu)
	else:
		_button(tr("btn_fight"), Vector2(110, 1110), Vector2(280, 92), "gold", _on_fight)
		_button(tr("btn_menu"), Vector2(420, 1110), Vector2(200, 92), "dark", _on_menu)

func _on_fight() -> void:
	AudioManager.play_sfx("run_node_select")
	Router.goto("battle")   # battle_scene 读 GameState.campaign 自行建场

func _on_menu() -> void:
	AudioManager.play_sfx("ui_button_back")
	Router.goto("main_menu")

# ---------- 小工具 ----------
func _panel(pos: Vector2, size: Vector2, bg: Color, border: Color, bw: int) -> Control:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", PixelUI.sbpixel(bg, bw, border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p

func _pin(parent: Control, text: String, pos: Vector2, size: Vector2, fs: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _center_label(text: String, y: float, fs: int, col: Color) -> Label:
	return _pin(self, text, Vector2(0, y), Vector2(720, float(fs) + 16.0), fs, col, HORIZONTAL_ALIGNMENT_CENTER)

func _title(text: String, y: float, fs: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		_pin(self, text, Vector2(off.x, y + off.y), Vector2(720, float(fs) + 16.0), fs, PixelUI.COL_OUTLINE, HORIZONTAL_ALIGNMENT_CENTER)
	_pin(self, text, Vector2(0, y), Vector2(720, float(fs) + 16.0), fs, PixelUI.COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _button(text: String, pos: Vector2, size: Vector2, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.pivot_offset = size * 0.5
	b.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(b, kind, 32)
	b.pressed.connect(cb)
	b.button_down.connect(_scale_to.bind(b, 0.96))
	b.button_up.connect(_scale_to.bind(b, 1.0))
	add_child(b)
	return b

func _scale_to(c: Control, s: float) -> void:
	create_tween().tween_property(c, "scale", Vector2(s, s), 0.07)
