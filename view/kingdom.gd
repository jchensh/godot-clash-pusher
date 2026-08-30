# Kingdom —— 王国主城（0726 正式城建场景：testAssets/城建0726 整图 BG + 16 建筑落位）。
#
# 场景 = 整图 BG（1440×1830 城内俯视，含围墙/路网/南门开口）+ 槽位表（BG 像素坐标系，
# 布局按美术「角色大小示意」参考图落位）。横竖屏共用一套槽位，只差视野变换：
# 竖屏 = 高铺满左右拖动 / 横屏 = 宽铺满上下拖动（_k2s 单点收敛，_pan 钳制在图内）。
# 纯 _draw 即时渲染（建筑/小人 Y-sort 伪深度），HUD 用 Control 子节点浮在上层；
# 点建筑 → UI.modal(KingdomBuildingModal)；placeholder 建筑（config kind）建成后点击=敬请期待。
# 决策 48 + 永久原则：服务器权威——本页只收发数据 + 表现；倒计时用服务器时间基准插值。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const HudWidgets := preload("res://view/ui/hud_widgets.gd")
const GameStateScript := preload("res://view/game_state.gd")
const SpriteDB := preload("res://view/sprite_db.gd")
const BuildingModal := preload("res://view/ui/kingdom_building_modal.gd")

# —— 场景整图（0726 城建正式素材）——
const TEX_PLOT := preload("res://assets/kingdom/kingdom_plot.png")   # 「未建造」空地占位图（过渡沿用，KAN-124 欠卡通版）
const TEX_UNIT_SHADOW := preload("res://assets/units/unit_shadow.png")
const BG_SIZE := Vector2(1440.0, 1830.0)   # 场景坐标系尺寸（沿用 0726 口径；示意图同尺寸）

# —— 决策 49 P3（0830 城建批次）：BG 整图下线 → 拼接式场景（地表错位平铺+围墙+路+装饰，
# 对齐美术《城建资源说明》「均由独立物件拼接」）；建筑贴图全换卡通件、布局按示意图落位。——
const TEX_GROUND := preload("res://assets/kingdom_cartoon/ground.png")   # 2×4 色块 tile，非四方连续
const TEX_ROAD := preload("res://assets/kingdom_cartoon/road.png")
const TEX_WALL_H := preload("res://assets/kingdom_cartoon/wall_a.png")   # 横墙段 167×107
const TEX_WALL_V := preload("res://assets/kingdom_cartoon/wall_b.png")   # 竖墙段 74×107
const TEX_WALL_POST := preload("res://assets/kingdom_cartoon/wall_d.png")  # 绿旗角柱 99×160
const DECO_TEX := {
	"tree1": preload("res://assets/kingdom_cartoon/tree1.png"),
	"tree2": preload("res://assets/kingdom_cartoon/tree2.png"),
	"tree3": preload("res://assets/kingdom_cartoon/tree3.png"),
	"flower1": preload("res://assets/kingdom_cartoon/flower1.png"),
	"flower2": preload("res://assets/kingdom_cartoon/flower2.png"),
	"bamboo": preload("res://assets/kingdom_cartoon/bamboo.png"),
	"barrel": preload("res://assets/kingdom_cartoon/barrel_wood.png"),
	"pumpkin": preload("res://assets/kingdom_cartoon/resident.png"),   # 南瓜居民屋=大型装饰（无槽位）
}
const BUILDING_TEX := {
	"keep": preload("res://assets/kingdom_cartoon/keep.png"),
	"farm": preload("res://assets/kingdom_cartoon/farm.png"),
	"workshop": preload("res://assets/kingdom_cartoon/magic_lab.png"),      # 顶替：紫蘑菇魔法工坊（产木料语义）
	"watchtower": preload("res://assets/towers/cartoon_tower_arrow.png"),   # 顶替：战斗箭塔复用（风格统一）
	"granary": preload("res://assets/kingdom_cartoon/granary.png"),
	"mint": preload("res://assets/kingdom_cartoon/mint.png"),               # 顶替：药剂工坊（卖药剂产金币）
	"wall": preload("res://assets/kingdom_cartoon/gate.png"),               # wall 槽=城门（沿 0726 先例）
	"quarry": preload("res://assets/kingdom_cartoon/quarry.png"),
	"stoneworks": preload("res://assets/kingdom_cartoon/stoneworks.png"),   # 顶替：科研所（天文台）
	"ironworks": preload("res://assets/kingdom_cartoon/ironworks.png"),
	"ranch": preload("res://assets/kingdom_cartoon/ranch.png"),
	"shop": preload("res://assets/kingdom_cartoon/shop.png"),
	"camp_infantry": preload("res://assets/kingdom_cartoon/camp_infantry.png"),  # 顶替：魔法书院（法师营）
	"camp_spear": preload("res://assets/kingdom_cartoon/camp_spear.png"),
	"camp_crossbow": preload("res://assets/kingdom_cartoon/camp_crossbow.png"),
	"camp_cavalry": preload("res://assets/kingdom_cartoon/camp_cavalry.png"),
}
# 槽位（BG 像素系，pos=建筑底边中心；按美术示意图落位）。w 缺省 = 贴图原生宽
# （0726 素材与示意图同比例）；watchtower 老素材过大需显式压宽。
const SLOTS := {   # 0830 卡通示意图落位（pos=建筑底边中心，BG 像素系；真人验收可调）
	"keep": {"pos": Vector2(705, 660)},
	"farm": {"pos": Vector2(1115, 455)},
	"workshop": {"pos": Vector2(280, 650)},
	"granary": {"pos": Vector2(828, 1000)},
	"mint": {"pos": Vector2(1130, 1215)},
	"wall": {"pos": Vector2(710, 1552)},   # 城门骑底墙中央（墙带中心 y≈1500）
	"watchtower": {"pos": Vector2(150, 1420), "w": 82.0},
	"quarry": {"pos": Vector2(370, 455)},
	"stoneworks": {"pos": Vector2(480, 790)},
	"ironworks": {"pos": Vector2(1140, 790)},
	"ranch": {"pos": Vector2(950, 610)},
	"shop": {"pos": Vector2(570, 1010)},
	"camp_infantry": {"pos": Vector2(287, 940)},
	"camp_spear": {"pos": Vector2(287, 1190)},
	"camp_crossbow": {"pos": Vector2(560, 1230)},
	"camp_cavalry": {"pos": Vector2(872, 1215)},
}
# 箭塔四角：主槽=左下（贴墙内侧）；其余三角视觉复刻（建成才画）；右下角与主槽同为交互入口。
const WT_CLICK_EXTRA := Vector2(1290, 1420)
const WT_VISUAL_EXTRA := [Vector2(1290, 1420), Vector2(150, 330), Vector2(1290, 330)]
# —— 拼接场景布局（BG 像素系）——
const WALL_TOP_Y := 230.0      # 顶墙中线
const WALL_BOT_Y := 1500.0     # 底墙中线
const WALL_LEFT_X := 90.0      # 左墙中线
const WALL_RIGHT_X := 1350.0   # 右墙中线
const GATE_GAP := 220.0        # 底墙城门开口宽（城门贴图骑缝）
# 路网段（BG 系矩形，按示意图复刻主干；真人验收可调）
const ROAD_SEGS := [
	Rect2(678, 880, 64, 660),     # 主干：城门→中横
	Rect2(340, 830, 720, 64),     # 中横：采石场支→炼铁厂支
	Rect2(348, 450, 64, 380),     # 左上支：采石场→中横
	Rect2(678, 650, 64, 230),     # keep 支：城堡门→中横
	Rect2(1083, 440, 64, 454),    # 右支：农田→炼铁厂→中横
	Rect2(248, 700, 64, 530),     # 左支：魔法工坊→魔法书院→枪兵营
	Rect2(312, 1166, 366, 64),    # 左下横：枪兵营→弩兵营→主干
	Rect2(742, 1166, 420, 64),    # 右下横：主干→骑兵营→药剂工坊
	Rect2(880, 590, 64, 240),     # 牧场支：牧场→中横
]
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
var _land := false
# —— 视野（_k2s 单点收敛；横竖同缩放，竖屏双向拖动）——
var _scale := 1.0
var _pan := Vector2.ZERO
var _pan_max := Vector2.ZERO
var _press := Vector2.ZERO
var _press_pan := Vector2.ZERO
var _pressing := false
var _dragged := false

# —— 巡游小人（占位=战斗单位走路帧；数量/速度纯表现，与逻辑无关）——
const WALKER_IDS := ["squire_body", "goblin_body", "archer_body", "barbarian_body", "knight_body"]
const WALKER_BOX := 46.0
const WALKER_SPEED_MIN := 34.0
const WALKER_SPEED_MAX := 58.0

var _font: Font
var _http: HTTPRequest
var _elapsed := 0.0
var _walkers: Array = []       # [{uid, pos(BG系), target(BG系), speed}]
# —— HUD ——
var _res_lbl: Label
var _wallet_holder: Control
var _def_lbl: Label
var _collect_btn: Button

func _ready() -> void:
	_land = GameStateScript.ui_layout() == "landscape"
	AudioManager.play_music("music_main_menu")
	_font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
	_init_view()
	_spawn_walkers()
	_build_hud()
	Events.kingdom_changed.connect(_on_kingdom_changed)
	Events.economy_changed.connect(_on_economy_changed)
	_http = HTTPRequest.new()
	add_child(_http)
	set_process(true)
	await _bootstrap()

# ---------- 视野/小人（纯表现）----------
func _init_view() -> void:
	var vs := Vector2(1280, 720) if _land else Vector2(720, 1280)
	_scale = 1280.0 / BG_SIZE.x   # 横竖同缩放（0726 验收：竖屏拉近对齐横屏观感，双向拖动）
	_pan_max = (BG_SIZE * _scale - vs).max(Vector2.ZERO)
	var keep_pos: Vector2 = SLOTS["keep"]["pos"]   # 初始视野对准主公府一带
	_set_pan(Vector2(keep_pos.x * _scale - vs.x * 0.5, keep_pos.y * _scale - vs.y * 0.45))

func _set_pan(p: Vector2) -> void:
	_pan = p.clamp(Vector2.ZERO, _pan_max)
	queue_redraw()

func _k2s(p: Vector2) -> Vector2:   # BG 像素系 → 屏幕
	return p * _scale - _pan

func _rand_slot_pos() -> Vector2:
	var b: String = SLOTS.keys()[randi() % SLOTS.size()]
	return (SLOTS[b]["pos"] as Vector2) + Vector2(randf_range(-30, 30), randf_range(8, 26))

func _spawn_walkers() -> void:
	for i in WALKER_IDS.size():
		_walkers.append({
			"uid": WALKER_IDS[i],
			"pos": _rand_slot_pos(),
			"target": _rand_slot_pos(),
			"speed": randf_range(WALKER_SPEED_MIN, WALKER_SPEED_MAX),
		})

func _process(delta: float) -> void:
	_elapsed += delta
	for w in _walkers:
		var pos: Vector2 = w["pos"]
		var d: Vector2 = (w["target"] as Vector2) - pos
		if d.length() < 8.0:
			w["target"] = _rand_slot_pos()   # 到站：换个建筑门口继续逛（BG 自带路网，直线巡游观感即可）
			continue
		w["pos"] = pos + d.normalized() * float(w["speed"]) * delta
	queue_redraw()

# ---------- 绘制（地形 → 路 → 空地 → 建筑+小人 Y-sort → 顶饰）----------
# —— 决策 49 拼接式场景（P3/KAN-123）：地表错位平铺 → 路网 → 围墙 → 装饰。
# 全部经 _k2s 变换（视野拖动/缩放自动跟随）；建筑/小人仍走原 Y-sort 通道画在其上。
func _draw_tiled_scene() -> void:
	_draw_ground_tiles()
	for seg in ROAD_SEGS:
		_draw_road_seg(seg as Rect2)
	_draw_walls()
	for it in DECO_ITEMS:
		var tex: Texture2D = DECO_TEX[it[0]]
		var p: Vector2 = it[1]
		var sz := Vector2(tex.get_width(), tex.get_height())
		draw_texture_rect(tex,
				Rect2(_k2s(Vector2(p.x - sz.x * 0.5, p.y - sz.y)), sz * _scale), false)

func _draw_ground_tiles() -> void:
	# 地表 tile 256×512：非四方连续 → 奇数列上移半块（美术《城建资源说明》「错位一格再复制」）。
	var tw := 256.0
	var th := 512.0
	var col := 0
	var x := 0.0
	while x < BG_SIZE.x:
		var y := (-th * 0.5) if col % 2 == 1 else 0.0
		while y < BG_SIZE.y:
			draw_texture_rect_region(TEX_GROUND,
					Rect2(_k2s(Vector2(x, y)), Vector2(tw, th) * _scale), Rect2(0, 0, tw, th))
			y += th
		x += tw
		col += 1

func _draw_road_seg(r: Rect2) -> void:
	# 路素材 99×420 竖条：竖段直接沿 y 平铺；横段绕段中心转 90° 后按竖段铺。
	if r.size.y >= r.size.x:
		_road_strip(r.position, r.size.x, r.size.y, Vector2.ZERO, 0.0)
	else:
		var c := _k2s(r.get_center())
		draw_set_transform(c, PI / 2.0, Vector2.ONE)
		_road_strip(Vector2(-r.size.y * 0.5, -r.size.x * 0.5), r.size.y, r.size.x, c, -1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _road_strip(origin: Vector2, w: float, length: float, local_off: Vector2, local_mode: float) -> void:
	# local_mode<0 = 已处于旋转局部系（origin 为局部坐标，仅乘缩放）；否则 BG 系经 _k2s。
	var block: float = w * (420.0 / 99.0)
	var y := 0.0
	while y < length:
		var h: float = minf(block, length - y)
		var src := Rect2(0, 0, 99, 420.0 * h / block)
		var dst_pos: Vector2
		if local_mode < 0.0:
			dst_pos = local_off + (origin + Vector2(0, y)) * _scale
		else:
			dst_pos = _k2s(origin + Vector2(0, y))
		draw_texture_rect_region(TEX_ROAD, Rect2(dst_pos, Vector2(w, h) * _scale), src)
		y += h

func _draw_walls() -> void:
	var hw := Vector2(167.0, 107.0)   # 横墙段
	var vw := Vector2(74.0, 107.0)    # 竖墙段
	var post := Vector2(99.0, 160.0)  # 绿旗角柱
	var gate_l: float = 710.0 - GATE_GAP * 0.5
	var gate_r: float = 710.0 + GATE_GAP * 0.5
	var x := WALL_LEFT_X
	while x < WALL_RIGHT_X:
		var seg_w: float = minf(hw.x, WALL_RIGHT_X - x)
		var src := Rect2(0, 0, hw.x * seg_w / hw.x, hw.y)
		draw_texture_rect_region(TEX_WALL_H,
				Rect2(_k2s(Vector2(x, WALL_TOP_Y - hw.y * 0.5)), Vector2(seg_w, hw.y) * _scale), src)
		if x + seg_w <= gate_l or x >= gate_r:   # 底墙城门开口跳过（粗粒度按整段）
			draw_texture_rect_region(TEX_WALL_H,
					Rect2(_k2s(Vector2(x, WALL_BOT_Y - hw.y * 0.5)), Vector2(seg_w, hw.y) * _scale), src)
		x += hw.x
	for wx in [WALL_LEFT_X, WALL_RIGHT_X]:
		var y := WALL_TOP_Y
		while y < WALL_BOT_Y:
			var seg_h: float = minf(vw.y, WALL_BOT_Y - y)
			draw_texture_rect_region(TEX_WALL_V,
					Rect2(_k2s(Vector2(wx - vw.x * 0.5, y)), Vector2(vw.x, seg_h) * _scale),
					Rect2(0, 0, vw.x, seg_h))
			y += vw.y
	for corner in [Vector2(WALL_LEFT_X, WALL_TOP_Y), Vector2(WALL_RIGHT_X, WALL_TOP_Y),
			Vector2(WALL_LEFT_X, WALL_BOT_Y), Vector2(WALL_RIGHT_X, WALL_BOT_Y)]:
		draw_texture_rect(TEX_WALL_POST,
				Rect2(_k2s(corner - Vector2(post.x * 0.5, post.y * 0.62)), post * _scale), false)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 1280)), Color("100c18"))   # 图外露夜色底
	_draw_tiled_scene()
	var kd = GameStateScript.kingdom()
	var items: Array = []   # [screen_ground_y, seq, kind, payload]
	for b in SLOTS:
		items.append([_k2s(SLOTS[b]["pos"] as Vector2).y, items.size(), "b", b])
	if _level_of("watchtower", kd) >= 1:   # 箭塔其余三角视觉复刻（建成才现身）
		for wp in WT_VISUAL_EXTRA:
			items.append([_k2s(wp as Vector2).y, items.size(), "wt", wp])
	for w in _walkers:
		items.append([_k2s(w["pos"] as Vector2).y + WALKER_BOX * 0.4, items.size(), "w", w])
	items.sort_custom(func(p, q): return p[0] < q[0] if p[0] != q[0] else p[1] < q[1])
	for it in items:
		if it[2] == "b":
			_draw_building(String(it[3]), kd)
		elif it[2] == "wt":
			_draw_watchtower_at(it[3] as Vector2, kd)
		else:
			_draw_walker(it[3])
	for b in SLOTS:
		_draw_building_overlay(String(b), kd)

func _slot_rect(building: String) -> Rect2:   # 屏幕系（BG 槽位经 _k2s 变换）
	var tex: Texture2D = BUILDING_TEX[building]
	var w: float = float((SLOTS[building] as Dictionary).get("w", tex.get_width()))
	var h: float = w * float(tex.get_height()) / float(tex.get_width())
	var pos: Vector2 = SLOTS[building]["pos"]
	return Rect2(_k2s(Vector2(pos.x - w * 0.5, pos.y - h)), Vector2(w, h) * _scale)

# 箭塔视觉复刻（角落副本；施工半透明跟随主建筑状态）。
func _draw_watchtower_at(pos: Vector2, kd) -> void:
	var tex: Texture2D = BUILDING_TEX["watchtower"]
	var w := 80.0
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var mod := Color.WHITE
	if kd != null and kd.is_loaded and int(kd.remaining_s("watchtower")) > 0:
		mod = Color(1, 1, 1, 0.55)
	draw_texture_rect(tex,
			Rect2(_k2s(Vector2(pos.x - w * 0.5, pos.y - h)), Vector2(w, h) * _scale), false, mod)

func _draw_building(building: String, kd) -> void:
	var rect := _slot_rect(building)
	var lv := _level_of(building, kd)
	if lv <= 0:
		# 空地：0726「未建造」占位图（点击建造）。
		var pos: Vector2 = SLOTS[building]["pos"]
		var pw := float(TEX_PLOT.get_width())
		var ph := float(TEX_PLOT.get_height())
		draw_texture_rect(TEX_PLOT,
				Rect2(_k2s(Vector2(pos.x - pw * 0.5, pos.y - ph)), Vector2(pw, ph) * _scale), false)
		return
	var mod := Color.WHITE
	if kd != null and kd.is_loaded and int(kd.remaining_s(building)) > 0:
		mod = Color(1, 1, 1, 0.55)   # 施工中半透明（脚手架感）
	draw_texture_rect(BUILDING_TEX[building], rect, false, mod)

# 顶饰（恒在建筑/小人之上）：名牌+等级 / 施工倒计时 / 待收取气泡 / 空地提示。
func _draw_building_overlay(building: String, kd) -> void:
	var rect := _slot_rect(building)
	var pos: Vector2 = _k2s(SLOTS[building]["pos"] as Vector2)   # 屏幕系锚点
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
	var pos: Vector2 = _k2s(w["pos"] as Vector2)
	var dir: Vector2 = (w["target"] as Vector2) - (w["pos"] as Vector2)
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

# ---------- 输入：按住拖动看全城；轻点命中建筑 → 弹操作窗 / placeholder 敬请期待 ----------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var e := event as InputEventMouseButton
		if e.pressed:
			_pressing = true
			_dragged = false
			_press = e.position
			_press_pan = _pan
		else:
			_pressing = false
			if not _dragged:
				_click(e.position)
	elif event is InputEventMouseMotion and _pressing:
		var d: Vector2 = (event as InputEventMouseMotion).position - _press
		if _dragged or d.length() > 12.0:   # 阈值内=点选；超出=拖动平移（不再触发点选）
			_dragged = true
			_set_pan(_press_pan - d)

func _click(p: Vector2) -> void:
	var kd = GameStateScript.kingdom()
	if kd == null or not kd.is_loaded:
		return
	var best := ""
	var best_y := -INF
	for b in SLOTS:
		var rect := _slot_rect(b)
		rect.position.y -= 8.0   # 顶部留点余量（名牌/气泡也算命中）
		rect.size.y += 34.0
		var sy: float = _k2s(SLOTS[b]["pos"] as Vector2).y
		if rect.has_point(p) and sy > best_y:
			best = b
			best_y = sy
	if best == "":
		# 右下角箭塔副本 = 第二交互入口（0726：下方两塔都作为入口）
		var tex: Texture2D = BUILDING_TEX["watchtower"]
		var wt_h := 80.0 * float(tex.get_height()) / float(tex.get_width())
		var wt_rect := Rect2(_k2s(WT_CLICK_EXTRA - Vector2(40.0, wt_h)),
				Vector2(80.0, wt_h) * _scale)
		wt_rect.position.y -= 8.0
		wt_rect.size.y += 34.0
		if wt_rect.has_point(p):
			best = "watchtower"
		else:
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
	bar.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color(0.07, 0.06, 0.10, 0.86), 3, Color("2b1e12")))
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
