# MainMenu —— 主菜单（0718 CR 式改版；布局按 docs/design/ui_mockups/main_menu_cr_style.html）。
#
# 进来先登录（持久会话）→ 路由：未创号→创号页 / 未完成新手引导→强制引导战 / 否则建菜单。
# 新版结构（用户已评审的示意图，正式美术后补、当前全占位）：
#   1 顶部：名片横幅(左) + 货币行(右) + 公告(灰)/设置小钮
#   2 左右活动轨：左=挂机金库(点击领取) / 右=探险占位(灰)
#   3 中央：章节主视觉(占位) + 闯关总进度条（点击进闯关地图）
#   4 底部操作大簇：卡组 | 对战(主 CTA·天梯) | 闯关
#   5 底部五页签：商店(灰) 卡牌 对战(当前页高亮) 闯关 探险(灰)
# 旧「六按钮列表」废弃；基地页(base_camp)不再从主菜单进（挂机并入活动轨、进度并入主视觉）。
# 数据：钱包/挂机/闯关进度 = EconomyStateCache 服务器快照（economy_changed 订阅刷新，决策48）。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")
const GameStateScript := preload("res://view/game_state.gd")
const CampaignStateScript := preload("res://logic/campaign_state.gd")
const StageProgressScript := preload("res://logic/stage_progress.gd")

const COL_BADGE := Color("e5453a")

var _status: Label
var _retry_btn: Button
var _boot_ui: Control          # 登录期标题+状态（菜单建成后整体移除）
var _http: HTTPRequest
# —— 菜单动态件（economy_changed 刷新）——
var _wallet_holder: Control
var _idle_lbl: Label
var _idle_btn: Button
var _chapter_lbl: Label
var _prog_fill: ColorRect
var _prog_txt: Label
var _deck_badge: Label
var _stage_badge: Label
var _battle_sub: Label

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	AudioManager.stop_ambience()
	_build_bg()
	_build_boot_ui()
	_http = HTTPRequest.new()
	add_child(_http)
	_bootstrap()

func _build_bg() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _build_boot_ui() -> void:
	_boot_ui = Control.new()
	_boot_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boot_ui)
	_title("CLASH\nPUSHER", 96, 72)
	_center_label(tr("app_subtitle"), 312, 26, PixelUI.COL_MUTED)
	_status = _center_label("登录中…", 620, 26, PixelUI.COL_MUTED)

# —— 登录 + 路由（V5-S9；KAN-109 起先过登录页门）——
func _bootstrap() -> void:
	var session = GameStateScript.session()
	# KAN-109：本地无记住的 username → 登录页（服务器查库判新老，本地数据不作数）
	if session.needs_login():
		Log.i("[V5][menu] 无登录凭据 → login")
		Router.goto("login")
		return
	var ok: bool = await session.ensure(_http)
	if not ok:
		if session.needs_login():   # ensure 期间被登出/凭据失效
			Router.goto("login")
			return
		Log.w("[V5][menu] 在线启动失败，停留重试门")
		if _status != null:
			_status.text = "未连接服务器，在线功能暂不可用"
		_show_retry()
		return
	_clear_retry()
	# 未创号（服务器 avatar_card_id 为空）→ 创号页。
	if session.needs_account_setup():
		Log.i("[V5][menu] 新账号未创号 → account_create")
		Router.goto("account_create")
		return
	# 未完成新手引导 → 强制引导战（打完一局回菜单）。
	if not session.tutorial_done():
		Log.i("[V5][menu] 新手引导未完成 → 强制引导战")
		_start_tutorial()
		return
	_build_menu()
	await _refresh_economy()

func _start_tutorial() -> void:
	var config = GameStateScript.config()
	var levels: Array = config.get_campaign("default").get("levels", [])
	GameStateScript.run = null
	GameStateScript.campaign = CampaignStateScript.new([levels[0]] if not levels.is_empty() else [])
	GameStateScript.campaign_last_result = 0
	GameStateScript.tutorial = true
	GameStateScript.stage_id = ""
	Router.goto("battle")

# —— 菜单骨架（路由放行后才建；数据由 economy_changed 订阅回填）——
func _build_menu() -> void:
	if _boot_ui != null:
		_boot_ui.queue_free()
		_boot_ui = null
		_status = null
	Events.economy_changed.connect(_on_economy_changed)
	_build_top_row()
	_build_rails()
	_build_showpiece()
	_build_cluster()
	_build_tabbar()

func _refresh_economy() -> void:
	var session = GameStateScript.session()
	var config = GameStateScript.config()
	var res: Dictionary = await GameStateScript.economy().refresh(
			_http, session.token(), config.cards.keys())
	if not bool(res.get("ok", false)):
		Log.w("[V5][menu] 经济状态拉取失败 → 离线降级展示")
		_set_offline()

# ---------- 1 顶部：名片 + 货币 + 小钮 ----------
func _build_top_row() -> void:
	var session = GameStateScript.session()
	var np := HudWidgets.nameplate(session.nickname(), session.avatar_card_id(),
			GameStateScript.config(), session.trophies(), true)
	np.position = Vector2(20, 20)
	add_child(np)
	_wallet_holder = Control.new()
	_wallet_holder.position = Vector2(388, 24)
	_wallet_holder.size = Vector2(312, 44)
	_wallet_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet_holder)
	_set_wallet(0, 0)
	var notice := _pin_button("公告", Vector2(556, 84), Vector2(66, 60), _noop, "dark", 20)
	notice.disabled = true   # 未开放，按示意图灰态占位
	_pin_button("设置", Vector2(634, 84), Vector2(66, 60), _on_settings, "dark", 20)

# ---------- 2 左右活动轨 ----------
func _build_rails() -> void:
	_idle_btn = _pin_button("挂机\n金库", Vector2(24, 230), Vector2(96, 96), _on_collect_idle, "gold", 22)
	_idle_lbl = _rail_label("产出中…", Vector2(4, 332), 136)
	var explore := _pin_button("探险", Vector2(600, 230), Vector2(96, 96), _noop, "stone", 22)
	explore.disabled = true
	_rail_label("敬请期待", Vector2(580, 332), 136)

func _rail_label(text: String, pos: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", PixelUI.COL_PARCHMENT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

# ---------- 3 中央章节主视觉 + 闯关进度 ----------
func _build_showpiece() -> void:
	var art := Button.new()   # 主视觉整块可点 → 闯关地图（美术位后补正式图）
	art.position = Vector2(120, 340)
	art.size = Vector2(480, 300)
	art.focus_mode = Control.FOCUS_NONE
	art.add_theme_stylebox_override("normal",
			PixelUI.sbpixel(Color(0.16, 0.12, 0.20, 0.72), 3, Color("4a3a14")))
	art.add_theme_stylebox_override("hover",
			PixelUI.sbpixel(Color(0.20, 0.15, 0.24, 0.78), 3, Color("6a5424")))
	art.add_theme_stylebox_override("pressed",
			PixelUI.sbpixel(Color(0.12, 0.09, 0.16, 0.78), 3, Color("4a3a14")))
	art.pressed.connect(_on_pressed.bind(_on_stage))
	add_child(art)
	_chapter_lbl = _child_label(art, "第 — 章", 96, 44, PixelUI.COL_GOLD)
	_child_label(art, "章节主视觉 · 美术位占位（点击进闯关）", 168, 18, PixelUI.COL_HINT)
	var bar := Panel.new()
	bar.position = Vector2(160, 660)
	bar.size = Vector2(400, 26)
	bar.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color("241c14"), 3, Color("2b1e12")))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_prog_fill = ColorRect.new()
	_prog_fill.position = Vector2(3, 3)
	_prog_fill.size = Vector2(0, 20)
	_prog_fill.color = Color("3f8ede")
	_prog_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_prog_fill)
	_prog_txt = _center_label("闯关进度 — / —", 692, 20, PixelUI.COL_PARCHMENT)

# ---------- 4 底部操作大簇 ----------
func _build_cluster() -> void:
	var panel := Panel.new()
	panel.position = Vector2(26, 900)
	panel.size = Vector2(668, 210)
	panel.add_theme_stylebox_override("panel",
			PixelUI.sbpixel(Color(0.09, 0.08, 0.06, 0.66), 3, Color("2b1e12")))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var deck := _pin_button("卡组", Vector2(58, 922), Vector2(150, 166), _on_deck, "stone", 30)
	_deck_badge = _badge(deck, "8")
	var battle := _pin_button("对战", Vector2(226, 912), Vector2(268, 186), _on_ladder, "gold", 52)
	_battle_sub = _child_label(battle, "天梯匹配", 132, 20, PixelUI.COL_GOLD_INK)
	var stage := _pin_button("闯关", Vector2(512, 922), Vector2(150, 166), _on_stage, "stone", 30)
	_stage_badge = _badge(stage, "—")

# ---------- 5 底部页签 ----------
func _build_tabbar() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, 1156)
	bar.size = Vector2(720, 124)
	bar.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color("16110c"), 3, Color("2b1e12")))
	add_child(bar)
	var defs: Array = [
		["商店", _noop, true], ["卡牌", _on_progression, false], ["对战", _noop, false],
		["闯关", _on_stage, false], ["探险", _noop, true],
	]
	var x := 0.0
	for i in defs.size():
		var center: bool = i == 2
		var w: float = 168.0 if center else 138.0
		var d: Array = defs[i]
		var btn := _pin_button(String(d[0]), Vector2(x + 6.0, 1170.0 if center else 1178.0),
				Vector2(w - 12.0, 100.0 if center else 88.0), d[1],
				"gold" if center else "dark", 30 if center else 24)
		btn.disabled = bool(d[2])
		x += w

# ---------- 数据回填（economy_changed 订阅，框架地基#2）----------
func _on_economy_changed(cache) -> void:
	if cache != null:
		_populate(cache, GameStateScript.config())

func _populate(cache, config) -> void:
	_set_wallet(cache.gold, cache.gems)
	# 挂机（活动轨）
	var now_ts := int(Time.get_unix_time_from_system())
	var pending: int = cache.idle_pending(now_ts, config)
	_idle_lbl.text = ("+%s 金币" % HudWidgets.format_int(pending)) if pending > 0 else "产出中…"
	_idle_btn.disabled = pending <= 0
	# 闯关进度 + 章节 + 下一关角标
	var sp = StageProgressScript.new(config.stages)
	var total: int = sp.ordered_ids().size()
	var cleared := 0
	for sid in cache.stages:
		if bool((cache.stages[sid] as Dictionary).get("cleared", false)):
			cleared += 1
	_prog_fill.size.x = 394.0 * (float(cleared) / float(maxi(1, total)))
	_prog_txt.text = "闯关进度 %d / %d" % [cleared, total]
	var next_id: String = sp.next_stage(cache)
	if next_id != "":
		var st: Dictionary = config.get_stage(next_id)
		_chapter_lbl.text = "第 %d 章" % int(st.get("chapter", 0))
		_stage_badge.text = "%d-%d" % [int(st.get("chapter", 0)), int(st.get("index", 0))]
	else:
		_chapter_lbl.text = "全部通关"
		_stage_badge.text = "毕业"
	# 卡组角标 = 当前卡组张数；对战副标 = 杯数
	var deck_n: int = GameStateScript.player_deck.size()
	_deck_badge.text = str(deck_n if deck_n > 0 else 8)
	_battle_sub.text = "天梯匹配 · %d杯" % GameStateScript.session().trophies()

func _set_offline() -> void:
	_idle_lbl.text = "离线"
	_idle_btn.disabled = true
	_prog_txt.text = "未连接服务器 · 进度暂不可用"

func _set_wallet(gold: int, gems: int) -> void:
	for c in _wallet_holder.get_children():
		c.queue_free()
	_wallet_holder.add_child(HudWidgets.wallet_bar(gold, gems, 312.0))

# ---------- 登录重试门 ----------
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
func _noop() -> void:
	pass

func _on_ladder() -> void:
	# V5-S9 改动5：天梯先选卡组（存槽1）再进匹配。
	GameStateScript.deck_mode = "ladder"
	GameStateScript.stage_id = ""
	Router.goto("deck_builder")

func _on_stage() -> void:
	Router.goto("stage_map")   # CR 改版：直进闯关地图（基地页废弃，挂机已并入活动轨）

func _on_progression() -> void:
	Router.goto("card_collection")

func _on_deck() -> void:
	GameStateScript.deck_mode = "edit"
	GameStateScript.stage_id = ""
	Router.goto("deck_builder")

func _on_settings() -> void:
	Router.goto("settings")

func _on_collect_idle() -> void:
	_idle_btn.disabled = true
	var session = GameStateScript.session()
	var config = GameStateScript.config()
	await GameStateScript.economy().collect_idle(_http, session.token(), config.cards.keys())
	# 成功 → economy_changed 订阅刷新（挂机清零后按钮回禁用态）；失败维持禁用防连点

# ---------- ui builders ----------
func _badge(host: Control, text: String) -> Label:
	var p := Panel.new()
	p.position = Vector2(host.size.x - 26, -14)
	p.size = Vector2(46, 40)
	p.add_theme_stylebox_override("panel", PixelUI.sbpixel(COL_BADGE, 3, Color("2b1e12")))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(p)
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return l

func _child_label(host: Control, text: String, y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(host.size.x, float(font_size) + 16.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(l)
	return l

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
	(_boot_ui if _boot_ui != null else self).add_child(l)
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
	(_boot_ui if _boot_ui != null else self).add_child(l)
	return l

func _pin_button(
		text: String, pos: Vector2, sz: Vector2, cb: Callable, kind: String, font_size: int
) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.pivot_offset = sz * 0.5
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, kind, font_size)
	btn.pressed.connect(_on_pressed.bind(cb))
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	return btn

func _menu_button(text: String, y: float, cb: Callable, kind: String = "stone", font_size: int = 34) -> Button:
	return _pin_button(text, Vector2((720.0 - 384.0) / 2.0, y), Vector2(384.0, 112.0), cb, kind, font_size)

func _scale_to(btn: Button, s: float) -> void:
	create_tween().tween_property(btn, "scale", Vector2(s, s), 0.07)

func _on_pressed(cb: Callable) -> void:
	AudioManager.play_sfx("ui_button_press")
	cb.call()
