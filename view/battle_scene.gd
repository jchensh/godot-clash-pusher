# BattleScene —— Step 7b 显示层 MVP（白膜）。
#
# 只读 Match 的逻辑状态作画；出牌一律经 player.try_play_card（玩家/AI 对称）。
# 逻辑坐标 0~1 → 像素的映射只活在本层：progress 0=己方塔在屏幕下，1=敌方塔在上。
# 单 lane；对手被动（不出牌，AI 留到 Step 8）。两段式出牌：先点手牌，再点己方半场落点。
extends Node2D

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const UnitScript = preload("res://logic/unit.gd")
const BattleScript = preload("res://logic/battle.gd")

const LANE_TOP := 240.0       # progress 1 = 敌方王塔
const LANE_BOTTOM := 940.0    # progress 0 = 己方王塔
const LANE_X := 360.0
const DEPLOY_MAX := 0.5       # 落点限己方半场

const COL_PLAYER := Color(0.35, 0.55, 1.0)
const COL_OPPONENT := Color(1.0, 0.42, 0.38)

var match_obj
var selected_card := -1

var unit_layer: Node2D
var unit_views := {}          # unit -> Polygon2D
var tower_bars := []          # [{tower, fill, full_w, fill_h, body}]
var card_buttons := []
var elixir_fill: ColorRect
var elixir_full_w := 0.0
var elixir_label: Label
var banner: Label

func _ready() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	match_obj = MatchScript.new(loader)
	match_obj.setup("level_01")
	_build_field()
	unit_layer = Node2D.new()
	add_child(unit_layer)
	_build_towers()
	_build_hud()

func _process(delta: float) -> void:
	if match_obj == null:
		return
	match_obj.update(delta)
	_sync_units(delta)
	_sync_towers()
	_sync_hud()
	_sync_banner()

# ---------- 坐标映射（仅显示层） ----------
func _progress_to_y(p: float) -> float:
	return lerpf(LANE_BOTTOM, LANE_TOP, clampf(p, 0.0, 1.0))

func _y_to_progress(y: float) -> float:
	return clampf((LANE_BOTTOM - y) / (LANE_BOTTOM - LANE_TOP), 0.0, 1.0)

# ---------- 建场景 ----------
func _rect(color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

func _label(text: String, pos: Vector2, font_size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _build_field() -> void:
	_rect(Color(0.10, 0.11, 0.14), Vector2(0, 0), Vector2(720, 1280))
	_rect(Color(0.16, 0.18, 0.22), Vector2(LANE_X - 90, LANE_TOP - 40), Vector2(180, (LANE_BOTTOM - LANE_TOP) + 80))
	var mid_y := _progress_to_y(DEPLOY_MAX)
	_rect(Color(0.20, 0.28, 0.40, 0.25), Vector2(LANE_X - 90, mid_y), Vector2(180, LANE_BOTTOM - mid_y + 40))  # 己方半场
	_rect(Color(1, 1, 1, 0.25), Vector2(LANE_X - 90, mid_y), Vector2(180, 3))                                  # 中线

func _build_towers() -> void:
	var b = match_obj.battle
	_add_tower(b.opponent_towers[0], Vector2(LANE_X, LANE_TOP), COL_OPPONENT, 46.0)
	_add_tower(b.opponent_towers[1], Vector2(LANE_X - 200, LANE_TOP - 30), COL_OPPONENT, 34.0)
	_add_tower(b.opponent_towers[2], Vector2(LANE_X + 200, LANE_TOP - 30), COL_OPPONENT, 34.0)
	_add_tower(b.player_towers[0], Vector2(LANE_X, LANE_BOTTOM), COL_PLAYER, 46.0)
	_add_tower(b.player_towers[1], Vector2(LANE_X - 200, LANE_BOTTOM + 30), COL_PLAYER, 34.0)
	_add_tower(b.player_towers[2], Vector2(LANE_X + 200, LANE_BOTTOM + 30), COL_PLAYER, 34.0)

func _add_tower(tower, pos: Vector2, color: Color, s: float) -> void:
	var tri := Polygon2D.new()                                       # 建筑=三角
	tri.polygon = PackedVector2Array([Vector2(-s, s), Vector2(s, s), Vector2(0, -s)])
	tri.color = color
	tri.position = pos
	add_child(tri)
	var bar_w := s * 2.2
	var bar_h := 8.0
	_rect(Color(0, 0, 0, 0.6), Vector2(pos.x - bar_w / 2, pos.y - s - 18), Vector2(bar_w, bar_h))
	var fill := _rect(Color(0.3, 0.9, 0.3), Vector2(pos.x - bar_w / 2, pos.y - s - 18), Vector2(bar_w, bar_h))
	tower_bars.append({"tower": tower, "fill": fill, "full_w": bar_w, "fill_h": bar_h, "body": tri})

func _build_hud() -> void:
	var ex := 24.0
	var ey := 956.0
	var ew := 720.0 - ex * 2.0
	_rect(Color(0, 0, 0, 0.5), Vector2(ex, ey), Vector2(ew, 26))
	elixir_full_w = ew
	elixir_fill = _rect(Color(0.7, 0.3, 0.95), Vector2(ex, ey), Vector2(0, 26))
	elixir_label = _label("0", Vector2(ex + 6, ey - 2), 20)
	var n := 4
	var gap := 12.0
	var bw := (720.0 - gap * (n + 1)) / float(n)
	var by := 1000.0
	for i in n:
		var btn := Button.new()
		btn.position = Vector2(gap + i * (bw + gap), by)
		btn.size = Vector2(bw, 210)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_card_pressed.bind(i))
		add_child(btn)
		card_buttons.append(btn)
	banner = _label("", Vector2(150, 540), 64, Color(1, 1, 0.4))
	banner.visible = false

# ---------- 每帧同步 ----------
func _sync_units(delta: float) -> void:
	var lane = match_obj.battle.get_lane(0)
	var live := {}
	for u in lane.get_units():
		live[u] = true
		var off := 12.0 if u.owner_id == UnitScript.OWNER_PLAYER else -12.0
		var target := Vector2(LANE_X + off, _progress_to_y(u.progress))
		if not unit_views.has(u):
			var created := _make_unit_node(u)
			created.position = target
			unit_layer.add_child(created)
			unit_views[u] = created
		else:
			var existing = unit_views[u]
			var cur: Vector2 = existing.position
			existing.position = cur.lerp(target, minf(delta * 12.0, 1.0))
	for u in unit_views.keys():
		if not live.has(u):
			unit_views[u].queue_free()
			unit_views.erase(u)

func _make_unit_node(u) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = COL_PLAYER if u.owner_id == UnitScript.OWNER_PLAYER else COL_OPPONENT
	if float(u.attack_range) >= 0.15:                              # 远程=圆
		poly.polygon = _circle_points(15.0, 16)
	else:                                                          # 近战=方块
		poly.polygon = PackedVector2Array([Vector2(-15, -15), Vector2(15, -15), Vector2(15, 15), Vector2(-15, 15)])
	return poly

func _circle_points(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _sync_towers() -> void:
	for t in tower_bars:
		var tower = t["tower"]
		var ratio: float = (float(tower.hp) / float(tower.max_hp)) if tower.max_hp > 0.0 else 0.0
		t["fill"].size = Vector2(t["full_w"] * clampf(ratio, 0.0, 1.0), t["fill_h"])
		if tower.is_destroyed():
			t["body"].color = Color(0.3, 0.3, 0.3)

func _sync_hud() -> void:
	var p = match_obj.player
	elixir_fill.size = Vector2(elixir_full_w * clampf(p.elixir.get_amount() / p.elixir.maximum, 0.0, 1.0), 26)
	elixir_label.text = str(p.elixir.get_int())
	var hand = p.deck.get_hand()
	for i in card_buttons.size():
		var btn = card_buttons[i]
		if i < hand.size() and hand[i] != null:
			var cid := str(hand[i])
			btn.text = "%s\n[%d]" % [cid, p.card_cost(cid)]
			btn.disabled = not p.can_play(i)
			btn.modulate = Color(1, 1, 0.5) if i == selected_card else Color.WHITE
		else:
			btn.text = ""
			btn.disabled = true

func _sync_banner() -> void:
	if not match_obj.is_over():
		return
	banner.visible = true
	var r: int = match_obj.get_result()
	if r == BattleScript.RESULT_PLAYER_WIN:
		banner.text = "YOU WIN"
	elif r == BattleScript.RESULT_OPPONENT_WIN:
		banner.text = "YOU LOSE"
	else:
		banner.text = "DRAW"

# ---------- 输入：两段式出牌 ----------
func _on_card_pressed(i: int) -> void:
	selected_card = i

func _unhandled_input(event: InputEvent) -> void:
	if match_obj == null or match_obj.is_over():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_card < 0:
			return
		var progress := minf(_y_to_progress(event.position.y), DEPLOY_MAX)
		if match_obj.player.try_play_card(selected_card, 0, progress):
			selected_card = -1
