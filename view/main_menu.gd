# MainMenu —— 主菜单（V3 像素设计系统；V5-S9 重构）。
#
# 进来先登录（持久会话）→ 路由：未创号→创号页 / 未完成新手引导→强制引导战 / 否则建菜单。
# 菜单（决策48 在线主轴）：天梯征途(PVP·选卡组→匹配) / 闯关(PVE 基地) / 养成 / 卡组 / 探险 / 设置。
# 顶部玩家名片（昵称+怪物头像+杯数）。去掉「退出」「新手战役」入口（引导改创号后自动一次）。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")
const GameStateScript := preload("res://view/game_state.gd")
const CampaignStateScript := preload("res://logic/campaign_state.gd")

var _status: Label
var _retry_btn: Button

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	AudioManager.stop_ambience()
	_build_bg()
	_status = _center_label("登录中…", 620, 26, PixelUI.COL_MUTED)
	_bootstrap()

func _build_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_title("CLASH\nPUSHER", 96, 72)
	_center_label(tr("app_subtitle"), 312, 26, PixelUI.COL_MUTED)

# —— 登录 + 路由（V5-S9；KAN-109 起先过登录页门）——
func _bootstrap() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var session = GameStateScript.session()
	# KAN-109：本地无记住的 username → 登录页（服务器查库判新老，本地数据不作数）
	if session.needs_login():
		Log.i("[V5][menu] 无登录凭据 → login")
		http.queue_free()
		Router.goto("login")
		return
	var ok: bool = await session.ensure(http)
	if not ok:
		if session.needs_login():   # ensure 期间被登出/凭据失效
			http.queue_free()
			Router.goto("login")
			return
		Log.w("[V5][menu] 在线启动失败，停留重试门")
		if _status != null:
			_status.text = "未连接服务器，在线功能暂不可用"
		_show_retry()
		http.queue_free()
		return
	_clear_retry()
	# 未创号（服务器 avatar_card_id 为空）→ 创号页。
	if session.needs_account_setup():
		Log.i("[V5][menu] 新账号未创号 → account_create")
		http.queue_free()
		Router.goto("account_create")
		return
	# 未完成新手引导 → 强制引导战（打完一局回菜单）。
	if not session.tutorial_done():
		Log.i("[V5][menu] 新手引导未完成 → 强制引导战")
		http.queue_free()
		_start_tutorial()
		return
	http.queue_free()
	_build_menu()

func _start_tutorial() -> void:
	var config = GameStateScript.config()
	var levels: Array = config.get_campaign("default").get("levels", [])
	GameStateScript.run = null
	GameStateScript.campaign = CampaignStateScript.new([levels[0]] if not levels.is_empty() else [])
	GameStateScript.campaign_last_result = 0
	GameStateScript.tutorial = true
	GameStateScript.stage_id = ""
	Router.goto("battle")

# —— 菜单（路由放行后才建）——
func _build_menu() -> void:
	if _status != null:
		_status.queue_free()
		_status = null
	var session = GameStateScript.session()
	var np := HudWidgets.nameplate(session.nickname(), session.avatar_card_id(), GameStateScript.config(), session.trophies(), true)
	np.position = Vector2(40, 36)
	add_child(np)
	_menu_button("天梯征途", 440, _on_ladder, "gold", 40)
	_menu_button("闯关", 556, _on_stage, "stone", 34)
	_menu_button("养成", 664, _on_progression, "stone", 34)
	_menu_button("卡组", 772, _on_deck, "stone", 34)
	var run_btn := _menu_button("探险（离线原型·未开放）", 880, _on_run, "stone", 24)
	run_btn.disabled = true   # E1：本地存档原型不得作为 Prod 在线进度入口
	_menu_button(tr("btn_settings"), 988, _on_settings, "stone", 34)
	_center_label(tr("app_footer"), 1208, 22, PixelUI.COL_HINT)


func _show_retry() -> void:
	if _retry_btn != null:
		_retry_btn.disabled = false
		return
	_retry_btn = _menu_button("重试连接", 720, _on_retry, "gold", 30)


func _clear_retry() -> void:
	if _retry_btn != null:
		_retry_btn.queue_free()
		_retry_btn = null


func _on_retry() -> void:
	if _retry_btn != null:
		_retry_btn.disabled = true
	if _status != null:
		_status.text = "重新连接中…"
	_bootstrap()

# ---------- handlers ----------
func _on_ladder() -> void:
	# V5-S9 改动5：天梯先选卡组（存槽1）再进匹配。
	GameStateScript.deck_mode = "ladder"
	GameStateScript.stage_id = ""
	Router.goto("deck_builder")

func _on_stage() -> void:
	Router.goto("base_camp")

func _on_progression() -> void:
	Router.goto("card_collection")

func _on_deck() -> void:
	GameStateScript.deck_mode = "edit"
	GameStateScript.stage_id = ""
	Router.goto("deck_builder")

func _on_run() -> void:
	Router.goto("run")

func _on_settings() -> void:
	Router.goto("settings")

# ---------- ui builders ----------
func _title(text: String, y: float, font_size: int) -> void:
	for off in [Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		_mk_label(text, y, font_size, PixelUI.COL_OUTLINE).position += off
	_mk_label(text, y, font_size, PixelUI.COL_GOLD)

func _mk_label(text: String, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(720, float(font_size) * 2.6 + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

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

func _menu_button(text: String, y: float, cb: Callable, kind: String = "stone", font_size: int = 34) -> Button:
	var bw := 384.0
	var bh: float = 112.0 if kind == "gold" else 92.0
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, bh)
	btn.pivot_offset = Vector2(bw / 2.0, bh / 2.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, kind, font_size)
	btn.pressed.connect(_on_menu_button_pressed.bind(cb))
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	return btn

func _scale_to(btn: Button, s: float) -> void:
	create_tween().tween_property(btn, "scale", Vector2(s, s), 0.07)

func _on_menu_button_pressed(cb: Callable) -> void:
	AudioManager.play_sfx("ui_button_press")
	cb.call()
