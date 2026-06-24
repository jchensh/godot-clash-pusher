extends Node2D
# NetBattleScene —— V4-S3 联机对战场景（slim 功能版；视觉/手感打磨留后）。
#
# 流程：匿名登录(device_id) → 连 gateway → 等配对 → lockstep 对战 → 结算。
# 渲染只读 battle_client.match_obj 的逻辑状态作画（与单机 battle_scene 同理念，但精简）。
# 本地出兵走 battle_client.send_deploy（不当场落子，等服务端把指令广播回来两端同 tick 落子）。
# 视角：side 2 整场 180° 翻转，让本方半场永远在屏幕下方（对称体验）。
#
# 单机训练营 battle_scene.gd 完全不受影响（这是独立新场景）。

const ConfigLoaderScript := preload("res://logic/config_loader.gd")
const AuthScript := preload("res://net/auth.gd")
const BattleClientScript := preload("res://net/battle_client.gd")
const MainMenuScene := "res://view/main_menu.tscn"

const DEFAULT_DECK := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]
const TOPBAR_H := 54.0
const HUD_BOTTOM_H := 176.0
const DROP_LIFT_TILES := 1.6

const COL_BG := Color(0.10, 0.12, 0.11)
const COL_SELF := Color(0.35, 0.60, 1.0)
const COL_FOE := Color(1.0, 0.42, 0.38)
const COL_ELIXIR := Color(0.80, 0.33, 0.96)
const COL_PANEL := Color(0.10, 0.08, 0.14, 0.96)
const COL_OK := Color(0.45, 1.0, 0.55)
const COL_BAD := Color(1.0, 0.42, 0.40)

var _loader
var _auth
var _client
var _http: HTTPRequest
var _font: Font
var _status := "连接中…"
var _flip := false
var _result_text := ""
var _selected := -1
var _dragging := false
var _drag_screen := Vector2.ZERO
var _card_btns: Array = []

@onready var _vw: float = float(get_viewport_rect().size.x)
@onready var _vh: float = float(get_viewport_rect().size.y)


func _ready() -> void:
	_font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
	_loader = ConfigLoaderScript.new()
	_loader.load_all()
	_http = HTTPRequest.new()
	add_child(_http)
	set_process(true)
	_connect_flow()


func _connect_flow() -> void:
	var net := _load_network()
	_auth = AuthScript.new(net.get("api_url", "http://localhost:8080"))
	_status = "登录中…"
	var lr = await _auth.login(_http)
	if not lr.ok:
		_status = "登录失败：%s" % lr.error
		return
	_status = "等待对手…"
	_client = BattleClientScript.new(_loader)
	_client.joined.connect(_on_joined)
	_client.result.connect(_on_result)
	_client.disconnected.connect(_on_disconnected)
	_client.start(net.get("ws_url", "ws://localhost:8081/v4/battle/ws"), _auth.access_token, DEFAULT_DECK)


func _load_network() -> Dictionary:
	var f := FileAccess.open("res://config/network.json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _on_joined(your_side: int, opponent_name: String) -> void:
	_flip = your_side == 2
	_status = ""
	if opponent_name != "":
		_status = "对手：%s" % opponent_name
	_build_cards()


func _on_result(winner: int, _reason: int) -> void:
	var mine := 1 if not _flip else 2
	if winner == 0:
		_result_text = "平局"
	elif winner == mine:
		_result_text = "胜利！"
	else:
		_result_text = "失败"


func _on_disconnected() -> void:
	if _result_text == "":
		_status = "连接断开"


func _process(_delta: float) -> void:
	if _client != null:
		_client.poll()
	if _dragging:
		_drag_screen = get_viewport().get_mouse_position()
	queue_redraw()


# —— 坐标映射（side 2 翻转）——
func _field_rect() -> Rect2:
	return Rect2(0.0, TOPBAR_H, _vw, _vh - TOPBAR_H - HUD_BOTTOM_H)

func _t2s(p: Vector2) -> Vector2:
	var a = _client.match_obj.battle.arena
	var x: float = (a.grid_w - p.x) if _flip else p.x
	var y: float = (a.grid_h - p.y) if _flip else p.y
	var fr := _field_rect()
	return Vector2(fr.position.x + x / a.grid_w * fr.size.x, fr.position.y + y / a.grid_h * fr.size.y)

func _s2t(s: Vector2) -> Vector2:
	var a = _client.match_obj.battle.arena
	var fr := _field_rect()
	var x: float = (s.x - fr.position.x) / fr.size.x * a.grid_w
	var y: float = (s.y - fr.position.y) / fr.size.y * a.grid_h
	if _flip:
		x = a.grid_w - x
		y = a.grid_h - y
	return Vector2(x, y)

func _tile_px() -> Vector2:
	var a = _client.match_obj.battle.arena
	var fr := _field_rect()
	return Vector2(fr.size.x / a.grid_w, fr.size.y / a.grid_h)


# —— 绘制 ——
func _draw() -> void:
	draw_rect(Rect2(0, 0, _vw, _vh), COL_BG)
	if _client == null or _client.match_obj == null:
		_text(Vector2(_vw * 0.5 - 80, _vh * 0.5), _status, Color.WHITE, 24)
		return
	var a = _client.match_obj.battle.arena
	_draw_field(a)
	_draw_towers()
	_draw_units(a)
	_draw_drag_ghost(a)
	# 顶栏
	draw_rect(Rect2(0, 0, _vw, TOPBAR_H), COL_PANEL)
	var t: float = _client.match_obj.battle.remaining_time()
	_text(Vector2(_vw * 0.5 - 30, 34), "%d:%02d" % [int(t) / 60, int(t) % 60], Color.WHITE, 22)
	if _status != "":
		_text(Vector2(12, 34), _status, COL_MUTED(), 16)
	# 底部 HUD
	draw_rect(Rect2(0, _vh - HUD_BOTTOM_H, _vw, HUD_BOTTOM_H), COL_PANEL)
	_draw_elixir()
	_draw_cards()
	if _result_text != "":
		draw_rect(Rect2(0, 0, _vw, _vh), Color(0, 0, 0, 0.6))
		_text(Vector2(_vw * 0.5 - 70, _vh * 0.5), _result_text, Color(1, 0.9, 0.4), 48)
		_text(Vector2(_vw * 0.5 - 90, _vh * 0.5 + 60), "点击返回主菜单", Color.WHITE, 20)

func COL_MUTED() -> Color:
	return Color(0.7, 0.7, 0.75)

func _draw_field(a) -> void:
	var fr := _field_rect()
	# 本方半场（屏幕下方）淡绿提示
	draw_rect(Rect2(fr.position.x, fr.position.y + fr.size.y * 0.5, fr.size.x, fr.size.y * 0.5), Color(0.3, 0.7, 0.45, 0.07))
	# 河（中线）
	draw_rect(Rect2(fr.position.x, fr.position.y + fr.size.y * 0.5 - 6.0, fr.size.x, 12.0), Color(0.2, 0.4, 0.7, 0.5))

func _draw_towers() -> void:
	var tp := _tile_px()
	for side in [_client.match_obj.battle.player_towers, _client.match_obj.battle.opponent_towers]:
		for t in side:
			var mine: bool = (t.owner_id == 0 and not _flip) or (t.owner_id == 1 and _flip)
			var col: Color = COL_SELF if mine else COL_FOE
			var c := _t2s(t.pos)
			var w: float = t.fw * tp.x
			var h: float = t.fh * tp.y
			if t.is_destroyed():
				draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h * 0.4), Color(0.3, 0.28, 0.26, 0.9))
				continue
			draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), col.darkened(0.2))
			draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), col, false, 2.0)
			var ratio: float = clampf(t.hp / t.max_hp, 0.0, 1.0)
			draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5 - 7.0, w, 4.0), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(c.x - w * 0.5, c.y - h * 0.5 - 7.0, w * ratio, 4.0), Color(0.3, 0.85, 0.35))

func _draw_units(a) -> void:
	var tp := _tile_px()
	var ur: float = (tp.x + tp.y) * 0.5
	for u in a.get_units():
		if not u.is_alive():
			continue
		var mine: bool = (u.owner_id == 0 and not _flip) or (u.owner_id == 1 and _flip)
		var col: Color = COL_SELF if mine else COL_FOE
		var c := _t2s(u.pos)
		var rad: float = maxf(ur * 0.4, 6.0)
		draw_circle(c, rad, col)
		draw_arc(c, rad, 0.0, TAU, 18, col.darkened(0.4), 2.0)
		if u.target_type == "air":
			draw_arc(c, rad + 3.0, 0.0, TAU, 18, Color(1, 1, 1, 0.7), 1.5)
		var ratio: float = clampf(u.hp / u.max_hp, 0.0, 1.0)
		if ratio < 1.0:
			draw_rect(Rect2(c.x - rad, c.y - rad - 5.0, rad * 2.0, 3.0), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(c.x - rad, c.y - rad - 5.0, rad * 2.0 * ratio, 3.0), Color(0.3, 0.85, 0.35))


# —— 出牌（拖拽）——
func _drop_tile() -> Vector2:
	var lift: float = _tile_px().y * DROP_LIFT_TILES
	return _s2t(_drag_screen + Vector2(0.0, -lift))

func _is_spawn(cid) -> bool:
	for sk in _loader.get_card(cid).get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

func _draw_drag_ghost(a) -> void:
	if not _dragging or _selected < 0 or _result_text != "":
		return
	var lp = _client.local_player()
	if lp == null:
		return
	var hand: Array = lp.deck.get_hand()
	if _selected >= hand.size() or hand[_selected] == null:
		return
	var cid := str(hand[_selected])
	var drop: Vector2 = _drop_tile()
	var owner_id: int = _client.your_side - 1
	var legal: bool = a.can_deploy(owner_id, drop) if _is_spawn(cid) else true
	var col: Color = COL_OK if legal else COL_BAD
	var c := _t2s(drop)
	var ur: float = (_tile_px().x + _tile_px().y) * 0.5
	draw_arc(c, ur * 0.9, 0.0, TAU, 24, col, 2.5)

func _build_cards() -> void:
	for b in _card_btns:
		b.queue_free()
	_card_btns.clear()
	var n := 4
	var bw := (_vw - 16.0 * (n + 1)) / n
	for i in n:
		var b := Button.new()
		b.position = Vector2(16.0 + i * (bw + 16.0), _vh - HUD_BOTTOM_H + 40.0)
		b.size = Vector2(bw, HUD_BOTTOM_H - 56.0)
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_down.connect(_on_card_down.bind(i))
		b.button_up.connect(_on_card_up.bind(i))
		add_child(b)
		_card_btns.append(b)

func _on_card_down(i: int) -> void:
	if _result_text != "":
		return
	_selected = i
	_dragging = true
	_drag_screen = get_viewport().get_mouse_position()

func _on_card_up(i: int) -> void:
	var was := _dragging
	var sc := _selected
	_dragging = false
	_selected = -1
	if not was or sc != i or _client == null or _client.match_obj == null or _result_text != "":
		return
	var screen: Vector2 = get_viewport().get_mouse_position()
	if screen.y < TOPBAR_H or screen.y > _vh - HUD_BOTTOM_H:
		return
	var lp = _client.local_player()
	if lp == null:
		return
	var hand: Array = lp.deck.get_hand()
	if sc >= hand.size() or hand[sc] == null:
		return
	var cid := str(hand[sc])
	if not lp.can_play(sc):
		return
	# 兵牌落点须己方半场合法（法术不限）；非法不发。
	var drop: Vector2 = _drop_tile()
	if _is_spawn(cid) and not _client.match_obj.battle.arena.can_deploy(_client.your_side - 1, drop):
		return
	_client.send_deploy(cid, drop)

func _draw_elixir() -> void:
	var lp = _client.local_player()
	if lp == null:
		return
	var e = lp.elixir
	var amt: float = e.get_amount()
	var mx: int = 10
	var y := _vh - HUD_BOTTOM_H + 12.0
	var x0 := 16.0
	var total_w := _vw - 32.0
	var gap := 3.0
	var pip_w: float = (total_w - gap * (mx - 1)) / mx
	for i in mx:
		var px := x0 + i * (pip_w + gap)
		draw_rect(Rect2(px, y, pip_w, 18.0), Color(0.10, 0.05, 0.12, 0.85))
		var fillf: float = clampf(amt - float(i), 0.0, 1.0)
		if fillf > 0.0:
			draw_rect(Rect2(px, y, pip_w * fillf, 18.0), COL_ELIXIR)
	_text(Vector2(x0 + 4, y + 15.0), "%d" % e.get_int(), Color.WHITE, 13)

func _draw_cards() -> void:
	var lp = _client.local_player()
	if lp == null:
		return
	var hand: Array = lp.deck.get_hand()
	for i in _card_btns.size():
		var b: Button = _card_btns[i]
		var rect := Rect2(b.position - Vector2(0, 14.0 if (_dragging and i == _selected) else 0.0), b.size)
		draw_rect(rect, Color(0.23, 0.21, 0.32, 0.96))
		if i < hand.size() and hand[i] != null:
			var cid := str(hand[i])
			var affordable: bool = lp.can_play(i)
			_text(rect.position + Vector2(8, 26), tr("card_" + cid), Color.WHITE if affordable else Color(0.6, 0.6, 0.66), 15)
			var cost: int = lp.card_cost(cid)
			draw_circle(rect.position + Vector2(rect.size.x - 16, 18), 9.0, COL_ELIXIR)
			_text(rect.position + Vector2(rect.size.x - 19, 23), "%d" % cost, Color.WHITE, 12)

func _text(pos: Vector2, s: String, col: Color, size: int) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _unhandled_input(event: InputEvent) -> void:
	if _result_text != "" and event is InputEventMouseButton and event.pressed:
		get_tree().change_scene_to_file(MainMenuScene)
