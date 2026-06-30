# BaseCamp —— V5-S7b 基地（单人闯关养成中枢，决策48 瘦客户端）。
#
# 替换主菜单 START 入口。进来 = 登录(复用 session) → 拉服务器经济状态(EconomyStateCache) →
# 展示 钱包 / 队伍战力 / 挂机收益(可领) → 分发到 闯关(stage_map) / 养成(card_collection) / 卡组 / 天梯。
# 读 = 缓存(服务器权威快照)；执行(领挂机) = EconomyStateCache.collect_idle → 服务器算+落库；
# 展示侧成本/战力/关卡 = 本地 ConfigLoader(非权威预览)。断线/未登录 → 离线降级展示。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const GameStateScript := preload("res://view/game_state.gd")
const StageProgressScript := preload("res://logic/stage_progress.gd")
const BG_TEX := preload("res://assets/ui/menu_bg.png")

const MENU_SCENE := "res://view/main_menu.tscn"
const STAGE_MAP_SCENE := "res://view/stage_map.tscn"          # S7c（未建则提示）

var _http: HTTPRequest
var _wallet_holder: Control
var _power_main: Label
var _power_shadow: Label
var _power_sub: Label
var _idle_value: Label
var _idle_rate: Label
var _collect_btn: Button
var _cta_btn: Button

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	_build_static()
	_http = HTTPRequest.new()
	add_child(_http)
	await _bootstrap()

# ---------- 静态骨架（始终在，先占位，数据回来再填）----------
func _build_static() -> void:
	var bg := TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_wallet_holder = Control.new()
	_wallet_holder.position = Vector2(80, 28)
	_wallet_holder.size = Vector2(560, 44)
	_wallet_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet_holder)
	_set_wallet(0, 0)

	_center_label("基地 · BASE CAMP", 92, 20, PixelUI.COL_HINT)
	_center_label("队伍战力", 150, 24, PixelUI.COL_MUTED)
	_power_shadow = _center_label("—", 184, 76, PixelUI.COL_OUTLINE)
	_power_shadow.position += Vector2(3, 3)
	_power_main = _center_label("—", 184, 76, PixelUI.COL_GOLD)
	_power_sub = _center_label("", 290, 22, PixelUI.COL_MUTED)

	_build_idle_card(348)

	# V5-S9：基地瘦身=PVE 中枢，只留闯关 + 钱包/挂机/战力（养成/卡组/天梯已上提到主菜单）。
	_cta_btn = _menu_button("闯关", 560, _on_stage_pressed, "gold", 44, 440, 120)

	_menu_button(tr("btn_back"), 1170, _on_back_pressed, "dark", 28, 240, 72)

func _build_idle_card(y: float) -> void:
	var card := Panel.new()
	card.position = Vector2(80, y)
	card.size = Vector2(560, 132)
	card.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color("1c1626"), 3, Color("4a3a14")))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	_pin_label("挂机收益", Vector2(104, y + 18), 28, PixelUI.COL_PARCHMENT)
	_idle_value = _pin_label("+0 金币", Vector2(104, y + 56), 30, PixelUI.COL_GOLD)
	_idle_rate = _pin_label("产出中…", Vector2(104, y + 96), 20, PixelUI.COL_HINT)
	_collect_btn = Button.new()
	_collect_btn.text = "领取"
	_collect_btn.position = Vector2(480, y + 24)
	_collect_btn.size = Vector2(130, 84)
	_collect_btn.pivot_offset = Vector2(65, 42)
	_collect_btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(_collect_btn, "gold", 30)
	_collect_btn.pressed.connect(_on_collect_pressed)
	_collect_btn.button_down.connect(_scale_to.bind(_collect_btn, 0.96))
	_collect_btn.button_up.connect(_scale_to.bind(_collect_btn, 1.0))
	_collect_btn.visible = false   # 待领=0 隐藏（设计 §7）；_populate 按 pending 显示
	add_child(_collect_btn)

# ---------- 数据 ----------
func _bootstrap() -> void:
	print("[V5][base] 进入基地 → 登录 + 拉经济状态")
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		print("[V5][base] 登录失败 → 离线展示")
		_set_offline()
		return
	var config = GameStateScript.config()
	var all_ids: Array = config.cards.keys()
	var econ = GameStateScript.economy()
	var res: Dictionary = await econ.refresh(_http, session.token(), all_ids)
	if bool(res.get("ok", false)):
		_populate(econ.get_cache(), config)
	else:
		_set_offline()

func _populate(cache, config) -> void:
	_set_wallet(cache.gold, cache.gems)
	# 队伍战力（当前卡组 = 已设卡组否则默认已解锁前 8）+ 按下一关推荐着色
	var deck := _current_deck(cache)
	var power := int(cache.team_power(deck, config))
	var sp = StageProgressScript.new(config.stages)
	var next_id: String = sp.next_stage(cache)
	var rec := 0
	var chapter := 0
	if next_id != "":
		var st: Dictionary = config.get_stage(next_id)
		rec = int(st.get("recommended_power", 0))
		chapter = int(st.get("chapter", 0))
	var tier := HudWidgets.power_tier(power, rec)
	_power_main.text = HudWidgets.format_int(power)
	_power_shadow.text = _power_main.text
	_power_main.add_theme_color_override("font_color", HudWidgets.power_tier_color(tier))
	if rec > 0:
		_power_sub.text = "下一关推荐 %s" % HudWidgets.format_int(rec)
	else:
		_power_sub.text = "全部通关 · 已毕业"
	# 闯关 CTA
	_cta_btn.text = ("闯关 · 第%d章" % chapter) if chapter > 0 else "闯关 · 已通关"
	# 挂机
	var now_ts := int(Time.get_unix_time_from_system())
	var pending: int = cache.idle_pending(now_ts, config)
	var rate: int = cache.idle_rate_per_hour(config)
	var cap_h := int((config.get_economy().get("idle", {}) as Dictionary).get("cap_hours", 0))
	_idle_value.text = "+%s 金币" % HudWidgets.format_int(pending)
	_idle_rate.text = "%s/小时 · 封顶 %dh" % [HudWidgets.format_int(rate), cap_h]
	_collect_btn.visible = pending > 0

func _current_deck(cache) -> Array:
	if not GameStateScript.player_deck.is_empty():
		return GameStateScript.player_deck
	var unlocked: Array = cache.unlocked_card_ids()
	return unlocked.slice(0, mini(8, unlocked.size()))

func _set_wallet(gold: int, gems: int) -> void:
	for c in _wallet_holder.get_children():
		c.queue_free()
	_wallet_holder.add_child(HudWidgets.wallet_bar(gold, gems, 560.0))

func _set_offline() -> void:
	_power_main.text = "离线"
	_power_shadow.text = "离线"
	_power_sub.text = "未连接服务器 · 仅离线展示"
	_idle_value.text = "—"
	_idle_rate.text = "需登录后产出"
	_collect_btn.visible = false

# ---------- handlers ----------
func _on_collect_pressed() -> void:
	if not _collect_btn.visible:
		return
	AudioManager.play_sfx("ui_button_press")
	_collect_btn.disabled = true
	var session = GameStateScript.session()
	var config = GameStateScript.config()
	var res: Dictionary = await GameStateScript.economy().collect_idle(_http, session.token(), config.cards.keys())
	if bool(res.get("ok", false)):
		_populate(GameStateScript.economy().get_cache(), config)

func _on_stage_pressed() -> void:
	_go(STAGE_MAP_SCENE, "闯关地图（S7c）即将上线")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _go(path: String, not_ready_hint: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		_toast(not_ready_hint)

# ---------- ui builders（沿用 main_menu 范式）----------
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

func _pin_label(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _menu_button(text: String, y: float, cb: Callable, kind: String, font_size: int, bw: float, bh: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = Vector2((720.0 - bw) / 2.0, y)
	btn.size = Vector2(bw, bh)
	btn.pivot_offset = Vector2(bw / 2.0, bh / 2.0)
	btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(btn, kind, font_size)
	btn.pressed.connect(_on_button.bind(cb))
	btn.button_down.connect(_scale_to.bind(btn, 0.96))
	btn.button_up.connect(_scale_to.bind(btn, 1.0))
	add_child(btn)
	return btn

func _on_button(cb: Callable) -> void:
	AudioManager.play_sfx("ui_button_press")
	cb.call()

func _scale_to(c: Control, s: float) -> void:
	create_tween().tween_property(c, "scale", Vector2(s, s), 0.07)

func _toast(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.position = Vector2(0, 1080)
	l.size = Vector2(720, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", PixelUI.COL_GOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
