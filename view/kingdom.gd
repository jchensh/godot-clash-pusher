# Kingdom —— 王国主城（D6 起 3D：view/three_d/kingdom_presenter.gd 渲染地面/路/城墙/16 建筑/居民）。
#
# 布局仍以 BG 像素系槽位表为真相源（pos = 建筑正面底边中心，按美术示意图落位；w = 建筑宽度像素），
# 3D 场景按 40 像素 = 1 米摆放，与 2D 时代布局一致。镜头正交斜俯视：拖动平移、滚轮/双指缩放、焦点钳在城内。
# 名牌/施工倒计时/待收取气泡仍是 2D 叠加（跟随建筑 3D 位置投影）；HUD 用 Control 子节点浮在上层；
# 点建筑 → UI.modal(KingdomBuildingModal)；placeholder 建筑（config kind）建成后点击=敬请期待。
# 决策 48 + 永久原则：服务器权威——本页只收发数据 + 表现；倒计时用服务器时间基准插值。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const GameStateScript := preload("res://view/game_state.gd")
const BuildingModal := preload("res://view/ui/kingdom_building_modal.gd")
const KingdomPresenter := preload("res://view/three_d/kingdom_presenter.gd")

const BG_SIZE := Vector2(1440.0, 1830.0)   # 场景坐标系尺寸（沿用 0726 口径；示意图同尺寸）
# 槽位（BG 像素系，pos=建筑底边中心；按 0830 卡通示意图落位；w=建筑宽度，沿用 2D 贴图原生宽，真人验收可调）。
const SLOTS := {
	"keep": {"pos": Vector2(705, 660), "w": 221.0},
	"farm": {"pos": Vector2(1115, 455), "w": 181.0},
	"workshop": {"pos": Vector2(280, 650), "w": 128.0},
	"granary": {"pos": Vector2(828, 1000), "w": 143.0},
	"mint": {"pos": Vector2(1130, 1215), "w": 170.0},
	"wall": {"pos": Vector2(710, 1552), "w": 253.0},   # wall 槽=城门，骑底墙中央（墙带中心 y≈1500）
	"watchtower": {"pos": Vector2(150, 1420), "w": 82.0},
	"quarry": {"pos": Vector2(370, 455), "w": 142.0},
	"stoneworks": {"pos": Vector2(480, 790), "w": 139.0},
	"ironworks": {"pos": Vector2(1140, 790), "w": 133.0},
	"ranch": {"pos": Vector2(950, 610), "w": 148.0},
	"shop": {"pos": Vector2(570, 1010), "w": 149.0},
	"camp_infantry": {"pos": Vector2(287, 940), "w": 146.0},
	"camp_spear": {"pos": Vector2(287, 1190), "w": 148.0},
	"camp_crossbow": {"pos": Vector2(560, 1230), "w": 161.0},
	"camp_cavalry": {"pos": Vector2(872, 1215), "w": 139.0},
}
# 箭塔四角：主槽=左下（贴墙内侧）；其余三角为视觉复刻（建成才现身，也可点选=箭塔）。
const WT_EXTRAS := [Vector2(1290, 1420), Vector2(150, 330), Vector2(1290, 330)]
# —— 城墙/路网布局（BG 像素系）——
const WALL_TOP_Y := 230.0      # 顶墙中线
const WALL_BOT_Y := 1500.0     # 底墙中线
const WALL_LEFT_X := 90.0      # 左墙中线
const WALL_RIGHT_X := 1350.0   # 右墙中线
const GATE_GAP := 220.0        # 底墙城门开口宽（城门模型骑缝盖住接缝）
# 路网＝运行时按 SLOTS 生成（干线：竖主干 城堡→城门 + 中/下横干；每建筑门口垂直支路，建筑挪位路自动跟随）。
const ROAD_W := 64.0
const ROAD_MID_Y := 850.0      # 中横干中线
const ROAD_LOW_Y := 1198.0     # 下横干中线（下排四营/药剂工坊门口贴线，无需支路）
const ROAD_SPUR_BUILDINGS := ["quarry", "farm", "workshop", "ranch", "stoneworks",
		"ironworks", "camp_infantry", "granary", "shop"]
# 装饰散点（kind, pos=底边中心；示意图角落感）
const DECO_ITEMS := [
	["tree1", Vector2(180, 350)], ["tree2", Vector2(1260, 320)], ["tree3", Vector2(1300, 560)],
	["tree1", Vector2(160, 1330)], ["tree2", Vector2(1280, 1340)], ["tree3", Vector2(620, 380)],
	["tree2", Vector2(200, 780)], ["tree1", Vector2(1310, 1000)],
	["flower1", Vector2(500, 620)], ["flower2", Vector2(940, 1100)], ["flower1", Vector2(1200, 640)],
	["bamboo", Vector2(420, 1330)], ["bamboo", Vector2(1050, 380)],
	["barrel", Vector2(760, 400)], ["barrel", Vector2(340, 1080)],
	["pumpkin", Vector2(905, 785)],   # 南瓜居民屋（大型装饰，占示意图原位）
]
# —— 巡游居民（战斗单位 3D 模型播 Walk；数量/速度纯表现，与逻辑无关）——
const WALKER_IDS := ["squire_body", "goblin_body", "archer_body", "barbarian_body", "knight_body"]
const DRAG_THRESHOLD := 12.0   # 按下后移动超过此像素 = 拖动平移（不再触发点选）
const WHEEL_ZOOM := 1.12

var _land := false
var _world   # KingdomPresenter（3D 场景 + 镜头 + 点选）
var _pressing := false
var _dragged := false
var _press := Vector2.ZERO
var _last := Vector2.ZERO
var _touches: Dictionary = {}  # 触点 index → 位置（双指缩放）
var _font: Font
var _http: HTTPRequest
var _elapsed := 0.0
# —— HUD ——
var _res_lbl: Label
var _wallet_holder: Control
var _def_lbl: Label
var _collect_btn: Button

func _ready() -> void:
	_land = GameStateScript.ui_layout() == "landscape"
	AudioManager.play_music("music_main_menu")
	_font = load("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")
	_init_world()
	_build_hud()
	Events.kingdom_changed.connect(_on_kingdom_changed)
	Events.economy_changed.connect(_on_economy_changed)
	_http = HTTPRequest.new()
	add_child(_http)
	set_process(true)
	await _bootstrap()

# ---------- 3D 场景（纯表现）----------
func _init_world() -> void:
	_world = KingdomPresenter.new()
	_world.name = "World3D"
	add_child(_world)
	var heights := {}
	for uid in WALKER_IDS:
		heights[uid] = float(GameStateScript.config().get_unit(uid).get("vis_height_px", 0.0))
	_world.setup({
		"slots": SLOTS, "deco": DECO_ITEMS, "roads": build_roads(), "watchtower_extras": WT_EXTRAS,
		"walls": {"top": WALL_TOP_Y, "bottom": WALL_BOT_Y, "left": WALL_LEFT_X, "right": WALL_RIGHT_X,
			"gate_x": float(SLOTS["wall"]["pos"].x), "gate_gap": GATE_GAP},
		"walkers": WALKER_IDS, "unit_heights": heights,
	}, get_viewport_rect().size)
	_sync_world()
	Log.i("[V5][kingdom] 王国 3D 场景就绪 槽位=%d 居民=%d" % [SLOTS.size(), _world.walker_count()])

static func build_roads() -> Array:
	var keep_pos: Vector2 = SLOTS["keep"]["pos"]
	var trunk_x: float = keep_pos.x - ROAD_W * 0.5
	var roads: Array = [
		Rect2(trunk_x, keep_pos.y - 10.0, ROAD_W, 1560.0 - (keep_pos.y - 10.0)),
		Rect2(248.0, ROAD_MID_Y - ROAD_W * 0.5, 924.0, ROAD_W),
		Rect2(248.0, ROAD_LOW_Y - ROAD_W * 0.5, 924.0, ROAD_W),
	]
	for b in ROAD_SPUR_BUILDINGS:
		var bp: Vector2 = SLOTS[b]["pos"]
		var x: float = bp.x - ROAD_W * 0.5
		if bp.y < ROAD_MID_Y:
			roads.append(Rect2(x, bp.y - 14.0, ROAD_W, ROAD_MID_Y - bp.y + 14.0))
		else:
			roads.append(Rect2(x, ROAD_MID_Y, ROAD_W, bp.y - ROAD_MID_Y + 14.0))
	return roads

# 建筑形态跟服务器缓存：未建=空地、施工中=外罩脚手架、建成=正式模型（每帧比对，施工到点自动拆架）。
func _sync_world() -> void:
	var kd = GameStateScript.kingdom()
	for b in SLOTS:
		var building_now: bool = kd != null and kd.is_loaded and int(kd.remaining_s(b)) > 0
		_world.set_slot_state(b, _level_of(b, kd), building_now)

func _process(delta: float) -> void:
	_elapsed += delta
	_world.advance(delta)
	_sync_world()
	queue_redraw()

# ---------- 2D 叠加（恒在 3D 之上）：名牌+等级 / 施工倒计时 / 待收取气泡 ----------
func _draw() -> void:
	var kd = GameStateScript.kingdom()
	for b in SLOTS:
		_draw_building_overlay(String(b), kd)

func _draw_building_overlay(building: String, kd) -> void:
	var rect: Rect2 = _world.screen_rect(building)
	var pos: Vector2 = _world.base_screen(building)
	var lv := _level_of(building, kd)
	_plate(Vector2(pos.x, pos.y + 4.0), _label_of(building, lv), 16, PixelUI.COL_PARCHMENT if lv > 0 else PixelUI.COL_MUTED)
	if lv <= 0 or kd == null or not kd.is_loaded:
		return
	var remain := int(kd.remaining_s(building))
	if remain > 0:
		_plate(Vector2(pos.x, rect.position.y - 28.0), "施工 %s" % _fmt_dur(remain), 17, PixelUI.COL_GOLD)
	elif _has_pending(building, kd):
		# 待收取气泡（SLG 式）：建筑头顶金色圆点脉动。
		var c := Vector2(pos.x, rect.position.y - 16.0)
		var pulse := 0.85 + 0.15 * sin(_elapsed * 5.0)
		draw_circle(c, 14.0 * pulse, Color.WHITE)
		draw_circle(c, 11.0 * pulse, Color("f6c343"))
		draw_string(_font, c + Vector2(-5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PixelUI.COL_GOLD_INK)

# 白卡名牌（天空牧场：浅底深字），top_center 为卡片顶边中点；返回卡片矩形。
func _plate(top_center: Vector2, text: String, font_size: int, color: Color) -> Rect2:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var r := plate_rect(top_center, tw, font_size)
	draw_rect(r, Color(1, 1, 1, 0.9))
	draw_rect(r, PixelUI.COL_SLOT_FILLED_BD, false, 2.0)
	draw_string(_font, Vector2(r.position.x + 7.0, r.position.y + float(font_size) + 1.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return r

func _label_of(building: String, lv: int) -> String:
	var bcfg: Dictionary = (GameStateScript.config().kingdom.get("buildings", {}) as Dictionary).get(building, {})
	return str(bcfg.get("display_zh", building)) + ((" Lv%d" % lv) if lv > 0 else "（空地）")

# 各建筑名牌的当前屏幕矩形（与 _draw 同口径，按当前镜头现算——点选不用上一帧的旧位置）。
func _name_plates(kd) -> Dictionary:
	var plates := {}
	for b in SLOTS:
		var text := _label_of(b, _level_of(b, kd))
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
		plates[b] = plate_rect(_world.base_screen(b) + Vector2(0, 4.0), tw, 16)
	return plates

static func plate_rect(top_center: Vector2, text_width: float, font_size: int) -> Rect2:
	return Rect2(top_center.x - text_width * 0.5 - 7.0, top_center.y, text_width + 14.0, float(font_size) + 8.0)

# ---------- 输入：拖动平移 / 滚轮与双指缩放 / 轻点命中建筑 → 弹操作窗或敬请期待 ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_on_touch(event)
		return
	if event is InputEventMagnifyGesture:
		var g := event as InputEventMagnifyGesture
		_world.zoom_at(g.position, 1.0 / maxf(g.factor, 0.01))
		return
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_world.zoom_at(e.position, 1.0 / WHEEL_ZOOM if e.button_index == MOUSE_BUTTON_WHEEL_UP else WHEEL_ZOOM)
			return
		if e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			_pressing = true
			_dragged = false
			_press = e.position
			_last = e.position
		else:
			_pressing = false
			if not _dragged and _touches.size() < 2:
				_click(e.position)
	elif event is InputEventMouseMotion and _pressing and _touches.size() < 2:
		var p: Vector2 = (event as InputEventMouseMotion).position
		if _dragged or p.distance_to(_press) > DRAG_THRESHOLD:
			_dragged = true
			_world.pan_by(p - _last)
			_last = p

# 双指缩放：两触点距离变化比 → 以中点为中心缩放；期间不平移、不点选。
func _on_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		if _touches.size() >= 2:
			_dragged = true
		return
	var d := event as InputEventScreenDrag
	if not _touches.has(d.index):
		return
	if _touches.size() < 2:
		_touches[d.index] = d.position
		return
	var keys := _touches.keys()
	var other: Vector2 = _touches[keys[1] if keys[0] == d.index else keys[0]]
	var before: float = (_touches[d.index] as Vector2).distance_to(other)
	_touches[d.index] = d.position
	var after: float = d.position.distance_to(other)
	if before > 1.0 and after > 1.0:
		_world.zoom_at((d.position + other) * 0.5, before / after)

func _click(p: Vector2) -> void:
	var kd = GameStateScript.kingdom()
	if kd == null or not kd.is_loaded:
		return
	var best: String = _world.pick(p, _name_plates(kd))
	if best == "":
		return
	AudioManager.play_sfx("ui_button_press")
	var bcfg: Dictionary = (GameStateScript.config().kingdom.get("buildings", {}) as Dictionary).get(best, {})
	if _level_of(best, kd) >= 1 and str(bcfg.get("kind", "")) == "placeholder":
		UI.toast("敬请期待")   # 0726 用户口径：placeholder 建筑可建造，功能后续设计
		return
	var m := BuildingModal.new()
	m.building = best
	UI.modal(m)

# ---------- HUD（Control 子节点，恒浮场景之上）----------
func _build_hud() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 92) if _land else Vector2(720, 118)
	bar.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color(1.0, 1.0, 1.0, 0.9), 3, Color("a9d3ee")))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_pin_label("王国领地", Vector2(28, 12) if _land else Vector2(28, 12), 26, PixelUI.COL_GOLD)
	_res_lbl = _pin_label("粮草 — · 木石 —", Vector2(28, 54) if _land else Vector2(28, 52), 20,
			PixelUI.COL_PARCHMENT)
	_def_lbl = _pin_label("城防：塔 HP +0% · 塔攻 +0%",
			Vector2(330, 58) if _land else Vector2(28, 84), 16, PixelUI.COL_HINT)
	_wallet_holder = Control.new()
	_wallet_holder.position = Vector2(690, 12) if _land else Vector2(430, 12)
	_wallet_holder.size = Vector2(270, 40)
	_wallet_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet_holder)
	_collect_btn = Button.new()
	_collect_btn.position = Vector2(1030, 22) if _land else Vector2(474, 58)
	_collect_btn.size = Vector2(226, 50)
	_collect_btn.pivot_offset = _collect_btn.size * 0.5
	_collect_btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(_collect_btn, "gold", 20)
	_collect_btn.text = "收取产出"
	_collect_btn.visible = false
	_collect_btn.pressed.connect(_on_collect)
	add_child(_collect_btn)
	var back := Button.new()
	back.text = tr("btn_back")
	back.position = Vector2(20, 646) if _land else Vector2(20, 1204)
	back.size = Vector2(170, 58)
	back.pivot_offset = back.size * 0.5
	back.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(back, "dark", 22)
	back.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_button_back")
		Router.goto("main_menu"))
	add_child(back)

# ---------- 数据 ----------
func _bootstrap() -> void:
	Log.i("[V5][kingdom] 进入王国主城 → 登录 + 拉王国/经济状态")
	var session = GameStateScript.session()
	if not await session.ensure(_http):
		Log.w("[V5][kingdom] 登录失败 → 离线展示")
		_res_lbl.text = "未连接服务器 · 王国暂不可用"
		return
	var config = GameStateScript.config()
	await GameStateScript.kingdom().refresh(_http, session.token())
	if GameStateScript.economy().get_cache() == null:
		await GameStateScript.economy().refresh(_http, session.token(), config.cards.keys())

func _on_kingdom_changed(kd) -> void:
	if kd == null or not kd.is_loaded:
		return
	var res: Dictionary = kd.cache.get("resources", {})
	_res_lbl.text = "粮草 %s · 木石 %s" % [
		HudWidgets.format_int(int(res.get("food", 0))), HudWidgets.format_int(int(res.get("wood", 0)))]
	var pending: Dictionary = kd.cache.get("pending", {})
	var pgold := int(kd.cache.get("pending_gold", 0))
	var has_pending: bool = pgold > 0 or not pending.is_empty()
	_collect_btn.visible = has_pending
	if has_pending:
		var parts: Array = []
		for r in pending:
			parts.append("+%d%s" % [int(pending[r]), _res_zh(str(r))])
		if pgold > 0:
			parts.append("+%d金" % pgold)
		_collect_btn.text = "收取 " + " ".join(parts)
	_def_lbl.text = "城防：塔 HP +%d%% · 塔攻 +%d%%（K4 接战斗）" % [
		_def_pct("wall", "tower_hp_pct", kd), _def_pct("watchtower", "tower_dmg_pct", kd)]
	queue_redraw()

func _on_economy_changed(cache) -> void:
	if cache == null:
		return
	for c in _wallet_holder.get_children():
		c.queue_free()
	_wallet_holder.add_child(HudWidgets.wallet_bar(cache.gold, cache.gems, 270.0))

func _on_collect() -> void:
	AudioManager.play_sfx("ui_button_press")
	_collect_btn.disabled = true
	var session = GameStateScript.session()
	var res: Dictionary = await GameStateScript.kingdom().collect(_http, session.token())
	_collect_btn.disabled = false
	if bool(res.get("ok", false)):
		# 铸币坊金币进主钱包 → 拉一次经济让钱包条同步。
		await GameStateScript.economy().refresh(_http, session.token(), GameStateScript.config().cards.keys())
	else:
		UI.toast(BuildingModal.reject_text(int(res.get("error_code", 0))))

# ---------- 小助手 ----------
func _level_of(building: String, kd) -> int:
	if kd == null or not kd.is_loaded:
		# 未加载时按初始配置画（王城/农田/工坊 Lv1），避免整城空地闪一下。
		var init: Dictionary = ((GameStateScript.config().kingdom.get("rules", {}) as Dictionary)
				.get("initial", {}) as Dictionary).get("buildings", {})
		return int(init.get(building, 0))
	return int(kd.building_level(building))

func _has_pending(building: String, kd) -> bool:
	var bcfg: Dictionary = (GameStateScript.config().kingdom.get("buildings", {}) as Dictionary).get(building, {})
	if str(bcfg.get("kind", "")) != "producer":
		return false
	var produces := str(bcfg.get("produces", ""))
	if produces == "gold":
		return int(kd.cache.get("pending_gold", 0)) > 0
	return int((kd.cache.get("pending", {}) as Dictionary).get(produces, 0)) > 0

func _def_pct(building: String, field: String, kd) -> int:
	var lv := int(kd.building_level(building))
	var total := 0
	var lvs: Array = ((GameStateScript.config().kingdom.get("buildings", {}) as Dictionary)
			.get(building, {}) as Dictionary).get("levels", [])
	for i in mini(lv, lvs.size()):
		total += int((lvs[i] as Dictionary).get(field, 0))
	return total

func _res_zh(res: String) -> String:
	match res:
		"food": return "粮草"
		"wood": return "木石"
		"gold": return "金币"
	return res

func _fmt_dur(s: int) -> String:
	if s <= 0:
		return "即时"
	if s < 3600:
		return "%d:%02d" % [s / 60, s % 60]
	if s < 86400:
		return "%d时%d分" % [s / 3600, (s % 3600) / 60]
	return "%d天%d时" % [s / 86400, (s % 86400) / 3600]

func _pin_label(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
