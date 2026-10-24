# CampaignScene —— 短战役中枢（V3-5a-view，V3 UI 像素设计系统）。
#
# 画教学关进度链 + 当前关，驱动「打当前关 → 回来推进(胜)/重打(败) → 下一关」，全通关弹结算。
# 战役流转走 CampaignState（可重试、无永久死亡）；与 battle_scene 经 GameState.campaign /
# campaign_last_result 握手。会话内进度（GameState.campaign static），落盘留后续。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const GameStateScript = preload("res://view/game_state.gd")
const CampaignStateScript = preload("res://logic/campaign_state.gd")

# 路线节点四态 = PixelUI 色板令牌（UI 偏离修复④：夜色深底 → 天空牧场浅底，字统一主文字色）
const C_DONE := PixelUI.COL_NODE_DONE_BG
const C_CURRENT := PixelUI.COL_NODE_CURRENT_BG
const C_FUTURE := PixelUI.COL_NODE_FUTURE_BG
const C_BOSS := PixelUI.COL_NODE_BOSS_BG
const BORD_DONE := PixelUI.COL_NODE_DONE_BD
const BORD_CURRENT := PixelUI.COL_NODE_CURRENT_BD
const BORD_FUTURE := PixelUI.COL_NODE_FUTURE_BD
const BORD_BOSS := PixelUI.COL_NODE_BOSS_BD

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
			Vector2(24, 0), Vector2(512, 76), 28, PixelUI.COL_PARCHMENT, HORIZONTAL_ALIGNMENT_LEFT)
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
	# 决策 49 换肤：原生 outline 取代 4-label 偏移描边（圆体字下偏移法成重影；白边保对比）
	var l := _pin(self, text, Vector2(0, y), Vector2(720, float(fs) + 16.0), fs, PixelUI.COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10)

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
