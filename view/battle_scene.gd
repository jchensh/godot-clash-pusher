# BattleScene —— 显示层（V3 2D 白膜）。
#
# 只读 Match/Arena 的逻辑状态作画；出牌一律经 player.try_play_card（玩家/AI 对称）。
# 抽象 tile 空间 → 屏幕像素的映射只活在本层（_t2s/_s2t）。
# y=0 敌方底线(屏上)、y=grid_h 玩家底线(屏下)；河横贯中部、左右双桥。
# 两段式出牌：先点手牌选中 → 再点己方半场落点（tile 空间，经 Arena.can_deploy 校验）。
# 美术/动画/特效在 V3-4 / V3-7 重做，本步只求功能可见（场地/兵自由走位/塔互射/胜负）。
extends Node2D

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const BattleScript = preload("res://logic/battle.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const GameStateScript = preload("res://view/game_state.gd")

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
}

var match_obj
var loader
var _font: Font
var selected_card := -1
var _card_btns: Array = []
var _result_layer: Control

@onready var _vw: float = float(get_viewport_rect().size.x)
@onready var _vh: float = float(get_viewport_rect().size.y)

func _ready() -> void:
	_font = ThemeDB.fallback_font
	loader = ConfigLoaderScript.new()
	loader.load_all()
	match_obj = MatchScript.new(loader)
	match_obj.setup(GameStateScript.level_id, GameStateScript.player_deck)
	match_obj.set_opponent_controller(AIControllerScript.new(match_obj, loader))
	_build_cards()
	_build_result_panel()
	set_process(true)

func _process(delta: float) -> void:
	if match_obj == null:
		return
	if not match_obj.is_over():
		match_obj.update(delta)
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
				   fr.position.y + p.y / a.grid_h * fr.size.y)

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
	_draw_towers()
	_draw_units(a)
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
			draw_rect(r, base.darkened(0.25))
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
	for u in a.get_units():
		if not u.is_alive():
			continue
		var base: Color = COL_PLAYER if u.owner_id == 0 else COL_OPPONENT
		var c := _t2s(u.pos)
		var vis: Dictionary = UNIT_VIS.get(u.unit_id, {"r": 0.5})
		var rad: float = float(vis["r"]) * ur
		var flying: bool = u.target_type == "air"
		if flying:
			draw_circle(c + Vector2(0, ur * 0.5), rad * 0.6, Color(0, 0, 0, 0.25))  # 地面影子
			c -= Vector2(0, ur * 0.7)                                                # 单位上浮
		draw_circle(c, rad, base)
		draw_arc(c, rad, 0.0, TAU, 20, base.darkened(0.4), 2.0)
		if flying:
			draw_arc(c, rad + 3.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 1.5)
		var ratio: float = clampf(u.hp / u.max_hp, 0.0, 1.0)
		if ratio < 1.0:
			var bw := rad * 2.0
			draw_rect(Rect2(c.x - rad, c.y - rad - 6.0, bw, 3.0), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(c.x - rad, c.y - rad - 6.0, bw * ratio, 3.0), _hp_color(ratio))

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

# —— 出牌交互 ——
func _unhandled_input(event: InputEvent) -> void:
	if match_obj == null or match_obj.is_over() or selected_card < 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < TOPBAR_H or event.position.y > _vh - HUD_BOTTOM_H:
			return
		var pos := _s2t(event.position)
		if match_obj.player.try_play_card(selected_card, pos):
			selected_card = -1

# —— HUD：手牌 ——
func _build_cards() -> void:
	var n := 4
	var bw := (_vw - 16.0 * (n + 1)) / n
	for i in n:
		var b := Button.new()
		b.position = Vector2(16.0 + i * (bw + 16.0), _vh - HUD_BOTTOM_H + 40.0)
		b.size = Vector2(bw, HUD_BOTTOM_H - 56.0)
		b.pressed.connect(_on_card_pressed.bind(i))
		add_child(b)
		_card_btns.append(b)
	_sync_cards()

func _on_card_pressed(i: int) -> void:
	selected_card = i if selected_card != i else -1

func _sync_cards() -> void:
	if match_obj == null:
		return
	var hand: Array = match_obj.player.deck.get_hand()
	for i in _card_btns.size():
		var b: Button = _card_btns[i]
		if i >= hand.size() or hand[i] == null:
			b.text = ""
			b.disabled = true
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
	_result_btn("REMATCH", _vh * 0.58, _on_rematch)
	_result_btn("MENU", _vh * 0.58 + 70.0, _on_menu)

func _result_btn(txt: String, y: float, cb: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.position = Vector2(_vw * 0.5 - 120, y)
	b.size = Vector2(240, 56)
	b.pressed.connect(cb)
	_result_layer.add_child(b)

func _on_rematch() -> void:
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://view/main_menu.tscn")
