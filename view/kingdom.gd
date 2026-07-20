# Kingdom —— 王国主城（K2 场景化改版，2026-07-19 用户拍板：SLG/4X 式主城，
# 场景化 + 动态小人，不做按钮列表）。
#
# 视觉 = 老中世纪占位资源（building1~8 城堡组 + Lonesome 地形 + SpriteDB 走路小人），
# 正式三国城建美术后整体换皮。架构同 battle_scene：纯 _draw 即时渲染（地形/建筑/小人
# Y-sort 伪深度），HUD 用 Control 子节点浮在上层；点建筑 → UI.modal(KingdomBuildingModal)。
# 决策 48 + 永久原则：服务器权威——本页只收发数据 + 表现；倒计时用服务器时间基准插值。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const GameStateScript := preload("res://view/game_state.gd")
const SpriteDB := preload("res://view/sprite_db.gd")
const BuildingModal := preload("res://view/ui/kingdom_building_modal.gd")

# —— 地形（战场同款 Lonesome 套）——
const TEX_FLOOR := preload("res://assets/terrain/Lonesome_Forest_FLOOR.png")
const TEX_PATH := preload("res://assets/terrain/Lonesome_Forest_COBBLESTONE_PATH.png")
const TEX_UNIT_SHADOW := preload("res://assets/units/unit_shadow.png")
const TILE_PX := 16          # 源 tile 尺寸
const CELL := 40.0           # 屏幕格边长（720/18）
const GROUND_TILES := [Vector2i(4, 1), Vector2i(4, 2)]
const PATH_TILES := [Vector2i(1, 1), Vector2i(2, 1)]

# —— 建筑贴图（2026-07-21 正式三国城建素材，testAssets/7.21.2026/王国领地 接入）——
const BUILDING_TEX := {
	"keep": preload("res://assets/kingdom/kingdom_palace.png"),
	"farm": preload("res://assets/kingdom/kingdom_farm.png"),
	"workshop": preload("res://assets/kingdom/kingdom_workshop.png"),
	"watchtower": preload("res://assets/kingdom/kingdom_watchtower.png"),
	"granary": preload("res://assets/kingdom/kingdom_granary.png"),
	"mint": preload("res://assets/kingdom/kingdom_mint.png"),
	"wall": preload("res://assets/kingdom/kingdom_wall.png"),
}
# —— 装饰树（同批素材；纯表现，不可点击，随建筑/小人一起 Y-sort）——
const TREE_TEX := [
	preload("res://assets/kingdom/kingdom_tree_1.png"),
	preload("res://assets/kingdom/kingdom_tree_2.png"),
	preload("res://assets/kingdom/kingdom_tree_3.png"),
]
# [tex_idx, 底边中心 pos, 绘制宽]，摆在槽位/路网空隙处，位置留真人验收调。
const TREE_DECO := [
	[0, Vector2(56, 420), 88.0],
	[1, Vector2(664, 440), 92.0],
	[2, Vector2(52, 1240), 80.0],
	[0, Vector2(676, 1252), 84.0],
]
# 槽位：pos = 建筑底边中心（屏幕 px），w = 绘制宽。布局参照 SLG 主城：王城居中偏上、
# 生产环绕、城防近前门。
const SLOTS := {
	"keep": {"pos": Vector2(360, 560), "w": 300.0},
	"farm": {"pos": Vector2(150, 780), "w": 210.0},
	"workshop": {"pos": Vector2(570, 790), "w": 220.0},
	"granary": {"pos": Vector2(130, 990), "w": 130.0},
	"mint": {"pos": Vector2(588, 1000), "w": 175.0},
	"wall": {"pos": Vector2(238, 1146), "w": 190.0},
	"watchtower": {"pos": Vector2(510, 1140), "w": 110.0},
}
const PLAZA := Vector2(360, 700)   # 中央广场（路网与小人巡游枢纽）

# —— 巡游小人（占位=战斗单位走路帧；数量/速度纯表现，与逻辑无关）——
const WALKER_IDS := ["squire_body", "goblin_body", "archer_body", "barbarian_body", "knight_body"]
const WALKER_BOX := 46.0
const WALKER_SPEED_MIN := 34.0
const WALKER_SPEED_MAX := 58.0

var _font: Font
var _http: HTTPRequest
var _elapsed := 0.0
var _walkers: Array = []       # [{uid, pos, target, speed, at_plaza}]
var _path_cells: Array = []    # 路面格 Vector2i（_ready 预铺）
# —— HUD ——
var _res_lbl: Label
var _wallet_holder: Control
var _def_lbl: Label
var _collect_btn: Button

func _ready() -> void:
	AudioManager.play_music("music_main_menu")
	_font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
	_build_paths()
	_spawn_walkers()
	_build_hud()
	Events.kingdom_changed.connect(_on_kingdom_changed)
	Events.economy_changed.connect(_on_economy_changed)
	_http = HTTPRequest.new()
	add_child(_http)
	set_process(true)
	await _bootstrap()

# ---------- 路网/小人（纯表现）----------
func _build_paths() -> void:
	var seen := {}
	for b in SLOTS:
		var from: Vector2 = (SLOTS[b]["pos"] as Vector2) + Vector2(0, -6)
		# L 型：先横到广场 x，再纵到广场 y。
		var cx := int(from.x / CELL)
		var cy := int(from.y / CELL)
		var px := int(PLAZA.x / CELL)
		var py := int(PLAZA.y / CELL)
		var x := cx
		while x != px:
			seen[Vector2i(x, cy)] = true
			x += 1 if px > cx else -1
		var y := cy
		while y != py:
			seen[Vector2i(px, y)] = true
			y += 1 if py > cy else -1
	# 广场 2×2
	for dx in [-1, 0]:
		for dy in [-1, 0]:
			seen[Vector2i(int(PLAZA.x / CELL) + dx, int(PLAZA.y / CELL) + dy)] = true
	_path_cells = seen.keys()

func _spawn_walkers() -> void:
	for i in WALKER_IDS.size():
		var slot: Vector2 = (SLOTS[SLOTS.keys()[i % SLOTS.size()]]["pos"] as Vector2)
		_walkers.append({
			"uid": WALKER_IDS[i],
			"pos": slot + Vector2(0, 14),
			"target": PLAZA + Vector2(randf_range(-30, 30), randf_range(-20, 20)),
			"speed": randf_range(WALKER_SPEED_MIN, WALKER_SPEED_MAX),
			"at_plaza": false,
		})

func _process(delta: float) -> void:
	_elapsed += delta
	for w in _walkers:
		var pos: Vector2 = w["pos"]
		var target: Vector2 = w["target"]
		var d := target - pos
		if d.length() < 6.0:
			# 到站：广场 ↔ 随机建筑门口 交替（贴着 L 路网观感即可，直线巡游）。
			if bool(w["at_plaza"]):
				var b: String = SLOTS.keys()[randi() % SLOTS.size()]
				w["target"] = (SLOTS[b]["pos"] as Vector2) + Vector2(randf_range(-24, 24), randf_range(6, 22))
				w["at_plaza"] = false
			else:
				w["target"] = PLAZA + Vector2(randf_range(-40, 40), randf_range(-24, 24))
				w["at_plaza"] = true
			continue
		w["pos"] = pos + d.normalized() * float(w["speed"]) * delta
	queue_redraw()

# ---------- 绘制（地形 → 路 → 空地 → 建筑+小人 Y-sort → 顶饰）----------
func _draw() -> void:
	_draw_terrain()
	var kd = GameStateScript.kingdom()
	var items: Array = []   # [ground_y, seq, kind, payload]
	for b in SLOTS:
		items.append([(SLOTS[b]["pos"] as Vector2).y, items.size(), "b", b])
	for w in _walkers:
		items.append([(w["pos"] as Vector2).y + WALKER_BOX * 0.4, items.size(), "w", w])
	for t in TREE_DECO:
		items.append([(t[1] as Vector2).y, items.size(), "t", t])
	items.sort_custom(func(p, q): return p[0] < q[0] if p[0] != q[0] else p[1] < q[1])
	for it in items:
		if it[2] == "b":
			_draw_building(String(it[3]), kd)
		elif it[2] == "t":
			_draw_tree(it[3])
		else:
			_draw_walker(it[3])
	for b in SLOTS:
		_draw_building_overlay(String(b), kd)

func _draw_terrain() -> void:
	for ty in range(0, int(1280 / CELL) + 1):
		for tx in range(0, int(720 / CELL) + 1):
			var cell: Vector2i = GROUND_TILES[(tx * 7 + ty * 13) % GROUND_TILES.size()]
			_blit(TEX_FLOOR, cell, Rect2(tx * CELL, ty * CELL, CELL + 1, CELL + 1))
	for c in _path_cells:
		var cell: Vector2i = PATH_TILES[(c.x + c.y) % PATH_TILES.size()]
		_blit(TEX_PATH, cell, Rect2(c.x * CELL, c.y * CELL, CELL + 1, CELL + 1))

func _blit(tex: Texture2D, cell: Vector2i, rect: Rect2) -> void:
	draw_texture_rect_region(tex, rect,
			Rect2(cell.x * TILE_PX, cell.y * TILE_PX, TILE_PX, TILE_PX))

func _draw_tree(t: Array) -> void:
	var tex: Texture2D = TREE_TEX[int(t[0])]
	var w: float = float(t[2])
	var h: float = w * float(tex.get_height()) / float(tex.get_width())
	var pos: Vector2 = t[1]
	draw_texture_rect(tex, Rect2(pos.x - w * 0.5, pos.y - h, w, h), false)

func _slot_rect(building: String) -> Rect2:
	var tex: Texture2D = BUILDING_TEX[building]
	var w: float = SLOTS[building]["w"]
	var h: float = w * float(tex.get_height()) / float(tex.get_width())
	var pos: Vector2 = SLOTS[building]["pos"]
	return Rect2(pos.x - w * 0.5, pos.y - h, w, h)

func _draw_building(building: String, kd) -> void:
	var rect := _slot_rect(building)
	var lv := _level_of(building, kd)
	if lv <= 0:
		# 空地：虚线地皮 + 提示（点击建造）。
		var plot := Rect2(rect.position.x + rect.size.x * 0.12, rect.end.y - rect.size.x * 0.42,
				rect.size.x * 0.76, rect.size.x * 0.4)
		draw_rect(plot, Color(0.24, 0.19, 0.12, 0.55))
		draw_rect(plot, Color(0.55, 0.45, 0.25, 0.9), false, 2.0)
		return
	var mod := Color.WHITE
	if kd != null and kd.is_loaded and int(kd.remaining_s(building)) > 0:
		mod = Color(1, 1, 1, 0.55)   # 施工中半透明（脚手架感）
	draw_texture_rect(BUILDING_TEX[building], rect, false, mod)

# 顶饰（恒在建筑/小人之上）：名牌+等级 / 施工倒计时 / 待收取气泡 / 空地提示。
func _draw_building_overlay(building: String, kd) -> void:
	var rect := _slot_rect(building)
	var pos: Vector2 = SLOTS[building]["pos"]
	var lv := _level_of(building, kd)
	var bcfg: Dictionary = (GameStateScript.config().kingdom.get("buildings", {}) as Dictionary).get(building, {})
	var label: String = str(bcfg.get("display_zh", building)) + ((" Lv%d" % lv) if lv > 0 else "")
	var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
	draw_rect(Rect2(pos.x - lw * 0.5 - 6, pos.y + 2, lw + 12, 22), Color(0.06, 0.05, 0.09, 0.72))
	draw_string(_font, Vector2(pos.x - lw * 0.5, pos.y + 19), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PixelUI.COL_PARCHMENT if lv > 0 else PixelUI.COL_HINT)
	if lv <= 0:
		draw_string(_font, Vector2(pos.x - 32, rect.end.y - 14), "空地",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.85, 0.6, 0.9))
		return
	if kd == null or not kd.is_loaded:
		return
	var remain := int(kd.remaining_s(building))
	if remain > 0:
		var txt := "施工 %s" % _fmt_dur(remain)
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
		draw_rect(Rect2(pos.x - tw * 0.5 - 6, rect.position.y - 26, tw + 12, 24), Color(0.06, 0.05, 0.09, 0.8))
		draw_string(_font, Vector2(pos.x - tw * 0.5, rect.position.y - 8), txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, PixelUI.COL_GOLD)
	elif _has_pending(building, kd):
		# 待收取气泡（SLG 式）：建筑头顶金色圆点脉动。
		var c := Vector2(pos.x, rect.position.y - 18)
		var pulse := 0.85 + 0.15 * sin(_elapsed * 5.0)
		draw_circle(c, 13.0 * pulse, Color(0.06, 0.05, 0.09, 0.85))
		draw_circle(c, 10.0 * pulse, PixelUI.COL_GOLD)
		draw_string(_font, c + Vector2(-5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.25, 0.16, 0.03))

func _draw_walker(w: Dictionary) -> void:
	var pos: Vector2 = w["pos"]
	var dir: Vector2 = (w["target"] as Vector2) - pos
	# 行向定帧行：向上走用背面行（owner0），向下用正面行（owner1）；横移镜像。
	var owner := 0 if dir.y < 0.0 else 1
	var spr: Dictionary = SpriteDB.frame(String(w["uid"]), "walk", owner, _elapsed)
	if spr.is_empty():
		draw_circle(pos, 10.0, Color(0.9, 0.9, 0.9, 0.8))
		return
	var box: float = WALKER_BOX * float(spr["scale"])
	if spr.get("shadow", false):
		var sw := box * 0.8
		var srect := Rect2(pos + Vector2(-sw * 0.5, box * 0.34), Vector2(sw, sw * 0.4))
		draw_texture_rect(TEX_UNIT_SHADOW, srect, false)
		draw_texture_rect(TEX_UNIT_SHADOW, srect, false)
	var mirror: bool = bool(spr.get("mirror", false)) and dir.x > 0.0
	draw_set_transform(pos, 0.0, Vector2(-1.0 if mirror else 1.0, 1.0))
	draw_texture_rect_region(spr["tex"], Rect2(-Vector2(box, box) * 0.5, Vector2(box, box)),
			spr["src"], spr.get("tint", Color.WHITE) if not spr.get("natural", false) else Color.WHITE)
	draw_set_transform(Vector2.ZERO)

# ---------- 点击：命中建筑 → 弹操作窗 ----------
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var kd = GameStateScript.kingdom()
	if kd == null or not kd.is_loaded:
		return
	var p: Vector2 = (event as InputEventMouseButton).position
	var best := ""
	var best_y := -INF
	for b in SLOTS:
		var rect := _slot_rect(b)
		rect.position.y -= 8.0   # 顶部留点余量（名牌/气泡也算命中）
		rect.size.y += 34.0
		if rect.has_point(p) and (SLOTS[b]["pos"] as Vector2).y > best_y:
			best = b
			best_y = (SLOTS[b]["pos"] as Vector2).y
	if best == "":
		return
	AudioManager.play_sfx("ui_button_press")
	var m := BuildingModal.new()
	m.building = best
	UI.modal(m)

# ---------- HUD（Control 子节点，恒浮场景之上）----------
func _build_hud() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(720, 118)
	bar.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color(0.07, 0.06, 0.10, 0.86), 3, Color("2b1e12")))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_pin_label("王国领地", Vector2(28, 12), 26, PixelUI.COL_GOLD)
	_res_lbl = _pin_label("粮草 — · 木石 —", Vector2(28, 52), 20, PixelUI.COL_PARCHMENT)
	_def_lbl = _pin_label("城防：塔 HP +0% · 塔攻 +0%", Vector2(28, 84), 16, PixelUI.COL_HINT)
	_wallet_holder = Control.new()
	_wallet_holder.position = Vector2(430, 12)
	_wallet_holder.size = Vector2(270, 40)
	_wallet_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wallet_holder)
	_collect_btn = Button.new()
	_collect_btn.position = Vector2(474, 58)
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
	back.position = Vector2(20, 1204)
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
