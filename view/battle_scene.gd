# BattleScene —— 显示层（V3 2D；V3-6a 起加交互手感）。
#
# 只读 Match/Arena 的逻辑状态作画；出牌一律经 player.try_play_card（玩家/AI 对称）。
# 抽象 tile 空间 → 屏幕像素的映射只活在本层（_t2s/_s2t）。
# y=0 敌方底线(屏上)、y=grid_h 玩家底线(屏下)；河横贯中部、左右双桥。
# 出牌 = 拖拽部署（CR 式，决策 41）：按手牌→拖到场上(落点抬到手指上方)→松手落子；
#   拖拽中画落点 ghost(兵剪影/AOE 圈/直伤准星)+合法绿/非法红 + 己方半场高亮；成功落子有涟漪、新兵入场缩放。
# 仍为白膜：V3-6b 加战斗 juice：10Hz→60fps 插值、受击闪白/数字、轻顿帧、震屏、命中 stub FX；仍仅显示层读逻辑状态。
extends Node2D

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const BattleScript = preload("res://logic/battle.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const GameStateScript = preload("res://view/game_state.gd")
const RunModifiersScript = preload("res://logic/run_modifiers.gd")
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
const HIT_FLASH_DUR := 0.16                    # 受击闪白时长
const FLOAT_TEXT_DUR := 0.70                   # 浮动伤害数字时长
const HIT_FX_DUR := 0.22                       # 命中 stub FX 时长
const HITSTOP_DUR := 0.045                     # 视觉顿帧（只暂停本 view 推进，逻辑层状态结构不变）
const SHAKE_DUR := 0.16                        # 震屏时长
const SHAKE_MAX_PX := 7.0                      # 轻震屏上限

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
var _fx: Array = []           # 场上短 FX：poof / hit
var _float_texts: Array = []  # 浮动数字：[{pos:Vector2(tile), text:String, color:Color, t0:float, dur:float}]
var _seen: Dictionary = {}    # 单位 instance_id → 首见 _elapsed（入场缩放）
var _card_base_pos: Array = []
var _prev_units: Dictionary = {}       # instance_id → {pos,hp,owner,unit_id}
var _prev_towers: Dictionary = {}      # instance_id → {pos,hp,owner,kind}
var _interp_from: Dictionary = {}      # instance_id → 上个逻辑 tick 位置
var _interp_to: Dictionary = {}        # instance_id → 当前逻辑 tick 位置
var _hit_flash: Dictionary = {}        # instance_id → 受击/治疗闪光起始时间
var _last_tick_count := 0
var _hitstop_remaining := 0.0
var _shake_t0 := -999.0
var _shake_amp := 0.0
var _shake_offset := Vector2.ZERO

@onready var _vw: float = float(get_viewport_rect().size.x)
@onready var _vh: float = float(get_viewport_rect().size.y)

func _ready() -> void:
	_font = ThemeDB.fallback_font
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
	_snapshot_combat_state()
	_last_tick_count = match_obj.clock.tick_count
	_build_cards()
	_build_result_panel()
	set_process(true)

func _process(delta: float) -> void:
	if match_obj == null:
		return
	_elapsed += delta
	_update_shake_offset()
	var before_units: Dictionary = _snapshot_units()
	var before_towers: Dictionary = _snapshot_towers()
	var step_dt := delta
	if _hitstop_remaining > 0.0:
		var hold: float = minf(step_dt, _hitstop_remaining)
		_hitstop_remaining -= hold
		step_dt -= hold
	if not match_obj.is_over() and step_dt > 0.0:
		match_obj.update(step_dt)
	_after_logic_update(before_units, before_towers)
	if _dragging:
		_drag_screen = get_viewport().get_mouse_position()
	_cull_fx()
	_cull_float_texts()
	_cull_hit_flash()
	_sync_cards()
	if match_obj.is_over() and not _result_layer.visible:
		_show_result()
	queue_redraw()

# —— 坐标映射 ——
func _field_rect() -> Rect2:
	return Rect2(0.0, TOPBAR_H, _vw, _vh - TOPBAR_H - HUD_BOTTOM_H)

func _t2s(p: Vector2) -> Vector2:
	var a = match_obj.battle.arena
	var fr := _field_rect()
	return Vector2(fr.position.x + p.x / a.grid_w * fr.size.x,
				   fr.position.y + p.y / a.grid_h * fr.size.y) + _shake_offset

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
	_draw_float_texts()
	_draw_drag_ghost(a)
	_draw_topbar()
	_draw_elixir()

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
			var w: float = t.fw * tp.x
			var h: float = t.fh * tp.y
			var r := Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
			if t.is_destroyed():
				draw_rect(r, Color(0.25, 0.25, 0.25, 0.6))
				continue
			var fill_col := base.darkened(0.25)
			if _flash_alpha(t.get_instance_id()) > 0.0:
				fill_col = fill_col.lerp(Color.WHITE, _flash_alpha(t.get_instance_id()))
			draw_rect(r, fill_col)
			draw_rect(r, base, false, 3.0)
			if t.is_king():
				draw_circle(c, minf(w, h) * 0.18, base.lightened(0.3))
			var ratio: float = clampf(t.hp / t.max_hp, 0.0, 1.0)
			var bw := w * 0.9
			var bx := c.x - bw * 0.5
			var by := c.y - h * 0.5 - 8.0
			draw_rect(Rect2(bx, by, bw, 5.0), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(bx, by, bw * ratio, 5.0), _hp_color(ratio))

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
		var c := _t2s(_render_unit_pos(u))
		var vis: Dictionary = UNIT_VIS.get(u.unit_id, {"r": 0.5})
		var rad: float = float(vis["r"]) * ur * _pop_scale(id)
		var flying: bool = u.target_type == "air"
		if flying:
			draw_circle(c + Vector2(0, ur * 0.5), rad * 0.6, Color(0, 0, 0, 0.25))  # 地面影子
			c -= Vector2(0, ur * 0.7)                                                # 单位上浮
		var body_col := base
		var fa: float = _flash_alpha(id)
		if fa > 0.0:
			body_col = body_col.lerp(Color.WHITE, fa)
		draw_circle(c, rad, body_col)
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

func _draw_topbar() -> void:
	draw_rect(Rect2(0, 0, _vw, TOPBAR_H), COL_PANEL)
	var p_crowns := _crowns(match_obj.battle.opponent_towers)
	var o_crowns := _crowns(match_obj.battle.player_towers)
	_text(Vector2(16, 34), "YOU  %d" % p_crowns, COL_PLAYER, 22)
	_text(Vector2(_vw - 120, 34), "%d  ENEMY" % o_crowns, COL_OPPONENT, 22)
	var t: float = match_obj.battle.remaining_time()
	_text(Vector2(_vw * 0.5 - 28, 34), "%d:%02d" % [int(t) / 60, int(t) % 60], Color.WHITE, 22)

func _draw_elixir() -> void:
	var e = match_obj.player.elixir
	var amt: float = e.get_amount()
	var mx: float = float(e.maximum) if "maximum" in e else 10.0
	var y := _vh - HUD_BOTTOM_H + 10.0
	var w := _vw - 32.0
	draw_rect(Rect2(16, y, w, 18.0), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(16, y, w * clampf(amt / mx, 0.0, 1.0), 18.0), COL_ELIXIR)
	_text(Vector2(20, y + 15.0), "%d" % int(amt), Color.WHITE, 16)

func _render_unit_pos(u) -> Vector2:
	var id: int = u.get_instance_id()
	if not _interp_from.has(id) or not _interp_to.has(id):
		return u.pos
	var alpha: float = clampf(match_obj.get_interpolation_fraction(), 0.0, 1.0)
	var from_pos: Vector2 = _interp_from[id]
	var to_pos: Vector2 = _interp_to[id]
	return from_pos.lerp(to_pos, alpha)

func _flash_alpha(id: int) -> float:
	if not _hit_flash.has(id):
		return 0.0
	var p: float = clampf((_elapsed - float(_hit_flash[id])) / HIT_FLASH_DUR, 0.0, 1.0)
	return (1.0 - p) * 0.85

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

# 落地涟漪。
func _draw_fx() -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for f in _fx:
		var p: float = clampf((_elapsed - f["t0"]) / f["dur"], 0.0, 1.0)
		var c: Vector2 = _t2s(f["pos"])
		var kind := String(f.get("kind", "poof"))
		if kind == "hit":
			var col: Color = f.get("color", Color.WHITE)
			var a: float = 1.0 - p
			for i in 6:
				var ang: float = float(i) / 6.0 * TAU + p * 1.6
				var inner: Vector2 = c + Vector2(cos(ang), sin(ang)) * ur * (0.12 + 0.25 * p)
				var outer: Vector2 = c + Vector2(cos(ang), sin(ang)) * ur * (0.45 + 0.55 * p)
				draw_line(inner, outer, Color(col.r, col.g, col.b, a), 2.0)
			draw_arc(c, ur * (0.25 + 0.45 * p), 0.0, TAU, 18, Color(col.r, col.g, col.b, a * 0.7), 1.5)
		else:
			draw_arc(c, ur * (0.3 + 1.3 * p), 0.0, TAU, 32, Color(1, 1, 1, (1.0 - p) * 0.7), 2.0 + 2.0 * (1.0 - p))

func _draw_float_texts() -> void:
	for f in _float_texts:
		var p: float = clampf((_elapsed - f["t0"]) / f["dur"], 0.0, 1.0)
		var pos: Vector2 = _t2s(f["pos"]) + Vector2(0.0, -34.0 * p)
		var col: Color = f["color"]
		col.a = 1.0 - p
		_text(pos + Vector2(-12, 0), String(f["text"]), col, 18)

func _cull_fx() -> void:
	if _fx.is_empty():
		return
	var keep: Array = []
	for f in _fx:
		if _elapsed - f["t0"] < f["dur"]:
			keep.append(f)
	_fx = keep

func _cull_float_texts() -> void:
	if _float_texts.is_empty():
		return
	var keep: Array = []
	for f in _float_texts:
		if _elapsed - f["t0"] < f["dur"]:
			keep.append(f)
	_float_texts = keep

func _cull_hit_flash() -> void:
	for id in _hit_flash.keys():
		if _elapsed - float(_hit_flash[id]) >= HIT_FLASH_DUR:
			_hit_flash.erase(id)

# 入场缩放：新兵从 0.35 弹到 1.0（ease-out）。
func _update_shake_offset() -> void:
	var p: float = clampf((_elapsed - _shake_t0) / SHAKE_DUR, 0.0, 1.0)
	if p >= 1.0 or _shake_amp <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	var amp: float = _shake_amp * (1.0 - p)
	var sx: float = sin(_elapsed * 97.0) + sin(_elapsed * 43.0) * 0.5
	var sy: float = cos(_elapsed * 83.0) + sin(_elapsed * 59.0) * 0.5
	_shake_offset = Vector2(sx, sy).normalized() * amp

func _trigger_hit_juice(pos: Vector2, amount: float, is_heal: bool, id: int) -> void:
	var col := Color(0.35, 1.0, 0.45) if is_heal else Color(1.0, 0.86, 0.35)
	var prefix := "+" if is_heal else "-"
	_float_texts.append({"pos": pos, "text": "%s%d" % [prefix, int(round(amount))], "color": col, "t0": _elapsed, "dur": FLOAT_TEXT_DUR})
	_fx.append({"kind": "hit", "pos": pos, "t0": _elapsed, "dur": HIT_FX_DUR, "color": col})
	_hit_flash[id] = _elapsed
	if not is_heal:
		_hitstop_remaining = maxf(_hitstop_remaining, HITSTOP_DUR)
		_shake_t0 = _elapsed
		_shake_amp = minf(SHAKE_MAX_PX, 2.0 + amount / 90.0)

func _snapshot_units() -> Dictionary:
	var out := {}
	if match_obj == null or match_obj.battle == null or match_obj.battle.arena == null:
		return out
	for u in match_obj.battle.arena.get_units():
		var id: int = u.get_instance_id()
		out[id] = {"pos": u.pos, "hp": float(u.hp), "owner": int(u.owner_id), "unit_id": String(u.unit_id)}
	return out

func _snapshot_towers() -> Dictionary:
	var out := {}
	if match_obj == null or match_obj.battle == null:
		return out
	for side in [match_obj.battle.player_towers, match_obj.battle.opponent_towers]:
		for t in side:
			var id: int = t.get_instance_id()
			out[id] = {"pos": t.pos, "hp": float(t.hp), "owner": int(t.owner_id), "kind": String(t.kind)}
	return out

func _snapshot_combat_state() -> void:
	_prev_units = _snapshot_units()
	_prev_towers = _snapshot_towers()
	_interp_from.clear()
	_interp_to.clear()
	for id in _prev_units.keys():
		_interp_from[id] = _prev_units[id]["pos"]
		_interp_to[id] = _prev_units[id]["pos"]

func _after_logic_update(before_units: Dictionary, before_towers: Dictionary) -> void:
	var after_units: Dictionary = _snapshot_units()
	var after_towers: Dictionary = _snapshot_towers()
	var tick_changed: bool = match_obj.clock != null and match_obj.clock.tick_count != _last_tick_count
	if tick_changed:
		for id in after_units.keys():
			_interp_from[id] = before_units[id]["pos"] if before_units.has(id) else after_units[id]["pos"]
			_interp_to[id] = after_units[id]["pos"]
		for id in _interp_from.keys():
			if not after_units.has(id):
				_interp_from.erase(id)
				_interp_to.erase(id)
		_last_tick_count = match_obj.clock.tick_count
	_detect_hp_changes(before_units, after_units)
	_detect_hp_changes(before_towers, after_towers)
	_prev_units = after_units
	_prev_towers = after_towers

func _detect_hp_changes(before: Dictionary, after: Dictionary) -> void:
	for id in after.keys():
		if not before.has(id):
			continue
		var old_hp: float = float(before[id]["hp"])
		var new_hp: float = float(after[id]["hp"])
		if absf(old_hp - new_hp) < 0.01:
			continue
		var is_heal := new_hp > old_hp
		var amount: float = absf(new_hp - old_hp)
		_trigger_hit_juice(after[id]["pos"], amount, is_heal, int(id))

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
	if match_obj.player.try_play_card(sc, drop_tile):
		_fx.append({"pos": drop_tile, "t0": _elapsed, "dur": POOF_DUR})

func _sync_cards() -> void:
	if match_obj == null:
		return
	var hand: Array = match_obj.player.deck.get_hand()
	for i in _card_btns.size():
		var b: Button = _card_btns[i]
		var lifted: bool = _dragging and i == selected_card
		if i < _card_base_pos.size():
			b.position.y = _card_base_pos[i].y - (14.0 if lifted else 0.0)
		if i >= hand.size() or hand[i] == null:
			b.text = ""
			b.disabled = true
			b.modulate = Color.WHITE
			continue
		var cid := str(hand[i])
		b.text = "%s\n%d" % [cid, match_obj.player.card_cost(cid)]
		b.disabled = not match_obj.player.can_play(i)
		b.modulate = Color(1, 0.9, 0.4) if i == selected_card else Color.WHITE

# —— HUD：结算面板 ——
func _build_result_panel() -> void:
	_result_layer = Control.new()
	_result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_layer.visible = false
	add_child(_result_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_result_layer.add_child(dim)

func _show_result() -> void:
	_result_layer.visible = true
	var res: int = match_obj.get_result()
	var title := "DRAW"
	var col := Color.WHITE
	if res == BattleScript.RESULT_PLAYER_WIN:
		title = "YOU WIN"
		col = COL_PLAYER
	elif res == BattleScript.RESULT_OPPONENT_WIN:
		title = "YOU LOSE"
		col = COL_OPPONENT
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = Vector2(_vw * 0.5 - 150, _vh * 0.38)
	lbl.size = Vector2(300, 70)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_layer.add_child(lbl)
	var pscore: float = match_obj.battle.total_tower_hp(match_obj.battle.player_towers)
	var oscore: float = match_obj.battle.total_tower_hp(match_obj.battle.opponent_towers)
	var sub := Label.new()
	sub.text = "Towers  You %d : Enemy %d" % [int(pscore), int(oscore)]
	sub.position = Vector2(_vw * 0.5 - 150, _vh * 0.5)
	sub.size = Vector2(300, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_layer.add_child(sub)
	if GameStateScript.run != null:
		_result_btn("CONTINUE", _vh * 0.58, _on_run_continue)   # Roguelite：回 run 中枢推进/给奖励/结算
	else:
		_result_btn("REMATCH", _vh * 0.58, _on_rematch)
		_result_btn("MENU", _vh * 0.58 + 70.0, _on_menu)

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
