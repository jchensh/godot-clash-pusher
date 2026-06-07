# BattleScene —— 显示层（白膜）。V2-2：3 lane + 出牌选 lane。
#
# 只读 Match 的逻辑状态作画；出牌一律经 player.try_play_card（玩家/AI 对称）。
# 逻辑坐标 0~1 → 像素的映射只活在本层：progress 0=己方塔在屏幕下，1=敌方塔在上。
# 3 条 lane（左公主/中王/右公主）；对手由规则 AI 自驱（固定中路）。
# 两段式出牌：先点手牌，再点己方半场落点——落点 lane 由点击 x 最近列决定、progress 由 y 决定。
extends Node2D

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const UnitScript = preload("res://logic/unit.gd")
const BattleScript = preload("res://logic/battle.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")

const LANE_TOP := 240.0       # progress 1 = 敌方塔
const LANE_BOTTOM := 940.0    # progress 0 = 己方塔
const LANE_XS := [160.0, 360.0, 560.0]   # lane 0 左 / 1 中 / 2 右 的列中心 x
const LANE_HALF_W := 70.0     # 每条 lane 列半宽（用于画道与判定点击归属）
const DEPLOY_MAX := 0.5       # 落点限己方半场

const COL_PLAYER := Color(0.35, 0.55, 1.0)
const COL_OPPONENT := Color(1.0, 0.42, 0.38)

# 程序化换皮（V2-3，仅显示层）：每个兵种一套形状+尺寸，队伍色仍区分敌我。
# 阵营色作主体填充→看色辨敌我；形状/大小→看形辨兵种；朝向按推进方向翻转。
const UNIT_VIS := {
	"giant_body":  {"shape": "octagon",  "size": 24.0},   # 巨人：最大八边形
	"knight_body": {"shape": "shield",   "size": 16.0},   # 骑士：盾形
	"archer_body": {"shape": "circle",   "size": 12.0},   # 弓箭手：小圆（远程）
	"goblin_body": {"shape": "triangle", "size": 12.0},   # 哥布林：小尖三角（快）
	"minion_body": {"shape": "diamond",  "size": 13.0},   # 亡灵：菱形 + 翅膀（空中）
}

const LOG_EVENTS := true      # 运行期把战局事件打到 Output 面板（仅显示层，不入逻辑/单测）

var match_obj
var selected_card := -1

var _result_logged := false
var _tower_hit := {}          # tower -> true（首次受伤已记）
var _tower_down := {}         # tower -> true（摧毁已记）

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
	match_obj.set_opponent_controller(AIControllerScript.new(match_obj, loader))  # 接入规则 AI
	_build_field()
	unit_layer = Node2D.new()
	add_child(unit_layer)
	_build_towers()
	_build_hud()
	_log("MATCH START  level_01 | 3 lane | AI=固定中路")

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
	_rect(Color(0.09, 0.12, 0.10, 1.0), Vector2(0, 0), Vector2(720, 1280))   # 草绿底
	var mid_y := _progress_to_y(DEPLOY_MAX)
	# 敌/我半场淡色分区（整屏）
	_rect(Color(0.55, 0.30, 0.28, 0.10), Vector2(0, LANE_TOP - 60), Vector2(720, mid_y - (LANE_TOP - 60)))   # 敌方半场淡红
	_rect(Color(0.28, 0.40, 0.62, 0.10), Vector2(0, mid_y), Vector2(720, (LANE_BOTTOM + 60) - mid_y))         # 己方半场淡蓝
	# 三条 lane 通道
	for lx in LANE_XS:
		var x0: float = lx - LANE_HALF_W
		_rect(Color(0.18, 0.22, 0.18, 1.0), Vector2(x0, LANE_TOP - 40), Vector2(LANE_HALF_W * 2.0, (LANE_BOTTOM - LANE_TOP) + 80))
		_rect(Color(0, 0, 0, 0.18), Vector2(x0, LANE_TOP - 40), Vector2(3, (LANE_BOTTOM - LANE_TOP) + 80))                            # 通道左描边
		_rect(Color(0, 0, 0, 0.18), Vector2(x0 + LANE_HALF_W * 2.0 - 3, LANE_TOP - 40), Vector2(3, (LANE_BOTTOM - LANE_TOP) + 80))    # 右描边
	# 河（横贯中线）+ 每条 lane 一段木桥（部署分界线的视觉化）
	_rect(Color(0.16, 0.42, 0.62, 0.85), Vector2(0, mid_y - 16), Vector2(720, 32))
	for lx in LANE_XS:
		_rect(Color(0.45, 0.34, 0.22, 1.0), Vector2(lx - LANE_HALF_W * 0.75, mid_y - 19), Vector2(LANE_HALF_W * 1.5, 38))   # 桥面
		_rect(Color(0.30, 0.22, 0.14, 1.0), Vector2(lx - LANE_HALF_W * 0.75, mid_y - 19), Vector2(LANE_HALF_W * 1.5, 3))     # 桥沿

# towers 数组顺序（build_v2_three_lanes）：[0]=王塔(中) [1]=左公主 [2]=右公主。
func _build_towers() -> void:
	var b = match_obj.battle
	_add_tower(b.opponent_towers[0], Vector2(LANE_XS[1], LANE_TOP), COL_OPPONENT, 46.0, "王塔(中)")
	_add_tower(b.opponent_towers[1], Vector2(LANE_XS[0], LANE_TOP), COL_OPPONENT, 34.0, "公主(左)")
	_add_tower(b.opponent_towers[2], Vector2(LANE_XS[2], LANE_TOP), COL_OPPONENT, 34.0, "公主(右)")
	_add_tower(b.player_towers[0], Vector2(LANE_XS[1], LANE_BOTTOM), COL_PLAYER, 46.0, "王塔(中)")
	_add_tower(b.player_towers[1], Vector2(LANE_XS[0], LANE_BOTTOM), COL_PLAYER, 34.0, "公主(左)")
	_add_tower(b.player_towers[2], Vector2(LANE_XS[2], LANE_BOTTOM), COL_PLAYER, 34.0, "公主(右)")

# 塔=方形塔身；王塔顶部城垛（3 块），公主塔尖顶。队伍色填充。
func _add_tower(tower, pos: Vector2, color: Color, s: float, tname: String = "") -> void:
	var root := Node2D.new()
	root.position = pos
	add_child(root)
	# 轮廓（略大，垫底）
	var ol := Polygon2D.new()
	ol.polygon = PackedVector2Array([Vector2(-s * 0.95, -s * 0.45), Vector2(s * 0.95, -s * 0.45), Vector2(s * 0.95, s * 1.05), Vector2(-s * 0.95, s * 1.05)])
	ol.color = color.darkened(0.55)
	root.add_child(ol)
	# 塔身
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([Vector2(-s * 0.8, -s * 0.3), Vector2(s * 0.8, -s * 0.3), Vector2(s * 0.8, s), Vector2(-s * 0.8, s)])
	base.color = color
	root.add_child(base)
	if tower.is_king():
		for k in 3:                                                  # 城垛
			var bx := -s * 0.55 + k * s * 0.55
			var cren := Polygon2D.new()
			cren.polygon = PackedVector2Array([Vector2(bx - s * 0.16, -s * 0.62), Vector2(bx + s * 0.16, -s * 0.62), Vector2(bx + s * 0.16, -s * 0.3), Vector2(bx - s * 0.16, -s * 0.3)])
			cren.color = color
			root.add_child(cren)
	else:
		var roof := Polygon2D.new()                                  # 尖顶
		roof.polygon = PackedVector2Array([Vector2(-s * 0.85, -s * 0.3), Vector2(s * 0.85, -s * 0.3), Vector2(0, -s * 0.95)])
		roof.color = color.lightened(0.12)
		root.add_child(roof)
	var bar_w := s * 2.2
	var bar_h := 8.0
	_rect(Color(0, 0, 0, 0.6), Vector2(pos.x - bar_w / 2, pos.y - s - 18), Vector2(bar_w, bar_h))
	var fill := _rect(Color(0.3, 0.9, 0.3), Vector2(pos.x - bar_w / 2, pos.y - s - 18), Vector2(bar_w, bar_h))
	tower_bars.append({"tower": tower, "fill": fill, "full_w": bar_w, "fill_h": bar_h, "body": root, "name": tname})

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
	var live := {}
	for li in range(LANE_XS.size()):
		var lane = match_obj.battle.get_lane(li)
		if lane == null:
			continue
		for u in lane.get_units():
			live[u] = true
			var off := 12.0 if u.owner_id == UnitScript.OWNER_PLAYER else -12.0
			var target := Vector2(LANE_XS[li] + off, _progress_to_y(u.progress))
			if not unit_views.has(u):
				var created := _make_unit_node(u)
				created.position = target
				unit_layer.add_child(created)
				unit_views[u] = created
				_log("SPAWN %s %s lane%d p=%.2f" % [_side(u.owner_id), u.unit_id, li, u.progress])
			else:
				var existing = unit_views[u]
				var cur: Vector2 = existing.position
				existing.position = cur.lerp(target, minf(delta * 12.0, 1.0))
	for u in unit_views.keys():
		if not live.has(u):
			_log("DEATH %s %s lane%d p=%.2f" % [_side(u.owner_id), u.unit_id, u.lane_index, u.progress])
			unit_views[u].queue_free()
			unit_views.erase(u)

func _make_unit_node(u) -> Node2D:
	var root := Node2D.new()
	var is_player: bool = u.owner_id == UnitScript.OWNER_PLAYER
	var team: Color = COL_PLAYER if is_player else COL_OPPONENT
	var vis: Dictionary = UNIT_VIS.get(u.unit_id, {"shape": "circle", "size": 14.0})
	var s: float = float(vis["size"])
	var is_air: bool = str(u.target_type) == "air"

	# 空中单位：地面留阴影，机体抬高（一眼区分地空）
	if is_air:
		var shadow := Polygon2D.new()
		shadow.polygon = _circle_points(s * 0.55, 12)
		shadow.color = Color(0, 0, 0, 0.22)
		shadow.position = Vector2(0, s * 0.95)
		root.add_child(shadow)

	var gfx := Node2D.new()
	if is_air:
		gfx.position = Vector2(0, -s * 0.5)
	root.add_child(gfx)

	var pts := _unit_shape(str(vis["shape"]), s)
	if not is_player:
		pts = _flip_y(pts)                                          # 对手朝向翻转（向下推进）

	if u.unit_id == "minion_body":                                  # 亡灵翅膀
		for sx in [-1.0, 1.0]:
			var wing := Polygon2D.new()
			wing.polygon = PackedVector2Array([Vector2(sx * s * 0.5, -s * 0.35), Vector2(sx * s * 1.25, -s * 0.05), Vector2(sx * s * 0.5, s * 0.35)])
			wing.color = team.lightened(0.25)
			gfx.add_child(wing)

	var outline := Polygon2D.new()                                  # 描边
	outline.polygon = _scale_pts(pts, 1.2)
	outline.color = team.darkened(0.55)
	gfx.add_child(outline)

	var body := Polygon2D.new()                                     # 主体（队伍色）
	body.polygon = pts
	body.color = team
	gfx.add_child(body)

	if u.unit_id == "giant_body":                                   # 巨人内圈铠甲
		var core := Polygon2D.new()
		core.polygon = _scale_pts(pts, 0.5)
		core.color = team.darkened(0.3)
		gfx.add_child(core)
	elif u.unit_id == "archer_body":                                # 弓箭手远程标记
		var dot := Polygon2D.new()
		dot.polygon = _circle_points(s * 0.32, 8)
		dot.color = Color(1, 1, 1, 0.85)
		gfx.add_child(dot)
	return root

# 兵种基础形状（apex 朝上 -y；朝向由调用方按阵营翻转）。
func _unit_shape(shape: String, s: float) -> PackedVector2Array:
	match shape:
		"octagon":
			var p := PackedVector2Array()
			for i in 8:
				var a := PI / 8.0 + TAU * float(i) / 8.0
				p.append(Vector2(cos(a), sin(a)) * s)
			return p
		"shield":
			return PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s * 0.4), Vector2(0, s * 1.15), Vector2(-s, s * 0.4)])
		"triangle":
			return PackedVector2Array([Vector2(0, -s * 1.1), Vector2(s, s * 0.8), Vector2(-s, s * 0.8)])
		"diamond":
			return PackedVector2Array([Vector2(0, -s), Vector2(s * 0.75, 0), Vector2(0, s), Vector2(-s * 0.75, 0)])
		_:
			return _circle_points(s, 16)

func _flip_y(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x, -p.y))
	return out

func _scale_pts(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out

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
			t["body"].modulate = Color(0.4, 0.4, 0.4)
		if not _tower_hit.has(tower) and tower.hp < tower.max_hp and not tower.is_destroyed():
			_tower_hit[tower] = true
			_log("TOWER HIT  %s %s (hp %d/%d)" % [_side(tower.owner_id), t["name"], int(tower.hp), int(tower.max_hp)])
		if tower.is_destroyed() and not _tower_down.has(tower):
			_tower_down[tower] = true
			_log("TOWER DOWN %s %s" % [_side(tower.owner_id), t["name"]])

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
	if not _result_logged:
		_result_logged = true
		var b = match_obj.battle
		_log("RESULT %s | 我方塔血=%d 敌方塔血=%d" % [banner.text, int(b.total_tower_hp(b.player_towers)), int(b.total_tower_hp(b.opponent_towers))])

# ---------- 输入：两段式出牌 ----------
func _on_card_pressed(i: int) -> void:
	selected_card = i
	var hand = match_obj.player.deck.get_hand()
	if i >= 0 and i < hand.size() and hand[i] != null:
		_log("SELECT 手牌[%d] %s" % [i, str(hand[i])])

# 点击 x 归属到最近的 lane 列。
func _lane_from_x(x: float) -> int:
	var best := 0
	var best_d := INF
	for i in range(LANE_XS.size()):
		var d: float = absf(x - float(LANE_XS[i]))
		if d < best_d:
			best_d = d
			best = i
	return best

func _unhandled_input(event: InputEvent) -> void:
	if match_obj == null or match_obj.is_over():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_card < 0:
			return
		var lane_index := _lane_from_x(event.position.x)
		var progress := minf(_y_to_progress(event.position.y), DEPLOY_MAX)
		var p = match_obj.player
		var hand = p.deck.get_hand()
		var cid := str(hand[selected_card]) if selected_card < hand.size() and hand[selected_card] != null else "?"
		var before: int = p.elixir.get_int()
		if p.try_play_card(selected_card, lane_index, progress):
			_log("PLAY  我方 %s → lane%d p=%.2f | 圣水 %d→%d" % [cid, lane_index, progress, before, p.elixir.get_int()])
			selected_card = -1
		else:
			var reason := "圣水不足" if not p.can_play(selected_card) else "落点非法"
			_log("PLAY  我方 %s → lane%d 被拒(%s)" % [cid, lane_index, reason])

# ---------- 运行期事件日志（仅显示层；逻辑层与 headless 单测不受影响）----------
func _log(msg: String) -> void:
	if not LOG_EVENTS:
		return
	var t := 0.0
	if match_obj != null and match_obj.battle != null:
		t = match_obj.battle.elapsed
	print("[战局 %6.1fs] %s" % [t, msg])

func _side(owner_id: int) -> String:
	return "我方" if owner_id == UnitScript.OWNER_PLAYER else "敌方"
