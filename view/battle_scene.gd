# BattleScene —— 显示层（V3 2D；V3-6a 起加交互手感）。
#
# 只读 Match/Arena 的逻辑状态作画；出牌一律经 player.try_play_card（玩家/AI 对称）。
# 抽象 tile 空间 → 屏幕像素的映射只活在本层（_t2s/_s2t）。
# y=0 敌方底线(屏上)、y=grid_h 玩家底线(屏下)；河横贯中部、左右双桥。
# 出牌 = 拖拽部署（CR 式，决策 41）：按手牌→拖到场上(落点抬到手指上方)→松手落子；
#   拖拽中画落点 ghost(兵剪影/AOE 圈/直伤准星)+合法绿/非法红 + 己方半场高亮；成功落子有涟漪、新兵入场缩放。
# V3-6b 加战斗 juice：移动插值(10Hz→60fps)/受击闪白+浮动伤害数字/命中顿帧/震屏/命中火花（全显示层派生）。
# V3-6c 加 HUD 反馈：分段圣水条+满槽脉动、卡面自绘(费用/不可用扫光/选中)+下一张预览、王冠/倒计时强调。
# 仍为白膜：精灵/粒子皮在 V3-7 接续。
extends Node2D

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const BattleScript = preload("res://logic/battle.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const GameStateScript = preload("res://view/game_state.gd")
const RunModifiersScript = preload("res://logic/run_modifiers.gd")
const SpriteDB = preload("res://view/sprite_db.gd")
const RunSceneScene := "res://view/run_scene.tscn"

const TOPBAR_H := 54.0
const HUD_BOTTOM_H := 176.0

const COL_BG := Color(0.10, 0.12, 0.11)
const COL_GROUND := Color(0.22, 0.40, 0.24)
const COL_GROUND_ENEMY := Color(0.34, 0.26, 0.26)   # 敌方半场地面微调（辨上下）
const COL_WATER := Color(0.16, 0.34, 0.55)
const COL_BRIDGE := Color(0.55, 0.42, 0.24)
const COL_PLAYER := Color(0.35, 0.60, 1.0)
const COL_OPPONENT := Color(1.0, 0.42, 0.38)
const COL_ELIXIR := Color(0.80, 0.33, 0.96)
const COL_PANEL := Color(0.05, 0.07, 0.06, 0.88)
const COL_OK := Color(0.45, 1.0, 0.55)        # 落点合法（ghost/高亮）
const COL_BAD := Color(1.0, 0.42, 0.40)       # 落点非法

const DROP_LIFT_TILES := 1.6                   # 落点抬到手指上方（拇指不遮挡，CR 式）
const POP_DUR := 0.22                          # 新单位入场缩放时长（秒）
const POOF_DUR := 0.40                         # 落地涟漪时长（秒）

# —— V3-6b 战斗 juice ——
const SMOOTH_K := 18.0                          # 位置插值平滑系数（越大越贴近逻辑位）
const FLASH_DUR := 0.12                         # 受击闪白时长
const DMGNUM_DUR := 0.75                        # 伤害数字停留时长
const DMGNUM_RISE := 34.0                       # 伤害数字上浮像素
const SPARK_DUR := 0.18                         # 命中火花时长
const SHAKE_DECAY := 42.0                       # 震屏衰减（像素/秒）
const SHAKE_MAX := 14.0                         # 震屏幅度上限
const SHAKE_HIT := 3.0                          # 中等命中震屏
const SHAKE_BIG := 6.0                          # 大伤害震屏
const SHAKE_TOWER := 12.0                       # 塔被摧毁震屏
const SHAKE_HIT_DMG := 80.0                     # 触发小震屏的单次伤害阈值
const HITSTOP_DMG := 200.0                      # 触发顿帧的单次伤害阈值
const HITSTOP_DUR := 0.06                       # 顿帧（冻结 sim）时长

# —— V3-6c HUD 反馈 ——
const COL_CARD_BG := Color(0.12, 0.13, 0.18, 0.95)
const COL_CARD_SEL := Color(0.22, 0.19, 0.10, 0.97)
const COL_CROWN := Color(1.0, 0.85, 0.32)

# —— V3-6d 胜负演出 ——
const END_BTN_DELAY := 0.85                     # 结算按钮淡入延迟（先放胜负演出）

# —— V3-7 精灵贴图（架构 A：immediate _draw + draw_texture；逻辑零改）——
# 单位精灵走 SpriteDB(manifest，含帧网格/走攻行/朝向)；塔/落地 FX 仍在此 preload（塔皮 7b-2、FX 7b-3 再细化）。
const TEX_TOWER_KING := preload("res://assets/towers/building1.png")       # 王塔 = 大城堡（4×4）
const TEX_TOWER_PRINCESS := preload("res://assets/towers/building6.png")   # 公主塔 = 单体小堡（3×3）
const TEX_EXPLOSION := preload("res://assets/fx/Fire_Explosion_28x28.png")
const EXPLOSION_FPX := 28
const EXPLOSION_N := 12
const TEX_LIGHTNING := preload("res://assets/fx/Lightning_Energy_48x48.png")   # 闪电术命中（扩散电能环）
const TEX_RED_ENERGY := preload("res://assets/fx/Red_Energy_48x48.png")        # 电火花命中（红电环）
const FX_SEQ_FPX := 48        # Lightning/Red_Energy 帧尺寸
const FX_SEQ_N := 9
# 卡 id → 命中 FX 类型；未列出（含 spawn 兵牌）= 中性落地尘土。
const FX_KIND := {
	"fireball": "fireball", "lightning": "lightning", "zap": "zap",
	"arrows": "arrows", "log": "log", "heal": "heal",
}
# —— 远程投射物（路线 A：view 侧检测攻击冷却上升沿=开火）——
const TEX_PROJ_FIREBALL := preload("res://assets/units/fire_skull_fireball.png")
const PROJ_FB_FPX := 16
const PROJ_SPEED := 16.0       # 投射物飞行速度 tile/s
const PROJ_RANGED_MIN := 2.5   # attack_range ≥ 此值才出投射物（排除近战/短手）
const PROJ_KIND := {"archer_body": "arrow", "musketeer_body": "bolt", "baby_dragon_body": "fireball"}

# 兵种白膜外形（半径 tile，按队伍色填充；空军画环标记）。
const UNIT_VIS := {
	"giant_body":      {"r": 0.85},
	"knight_body":     {"r": 0.55},
	"mini_pekka_body": {"r": 0.6},
	"musketeer_body":  {"r": 0.5},
	"archer_body":     {"r": 0.45},
	"baby_dragon_body":{"r": 0.75},
	"minion_body":     {"r": 0.45},
	"goblin_body":     {"r": 0.4},
	"skeleton_body":   {"r": 0.38},
	"golem_body":      {"r": 0.85},
}

var match_obj
var loader
var _font: Font
var selected_card := -1
var _card_btns: Array = []
var _result_layer: Control
var _dragging := false
var _drag_screen := Vector2.ZERO
var _elapsed := 0.0
var _fx: Array = []           # 落地涟漪：[{pos:Vector2(tile), t0:float, dur:float}]
var _seen: Dictionary = {}    # 单位 instance_id → 首见 _elapsed（入场缩放）
var _card_base_pos: Array = []
# —— V3-6b 战斗 juice 状态 ——
var _disp: Dictionary = {}    # 单位 id → 显示插值位（tile）
var _uhp: Dictionary = {}     # 单位 id → 上帧 hp
var _thp: Dictionary = {}     # 塔 id → 上帧 hp
var _flash: Dictionary = {}   # id → 闪白结束 _elapsed（单位+塔混用）
var _dmgnums: Array = []      # [{pos:Vector2(tile), text, col, size, t0, dur}]
var _sparks: Array = []       # [{pos:Vector2(tile), t0, dur}]
var _projectiles: Array = [] # 远程投射物：[{from,to:Vector2(tile), t0, dur, kind}]
var _atkcd: Dictionary = {}  # 单位 id → 上帧 _attack_cooldown（检测开火上升沿）
var _shake := Vector2.ZERO
var _shake_mag := 0.0
var _hitstop_t := 0.0
# —— V3-6d 胜负演出状态 ——
var _ending := false
var _end_t := 0.0
var _end_result := 0
var _end_pscore := 0.0
var _end_oscore := 0.0
var _end_buttons_added := false

@onready var _vw: float = float(get_viewport_rect().size.x)
@onready var _vh: float = float(get_viewport_rect().size.y)

func _ready() -> void:
	_font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
	loader = ConfigLoaderScript.new()
	loader.load_all()
	match_obj = MatchScript.new(loader)
	var run = GameStateScript.run
	if run != null and not run.is_over():
		# Roguelite 模式：当前节点 level_id + run 卡组 + relic/节点难度修正器。
		var node: Dictionary = run.current_node()
		var mods: Array = RunModifiersScript.relic_mods(run.relics, loader.relics)
		var nm: Dictionary = RunModifiersScript.node_mod(loader.get_run("default"), String(node.get("type", "battle")))
		if not nm.is_empty():
			mods.append(nm)
		match_obj.setup(String(node.get("level_id")), run.deck, mods)
	else:
		match_obj.setup(GameStateScript.level_id, GameStateScript.player_deck)
	match_obj.set_opponent_controller(AIControllerScript.new(match_obj, loader))
	_build_cards()
	_build_result_panel()
	set_process(true)

func _process(delta: float) -> void:
	if match_obj == null:
		return
	_elapsed += delta
	if _hitstop_t > 0.0:
		_hitstop_t -= delta            # 顿帧：冻结 sim、画面继续
	elif not match_obj.is_over():
		match_obj.update(delta)
	_detect_events()                   # 逐帧 diff hp → 伤害数字/闪白/火花/顿帧/震屏（路线 A）
	_detect_attacks()                  # 远程兵开火上升沿 → 投射物（路线 A）
	_update_disp(delta)                # 10Hz→60fps 位置插值
	_update_shake(delta)
	if _dragging:
		_drag_screen = get_viewport().get_mouse_position()
	_cull_transients()
	_sync_cards()
	if match_obj.is_over() and not _ending:
		_start_ending()
	if _ending:
		_end_t += delta
		if _end_t >= END_BTN_DELAY and not _end_buttons_added:
			_add_result_buttons()
	queue_redraw()

# —— 坐标映射 ——
func _field_rect() -> Rect2:
	return Rect2(0.0, TOPBAR_H, _vw, _vh - TOPBAR_H - HUD_BOTTOM_H)

func _t2s(p: Vector2) -> Vector2:
	var a = match_obj.battle.arena
	var fr := _field_rect()
	return Vector2(fr.position.x + p.x / a.grid_w * fr.size.x,
				   fr.position.y + p.y / a.grid_h * fr.size.y) + _shake   # _shake 只动场内、HUD 不抖

func _s2t(s: Vector2) -> Vector2:
	var a = match_obj.battle.arena
	var fr := _field_rect()
	return Vector2((s.x - fr.position.x) / fr.size.x * a.grid_w,
				   (s.y - fr.position.y) / fr.size.y * a.grid_h)

func _tile_px() -> Vector2:
	var a = match_obj.battle.arena
	var fr := _field_rect()
	return Vector2(fr.size.x / a.grid_w, fr.size.y / a.grid_h)

# —— 绘制 ——
func _draw() -> void:
	if match_obj == null or match_obj.battle == null or match_obj.battle.arena == null:
		return
	var a = match_obj.battle.arena
	draw_rect(Rect2(0, 0, _vw, _vh), COL_BG)
	_draw_terrain(a)
	_draw_deploy_hint(a)
	_draw_towers()
	_draw_units(a)
	_draw_fx()
	_draw_projectiles()
	_draw_combat_fx()
	_draw_drag_ghost(a)
	_draw_topbar()
	draw_rect(Rect2(0, _vh - HUD_BOTTOM_H, _vw, HUD_BOTTOM_H), COL_PANEL)   # 底部 HUD 底板
	_draw_elixir()
	_draw_cards()
	_draw_end_screen()

func _draw_terrain(a) -> void:
	var tp := _tile_px()
	for ty in range(a.grid_h):
		for tx in range(a.grid_w):
			var t: int = a.tile_type(tx, ty)
			if t == a.TILE_TOWER:
				continue   # 塔单独画
			var col := COL_GROUND
			if t == a.TILE_WATER:
				col = COL_WATER
			elif ty >= a.river_y_min and ty < a.river_y_max:
				col = COL_BRIDGE      # 河行里的可走 = 桥
			elif ty < a.grid_h / 2:
				col = COL_GROUND_ENEMY
			var s := _t2s(Vector2(tx, ty))
			draw_rect(Rect2(s.x, s.y, tp.x + 1.0, tp.y + 1.0), col)
	# 己方半场可部署区描边提示
	var fr := _field_rect()
	var y0 := _t2s(Vector2(0, a.deploy_player_y_min)).y
	draw_rect(Rect2(fr.position.x, y0, fr.size.x, fr.position.y + fr.size.y - y0),
			Color(0.4, 0.8, 0.5, 0.10))

func _draw_towers() -> void:
	var tp := _tile_px()
	for side in [match_obj.battle.player_towers, match_obj.battle.opponent_towers]:
		for t in side:
			var base: Color = COL_PLAYER if t.owner_id == 0 else COL_OPPONENT
			var c := _t2s(t.pos)
			var king: bool = t.is_king()
			var fw_px: float = t.fw * tp.x
			var foot_bottom: float = c.y + t.fh * tp.y * 0.5     # footprint 底边 = 塔贴地处
			var tex: Texture2D = TEX_TOWER_KING if king else TEX_TOWER_PRINCESS
			var ts: Vector2 = tex.get_size()
			# 保持贴图原始长宽比（不再压扁填正方形）：以 footprint 宽为基准缩放，底部对齐贴地。
			# 王塔横宽(building1=1.5:1)、公主方正(building6=1:1)，王塔系数更大以保主次（否则公主反而更高）。
			var draw_w: float = fw_px * (1.35 if king else 1.05)
			var draw_h: float = draw_w * ts.y / ts.x
			var rx: float = c.x - draw_w * 0.5
			var ry: float = foot_bottom - draw_h
			if t.is_destroyed():                                  # 摧毁：压低 + 染暗成废墟堆
				var dh: float = draw_h * 0.42
				draw_texture_rect(tex, Rect2(rx, foot_bottom - dh, draw_w, dh), false, Color(0.30, 0.28, 0.26, 0.95))
				continue
			var fill: Color = Color.WHITE.lerp(base, 0.5)        # 温和队伍色（让城堡贴图透出）
			var fend: float = _flash.get(t.get_instance_id(), 0.0)
			if fend > _elapsed:
				fill = fill.lerp(Color.WHITE, ((fend - _elapsed) / FLASH_DUR) * 0.85)
			draw_texture_rect(tex, Rect2(rx, ry, draw_w, draw_h), false, fill)
			var ratio: float = clampf(t.hp / t.max_hp, 0.0, 1.0)
			var bw := draw_w * 0.8
			var by := ry - 7.0
			draw_rect(Rect2(c.x - bw * 0.5, by, bw, 5.0), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(c.x - bw * 0.5, by, bw * ratio, 5.0), _hp_color(ratio))
			if king:                                              # 王塔顶金王冠标记
				_draw_crown(Vector2(c.x, by - 13.0), 20.0, COL_CROWN, true)

func _draw_units(a) -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	var cur := {}
	for u in a.get_units():
		if not u.is_alive():
			continue
		var id: int = u.get_instance_id()
		cur[id] = true
		if not _seen.has(id):
			_seen[id] = _elapsed
		var base: Color = COL_PLAYER if u.owner_id == 0 else COL_OPPONENT
		var c := _t2s(_disp_pos(u))
		var vis: Dictionary = UNIT_VIS.get(u.unit_id, {"r": 0.5})
		var rad: float = float(vis["r"]) * ur * _pop_scale(id)
		var flying: bool = u.target_type == "air"
		if flying:
			draw_circle(c + Vector2(0, ur * 0.5), rad * 0.6, Color(0, 0, 0, 0.25))  # 地面影子
			c -= Vector2(0, ur * 0.7)                                                # 单位上浮
		var fill: Color = base
		var fend: float = _flash.get(id, 0.0)
		if fend > _elapsed:
			fill = base.lerp(Color.WHITE, ((fend - _elapsed) / FLASH_DUR) * 0.85)
		# 状态派生（路线 A）：有索敌目标且在攻击射程内 → attack，否则 walk。
		# 塔目标因占位较大，射程需加塔半径。
		var st := "walk"
		var ct = u.current_target
		if ct != null and is_instance_valid(ct):
			var reach: float = u.attack_range + 1.0
			if "fw" in ct:
				reach = u.attack_range + maxf(float(ct.fw), float(ct.fh)) * 0.5 + 0.5
			if u.pos.distance_to(ct.pos) <= reach:
				st = "attack"
		var spr: Dictionary = SpriteDB.frame(u.unit_id, st, u.owner_id, _elapsed)
		if not spr.is_empty():   # 精灵帧（modulate=fill 染队伍色+受击闪白）
			var box: float = rad * 2.0 * float(spr["scale"])
			draw_texture_rect_region(spr["tex"], Rect2(c - Vector2(box, box) * 0.5, Vector2(box, box)), spr["src"], fill)
		else:                    # 无精灵 → 白膜回退
			draw_circle(c, rad, fill)
			draw_arc(c, rad, 0.0, TAU, 20, base.darkened(0.4), 2.0)
		if flying:
			draw_arc(c, rad + 3.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 1.5)
		var ratio: float = clampf(u.hp / u.max_hp, 0.0, 1.0)
		if ratio < 1.0:
			var bw := rad * 2.0
			draw_rect(Rect2(c.x - rad, c.y - rad - 6.0, bw, 3.0), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(c.x - rad, c.y - rad - 6.0, bw * ratio, 3.0), _hp_color(ratio))
	for k in _seen.keys():
		if not cur.has(k):
			_seen.erase(k)
			_disp.erase(k)
			_uhp.erase(k)
			_atkcd.erase(k)

func _draw_topbar() -> void:
	draw_rect(Rect2(0, 0, _vw, TOPBAR_H), COL_PANEL)
	var p_crowns := _crowns(match_obj.battle.opponent_towers)   # 你拆掉的敌塔
	var o_crowns := _crowns(match_obj.battle.player_towers)
	_text(Vector2(12, 28), tr("hud_you"), COL_PLAYER, 16)
	_draw_crowns(Vector2(54, 8), p_crowns, COL_PLAYER)
	_text(Vector2(_vw - 56, 28), tr("hud_enemy"), COL_OPPONENT, 16)
	_draw_crowns(Vector2(_vw - 150, 8), o_crowns, COL_OPPONENT)
	# 倒计时：低于 30s 红色脉动强调
	var t: float = match_obj.battle.remaining_time()
	var tcol := Color.WHITE
	var tsize := 24
	if t <= 30.0:
		var pulse: float = 0.5 + 0.5 * sin(_elapsed * 6.0)
		tcol = Color(1, 0.4, 0.35).lerp(Color(1, 0.9, 0.3), pulse)
		tsize = 27
	_text(Vector2(_vw * 0.5 - 30, 32), "%d:%02d" % [int(t) / 60, int(t) % 60], tcol, tsize)

func _draw_crowns(start: Vector2, n: int, col: Color) -> void:
	for i in 3:
		_draw_crown(start + Vector2(i * 19 + 9, 9), 15.0, col, i < n)

func _draw_crown(c: Vector2, s: float, col: Color, filled: bool) -> void:
	var w := s
	var h := s * 0.8
	var pts := PackedVector2Array([
		c + Vector2(-w * 0.5, h * 0.5), c + Vector2(-w * 0.5, -h * 0.25),
		c + Vector2(-w * 0.25, h * 0.1), c + Vector2(0, -h * 0.5),
		c + Vector2(w * 0.25, h * 0.1), c + Vector2(w * 0.5, -h * 0.25),
		c + Vector2(w * 0.5, h * 0.5),
	])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Color(col.r, col.g, col.b, 0.35), 1.5)

func _draw_elixir() -> void:
	var e = match_obj.player.elixir
	var amt: float = e.get_amount()
	var mx: int = maxi(1, int(round(float(e.maximum) if "maximum" in e else 10.0)))
	var full: bool = e.is_full()
	var y := _vh - HUD_BOTTOM_H + 10.0
	var x0 := 16.0
	var next_w := 104.0
	var total_w := _vw - 32.0 - next_w
	var gap := 3.0
	var pip_w: float = (total_w - gap * (mx - 1)) / mx
	for i in mx:
		var px := x0 + i * (pip_w + gap)
		draw_rect(Rect2(px, y, pip_w, 20.0), Color(0.10, 0.05, 0.12, 0.85))   # 空槽
		var fillf: float = clampf(amt - float(i), 0.0, 1.0)
		if fillf > 0.0:
			var col := COL_ELIXIR
			if full:
				col = COL_ELIXIR.lerp(Color(1, 0.85, 1), (0.5 + 0.5 * sin(_elapsed * 8.0)) * 0.6)
			draw_rect(Rect2(px, y, pip_w * fillf, 20.0), col)
	_text(Vector2(x0 + 4, y + 16.0), "%d" % e.get_int(), Color.WHITE, 14)
	_draw_next_chip(_vw - next_w - 4.0, y - 2.0, next_w - 6.0, 24.0)

func _draw_next_chip(x: float, y: float, w: float, h: float) -> void:
	var nx = match_obj.player.deck.peek_next()
	if nx == null:
		return
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.4))
	_text(Vector2(x + 5, y + 10), tr("hud_next"), Color(0.7, 0.7, 0.7), 10)
	_text(Vector2(x + 5, y + h - 4), _short(tr("card_" + str(nx)), 9), Color.WHITE, 11)
	var cost: int = match_obj.player.card_cost(nx)
	draw_circle(Vector2(x + w - 12, y + h * 0.5), 8.0, COL_ELIXIR)
	_text(Vector2(x + w - 15, y + h * 0.5 + 4.0), "%d" % cost, Color.WHITE, 11)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.3, 0.85, 0.35)
	elif ratio > 0.25:
		return Color(0.95, 0.7, 0.2)
	return Color(0.9, 0.3, 0.25)

func _crowns(towers: Array) -> int:
	var n := 0
	for t in towers:
		if t.is_destroyed():
			n += 1
	return n

func _text(pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# —— 出牌交互（拖拽部署，CR 式：按卡→拖到场上→松手落子，决策 41）——
# 落点抬到手指上方（拇指不遮挡）。
func _drop_tile_from(screen: Vector2) -> Vector2:
	var lift: float = _tile_px().y * DROP_LIFT_TILES
	return _s2t(screen + Vector2(0.0, -lift))

# 卡牌出什么：spawn=生成兵（含 unit_id/count）；否则法术（radius>0=AOE 圈、=0=直伤准星）。
func _card_info(cid) -> Dictionary:
	for sk in loader.get_card(cid).get("skills", []):
		if typeof(sk) != TYPE_DICTIONARY:
			continue
		var t = sk.get("type")
		if t == "spawn_unit":
			return {"spawn": true, "unit_id": str(sk.get("unit_id")), "count": int(sk.get("count", 1)), "radius": 0.0}
		elif t == "aoe_damage" or t == "aoe_heal":
			return {"spawn": false, "unit_id": "", "count": 0, "radius": float(sk.get("radius", 1.0))}
		elif t == "direct_damage":
			return {"spawn": false, "unit_id": "", "count": 0, "radius": 0.0}
	return {"spawn": false, "unit_id": "", "count": 0, "radius": 0.0}

# 拖拽中：场上画落点 ghost（兵剪影 / AOE 圈 / 直伤准星）+ 合法绿/非法红。
func _draw_drag_ghost(a) -> void:
	if not _dragging or selected_card < 0 or match_obj.is_over():
		return
	var hand: Array = match_obj.player.deck.get_hand()
	if selected_card >= hand.size() or hand[selected_card] == null:
		return
	var info: Dictionary = _card_info(str(hand[selected_card]))
	var drop_tile: Vector2 = _drop_tile_from(_drag_screen)
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	var legal: bool = a.can_deploy(0, drop_tile) if info["spawn"] else true
	var col: Color = COL_OK if legal else COL_BAD
	var c: Vector2 = _t2s(drop_tile)
	draw_arc(c, ur * 0.9, 0.0, TAU, 28, col, 2.5)   # 落点标记环
	if info["spawn"]:
		var n: int = maxi(1, int(info["count"]))
		var vr: float = float(UNIT_VIS.get(info["unit_id"], {"r": 0.5})["r"]) * ur
		for i in n:
			var off := Vector2.ZERO
			if n > 1:
				var ang: float = float(i) / n * TAU
				off = Vector2(cos(ang), sin(ang)) * (vr * 0.9)
			var gc: Vector2 = c + off
			draw_circle(gc, vr, Color(col.r, col.g, col.b, 0.35))
			draw_arc(gc, vr, 0.0, TAU, 20, col, 2.0)
	elif info["radius"] > 0.0:
		var rr: float = float(info["radius"]) * ur
		draw_circle(c, rr, Color(col.r, col.g, col.b, 0.12))
		draw_arc(c, rr, 0.0, TAU, 40, col, 2.0)
	else:
		draw_line(c - Vector2(ur, 0), c + Vector2(ur, 0), col, 2.0)
		draw_line(c - Vector2(0, ur), c + Vector2(0, ur), col, 2.0)

# 拖拽兵牌时高亮己方半场可部署区（轻微脉动）。
func _draw_deploy_hint(a) -> void:
	if not _dragging or selected_card < 0:
		return
	var hand: Array = match_obj.player.deck.get_hand()
	if selected_card >= hand.size() or hand[selected_card] == null:
		return
	if not _card_info(str(hand[selected_card]))["spawn"]:
		return
	var fr := _field_rect()
	var y0: float = _t2s(Vector2(0, a.deploy_player_y_min)).y
	var pulse: float = 0.12 + 0.06 * (0.5 + 0.5 * sin(_elapsed * 6.0))
	draw_rect(Rect2(fr.position.x, y0, fr.size.x, fr.position.y + fr.size.y - y0),
			Color(COL_OK.r, COL_OK.g, COL_OK.b, pulse))

# 命中/落地 FX：按 kind 分派（sheet 序列帧 or 程序化）。AOE 卡用 radius 定大小。
func _draw_fx() -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for f in _fx:
		var p: float = clampf((_elapsed - f["t0"]) / f["dur"], 0.0, 1.0)
		var c: Vector2 = _t2s(f["pos"])
		var kind: String = f.get("kind", "spawn")
		var rt: float = float(f.get("radius", 0.0))
		match kind:
			"fireball":
				_fx_seq(TEX_EXPLOSION, EXPLOSION_FPX, EXPLOSION_N, c, (rt * 2.0 * ur) if rt > 0.0 else ur * 2.6, p, Color.WHITE)
			"lightning":
				_fx_seq(TEX_LIGHTNING, FX_SEQ_FPX, FX_SEQ_N, c, (rt * 2.2 * ur) if rt > 0.0 else ur * 3.0, p, Color(0.85, 0.92, 1.0))
			"zap":
				_fx_seq(TEX_RED_ENERGY, FX_SEQ_FPX, FX_SEQ_N, c, ur * 2.0, p, Color.WHITE)
			"arrows":
				_fx_arrows(c, maxf(rt, 1.0) * ur, p)
			"log":
				_fx_dust(c, maxf(rt, 1.0) * ur, p, Color(0.60, 0.50, 0.36))
			"heal":
				_fx_heal(c, maxf(rt, 1.0) * ur, p)
			_:
				_fx_dust(c, ur * 1.2, p, Color(0.78, 0.74, 0.66))

# sheet 横向序列帧：按进度 p 取帧画到 center（边长 size），modulate 染色。
func _fx_seq(tex: Texture2D, fpx: int, n: int, c: Vector2, size: float, p: float, mod: Color) -> void:
	var fi: int = mini(n - 1, int(p * n))
	draw_texture_rect_region(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), Rect2(fi * fpx, 0, fpx, fpx), mod)

# 程序化尘土环（召唤落地 / 滚石）：扩散 + 淡出。
func _fx_dust(c: Vector2, r: float, p: float, col: Color) -> void:
	var rr: float = r * (0.35 + 1.0 * p)
	var a: float = (1.0 - p) * 0.6
	draw_circle(c, rr * 0.85, Color(col.r, col.g, col.b, a * 0.35))
	draw_arc(c, rr, 0.0, TAU, 26, Color(col.r, col.g, col.b, a), 3.0)

# 程序化箭雨：数支箭错峰斜插入 AOE 区淡出。
func _fx_arrows(c: Vector2, r: float, p: float) -> void:
	var col := Color(0.92, 0.86, 0.6)
	for i in 8:
		var lt: float = clampf((p - float(i) * 0.03) / 0.45, 0.0, 1.0)
		if lt <= 0.0:
			continue
		var ox: float = (float(i) / 7.0 - 0.5) * 1.6 * r
		var tip: Vector2 = c + Vector2(ox, -r * 0.4 + r * 1.3 * lt)
		col.a = 1.0 - lt
		draw_line(tip + Vector2(-7, -18), tip, col, 2.0)
		draw_line(tip, tip + Vector2(-3, -5), col, 1.5)
		draw_line(tip, tip + Vector2(4, -5), col, 1.5)

# 程序化治疗：绿色扩散环 + 上浮十字。
func _fx_heal(c: Vector2, r: float, p: float) -> void:
	draw_arc(c, r * (0.4 + 0.8 * p), 0.0, TAU, 28, Color(0.4, 1.0, 0.5, (1.0 - p) * 0.7), 2.5)
	for i in 5:
		var ang: float = float(i) / 5.0 * TAU
		var pp: Vector2 = c + Vector2(cos(ang), sin(ang)) * r * 0.45 - Vector2(0, r * 0.7 * p)
		var pa: float = 1.0 - p
		draw_line(pp - Vector2(3, 0), pp + Vector2(3, 0), Color(0.5, 1, 0.6, pa), 2.0)
		draw_line(pp - Vector2(0, 3), pp + Vector2(0, 3), Color(0.5, 1, 0.6, pa), 2.0)

# 各 FX 类型时长。
func _fx_dur(kind: String) -> float:
	match kind:
		"fireball": return 0.5
		"lightning": return 0.45
		"zap": return 0.32
		"arrows": return 0.6
		"log": return 0.5
		"heal": return 0.65
		_: return POOF_DUR

func _cull_transients() -> void:
	_fx = _cull_list(_fx)
	_dmgnums = _cull_list(_dmgnums)
	_sparks = _cull_list(_sparks)
	_projectiles = _cull_list(_projectiles)
	for k in _flash.keys():
		if _flash[k] <= _elapsed:
			_flash.erase(k)

func _cull_list(arr: Array) -> Array:
	var keep: Array = []
	for f in arr:
		if _elapsed - f["t0"] < f["dur"]:
			keep.append(f)
	return keep

# —— V3-6b：逐帧 diff 逻辑状态派生反馈（受击/治疗/塔毁）——
func _disp_pos(u) -> Vector2:
	return _disp.get(u.get_instance_id(), u.pos)

func _detect_events() -> void:
	if match_obj.battle == null or match_obj.battle.arena == null:
		return
	for u in match_obj.battle.arena.get_units():
		if not u.is_alive():
			continue
		var id: int = u.get_instance_id()
		var cur: float = u.hp
		if _uhp.has(id):
			var d: float = float(_uhp[id]) - cur
			if d > 0.5:
				_on_hit(id, _disp_pos(u), d)
			elif d < -0.5:
				_spawn_dmgnum(_disp_pos(u), "+%d" % int(-d), COL_OK, 18)
		_uhp[id] = cur
	for side in [match_obj.battle.player_towers, match_obj.battle.opponent_towers]:
		for t in side:
			var id: int = t.get_instance_id()
			var cur: float = t.hp
			if _thp.has(id):
				var was_alive: bool = float(_thp[id]) > 0.0
				var d: float = float(_thp[id]) - cur
				if d > 0.5:
					_on_hit(id, t.pos - Vector2(0, t.fh * 0.5), d)
					if was_alive and t.is_destroyed():
						_on_tower_destroyed(t.pos)
			_thp[id] = cur

func _on_hit(id: int, pos: Vector2, amount: float) -> void:
	_flash[id] = _elapsed + FLASH_DUR
	var big: bool = amount >= HITSTOP_DMG
	_spawn_dmgnum(pos, "%d" % int(round(amount)), Color(1, 0.92, 0.45) if big else Color.WHITE, 24 if big else 18)
	_sparks.append({"pos": pos, "t0": _elapsed, "dur": SPARK_DUR})
	if big:
		_hitstop_t = maxf(_hitstop_t, HITSTOP_DUR)
		_shake_mag = minf(SHAKE_MAX, maxf(_shake_mag, SHAKE_BIG))
	elif amount >= SHAKE_HIT_DMG:
		_shake_mag = minf(SHAKE_MAX, maxf(_shake_mag, SHAKE_HIT))

func _on_tower_destroyed(pos: Vector2) -> void:
	_hitstop_t = maxf(_hitstop_t, HITSTOP_DUR)
	_shake_mag = minf(SHAKE_MAX, maxf(_shake_mag, SHAKE_TOWER))
	_fx.append({"pos": pos, "t0": _elapsed, "dur": 0.6, "kind": "fireball", "radius": 2.5})

# 远程兵开火检测（路线 A）：攻击冷却从 ~0 跳满 = 上升沿 = 刚出手 → 发射 attacker→target 投射物。
func _detect_attacks() -> void:
	if match_obj.battle == null or match_obj.battle.arena == null:
		return
	for u in match_obj.battle.arena.get_units():
		if not u.is_alive() or not PROJ_KIND.has(u.unit_id) or u.attack_range < PROJ_RANGED_MIN:
			continue
		var id: int = u.get_instance_id()
		var cur: float = u._attack_cooldown
		var prev: float = _atkcd.get(id, cur)
		_atkcd[id] = cur
		# 冷却跳升 = 刚 mark_attacked（逻辑层只会让冷却递减，唯有攻击会设回满）。
		# 注意不能用「prev≈0→cur满」：同 tick 内冷却减到 0 又立即设满，view 永远看不到 0，最低只见 ~0.1。
		if cur > prev + 0.01:
			var ct = u.current_target
			if ct != null and is_instance_valid(ct):
				var dist: float = u.pos.distance_to(ct.pos)
				_projectiles.append({"from": _disp_pos(u), "to": ct.pos, "t0": _elapsed,
						"dur": clampf(dist / PROJ_SPEED, 0.1, 0.45), "kind": PROJ_KIND[u.unit_id]})

# 投射物：from→to 线性飞行，按 kind 画箭/法术弹/火球。
func _draw_projectiles() -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for pr in _projectiles:
		var t: float = clampf((_elapsed - pr["t0"]) / pr["dur"], 0.0, 1.0)
		var a: Vector2 = _t2s(pr["from"])
		var b: Vector2 = _t2s(pr["to"])
		var pos: Vector2 = a.lerp(b, t)
		match pr["kind"]:
			"arrow":
				var dir: Vector2 = (b - a)
				dir = dir.normalized() if dir.length() > 0.001 else Vector2.UP
				var perp := Vector2(-dir.y, dir.x)
				var col := Color(0.93, 0.88, 0.6)
				draw_line(pos - dir * ur * 0.7, pos, col, 2.0)
				draw_line(pos, pos - dir * 5.0 + perp * 3.0, col, 1.5)
				draw_line(pos, pos - dir * 5.0 - perp * 3.0, col, 1.5)
			"bolt":
				draw_circle(pos, ur * 0.24, Color(0.8, 0.55, 1.0, 0.85))
				draw_circle(pos, ur * 0.12, Color(1, 1, 1, 0.95))
			"fireball":
				var fi: int = 1 + int(_elapsed * 14.0) % 7   # 飞行帧循环（避开末尾炸帧）
				var sz: float = ur * 1.0
				draw_texture_rect_region(TEX_PROJ_FIREBALL, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Rect2(fi * PROJ_FB_FPX, 0, PROJ_FB_FPX, PROJ_FB_FPX))

func _spawn_dmgnum(pos: Vector2, text: String, col: Color, size: int) -> void:
	_dmgnums.append({"pos": pos, "text": text, "col": col, "size": size, "t0": _elapsed, "dur": DMGNUM_DUR})

func _update_disp(delta: float) -> void:
	if match_obj.battle == null or match_obj.battle.arena == null:
		return
	var alpha: float = 1.0 - exp(-SMOOTH_K * delta)
	for u in match_obj.battle.arena.get_units():
		if not u.is_alive():
			continue
		var id: int = u.get_instance_id()
		if _disp.has(id):
			_disp[id] = (_disp[id] as Vector2).lerp(u.pos, alpha)
		else:
			_disp[id] = u.pos

func _update_shake(delta: float) -> void:
	if _shake_mag <= 0.05:
		_shake = Vector2.ZERO
		_shake_mag = 0.0
		return
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_mag
	_shake_mag = maxf(0.0, _shake_mag - SHAKE_DECAY * delta)

# 命中火花（白膜：径向短线）+ 浮动伤害数字。
func _draw_combat_fx() -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for s in _sparks:
		var p: float = clampf((_elapsed - s["t0"]) / s["dur"], 0.0, 1.0)
		var c: Vector2 = _t2s(s["pos"])
		var rr: float = ur * (0.2 + 0.6 * p)
		var al: float = 1.0 - p
		for k in 6:
			var dir := Vector2(cos(float(k) / 6.0 * TAU), sin(float(k) / 6.0 * TAU))
			draw_line(c + dir * rr * 0.4, c + dir * rr, Color(1, 1, 0.6, al), 1.5)
	for dn in _dmgnums:
		var p2: float = clampf((_elapsed - dn["t0"]) / dn["dur"], 0.0, 1.0)
		var c2: Vector2 = _t2s(dn["pos"]) + Vector2(-8.0, -ur * 0.8 - DMGNUM_RISE * p2)
		var col: Color = dn["col"]
		col.a = 1.0 - p2
		draw_string(_font, c2, dn["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(dn["size"]), col)

# 入场缩放：新兵从 0.35 弹到 1.0（ease-out）。
func _pop_scale(id: int) -> float:
	var t0: float = _seen.get(id, _elapsed)
	var p: float = (_elapsed - t0) / POP_DUR
	if p >= 1.0:
		return 1.0
	var s: float = clampf(p, 0.0, 1.0)
	return 0.35 + 0.65 * (1.0 - pow(1.0 - s, 3.0))

# —— HUD：手牌 ——
func _build_cards() -> void:
	var n := 4
	var bw := (_vw - 16.0 * (n + 1)) / n
	for i in n:
		var b := Button.new()
		b.position = Vector2(16.0 + i * (bw + 16.0), _vh - HUD_BOTTOM_H + 40.0)
		b.size = Vector2(bw, HUD_BOTTOM_H - 56.0)
		b.button_down.connect(_on_card_down.bind(i))
		b.button_up.connect(_on_card_up.bind(i))
		# 透明：仅作输入热区，卡面由 _draw_cards 自绘（便于 V3-7 贴皮）。
		var empty := StyleBoxEmpty.new()
		for sn in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(sn, empty)
		b.focus_mode = Control.FOCUS_NONE
		b.text = ""
		add_child(b)
		_card_btns.append(b)
		_card_base_pos.append(b.position)
	_sync_cards()

# 按下卡牌 = 开始拖拽（disabled 卡不会触发 button_down，出不起的牌拖不动）。
func _on_card_down(i: int) -> void:
	if match_obj == null or match_obj.is_over():
		return
	selected_card = i
	_dragging = true
	_drag_screen = get_viewport().get_mouse_position()

# 松手 = 落子：在场上且合法则出牌 + 涟漪；落在 HUD/非法处则取消。
func _on_card_up(i: int) -> void:
	var was_dragging := _dragging
	var sc := selected_card
	_dragging = false
	selected_card = -1
	if not was_dragging or sc != i or match_obj == null or match_obj.is_over():
		return
	var screen: Vector2 = get_viewport().get_mouse_position()
	if screen.y < TOPBAR_H or screen.y > _vh - HUD_BOTTOM_H:
		return   # 松手在 HUD/顶栏 → 取消
	var drop_tile: Vector2 = _drop_tile_from(screen)
	var hand: Array = match_obj.player.deck.get_hand()
	var cid: String = str(hand[sc]) if (sc < hand.size() and hand[sc] != null) else ""
	if match_obj.player.try_play_card(sc, drop_tile):
		var kind: String = FX_KIND.get(cid, "spawn")
		var info: Dictionary = _card_info(cid)
		_fx.append({"pos": drop_tile, "t0": _elapsed, "dur": _fx_dur(kind), "kind": kind, "radius": float(info["radius"])})

# 仅作输入门控：出不起/空格 → disabled（disabled 不触发 button_down，拖不动）。卡面见 _draw_cards。
func _sync_cards() -> void:
	if match_obj == null:
		return
	var hand: Array = match_obj.player.deck.get_hand()
	for i in _card_btns.size():
		var b: Button = _card_btns[i]
		b.disabled = not (i < hand.size() and hand[i] != null and match_obj.player.can_play(i))

# 自绘卡面：底板 + 卡名 + 费用珠 + 不可用「扫光」(暗罩随圣水→费用回落) + 选中高亮 + 拖拽抬起。
func _draw_cards() -> void:
	var hand: Array = match_obj.player.deck.get_hand()
	var e = match_obj.player.elixir
	for i in _card_btns.size():
		if i >= _card_base_pos.size():
			continue
		var sz: Vector2 = (_card_btns[i] as Button).size
		var lifted: bool = _dragging and i == selected_card
		var pos: Vector2 = _card_base_pos[i] - Vector2(0, 14.0 if lifted else 0.0)
		var rect := Rect2(pos, sz)
		var sel: bool = i == selected_card
		draw_rect(rect, COL_CARD_SEL if sel else COL_CARD_BG)
		if i < hand.size() and hand[i] != null:
			var cid := str(hand[i])
			var cost: int = match_obj.player.card_cost(cid)
			var affordable: bool = e.get_int() >= cost
			_text(pos + Vector2(7, 22), _short(tr("card_" + cid), 10), Color.WHITE if affordable else Color(0.62, 0.62, 0.66), 14)
			draw_circle(pos + Vector2(15, sz.y - 15), 11.0, COL_ELIXIR)
			_text(pos + Vector2(11, sz.y - 10), "%d" % cost, Color.WHITE, 14)
			if not affordable:
				var prog: float = clampf(e.get_amount() / float(maxi(1, cost)), 0.0, 1.0)
				draw_rect(Rect2(pos.x, pos.y, sz.x, sz.y * (1.0 - prog)), Color(0, 0, 0, 0.55))
		if sel:
			draw_rect(rect, COL_CROWN, false, 3.0)
		else:
			draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.0)

func _short(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1) + "…"

# —— HUD：结算面板 ——
func _build_result_panel() -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_layer.visible = false
	add_child(_result_layer)
	# 调暗/标题/王冠/比分由 _draw_end_screen 动画绘制；本层只承载（延迟淡入的）按钮。
	# 比赛一结束即 visible（透明全屏 STOP）→ 拦截点击、演出期间不能再出牌。

# 比赛结束：进入演出（调暗/标题 sting/王冠落入/比分滚动），按钮稍后淡入。
func _start_ending() -> void:
	_ending = true
	_end_t = 0.0
	_end_result = match_obj.get_result()
	_end_pscore = match_obj.battle.total_tower_hp(match_obj.battle.player_towers)
	_end_oscore = match_obj.battle.total_tower_hp(match_obj.battle.opponent_towers)
	_result_layer.visible = true   # 透明全屏，拦截点击（演出期不能出牌）

func _add_result_buttons() -> void:
	_end_buttons_added = true
	if GameStateScript.run != null:
		_result_btn(tr("btn_continue"), _vh * 0.62, _on_run_continue)   # Roguelite：回 run 中枢推进/给奖励/结算
	else:
		_result_btn(tr("btn_rematch"), _vh * 0.62, _on_rematch)
		_result_btn(tr("btn_menu"), _vh * 0.62 + 70.0, _on_menu)
	_result_layer.modulate = Color(1, 1, 1, 0.0)
	create_tween().tween_property(_result_layer, "modulate:a", 1.0, 0.3)

# 胜负演出（全 _draw 驱动、单一 _end_t 计时）。
func _draw_end_screen() -> void:
	if not _ending:
		return
	var dimp: float = clampf(_end_t / 0.35, 0.0, 1.0)
	draw_rect(Rect2(0, 0, _vw, _vh), Color(0, 0, 0, 0.62 * dimp))
	var win: bool = _end_result == BattleScript.RESULT_PLAYER_WIN
	var lose: bool = _end_result == BattleScript.RESULT_OPPONENT_WIN
	var title := tr("result_win") if win else (tr("result_lose") if lose else tr("result_draw"))
	var tcol: Color = COL_PLAYER if win else (COL_OPPONENT if lose else Color.WHITE)
	# 标题 sting：透明淡入 + 字号回弹放大
	var ti: float = clampf(_end_t / 0.45, 0.0, 1.0)
	var fs: int = int(40.0 + 24.0 * _ease_back(ti))
	tcol.a = ti
	draw_string(_font, Vector2(0, _vh * 0.34), title, HORIZONTAL_ALIGNMENT_CENTER, _vw, fs, tcol)
	# 王冠落入（你拆掉的敌塔数，逐个延迟 + 回弹下落）
	var earned: int = _crowns(match_obj.battle.opponent_towers)
	var cw := 56.0
	var sx: float = _vw * 0.5 - float(earned - 1) * cw * 0.5
	for i in earned:
		var lt: float = clampf((_end_t - 0.2 - float(i) * 0.12) / 0.4, 0.0, 1.0)
		if lt <= 0.0:
			continue
		var yb: float = _ease_back(lt)
		_draw_crown(Vector2(sx + float(i) * cw, _vh * 0.46 - 60.0 * (1.0 - yb)), 40.0, COL_CROWN, true)
	# 比分滚动
	var cu: float = clampf((_end_t - 0.3) / 0.7, 0.0, 1.0)
	var sc := Color(1, 1, 1, clampf(_end_t * 2.0, 0.0, 1.0))
	draw_string(_font, Vector2(0, _vh * 0.56), tr("result_score") % [int(round(_end_pscore * cu)), int(round(_end_oscore * cu))],
			HORIZONTAL_ALIGNMENT_CENTER, _vw, 22, sc)

# back-out 缓动（0→1，末段回弹过冲 >1）。
func _ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x: float = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x

func _result_btn(txt: String, y: float, cb: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.position = Vector2(_vw * 0.5 - 120, y)
	b.size = Vector2(240, 56)
	b.pressed.connect(cb)
	_result_layer.add_child(b)

func _on_run_continue() -> void:
	GameStateScript.run_last_result = match_obj.get_result()
	get_tree().change_scene_to_file(RunSceneScene)

func _on_rematch() -> void:
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://view/main_menu.tscn")
