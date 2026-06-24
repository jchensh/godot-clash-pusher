extends RefCounted
##
## V4-S3 联机对战客户端（lockstep 客户端侧）。
## 流程：连 gateway → 发 JoinRoomReq(本方卡组) → 收 JoinRoomResp 建同一初始态 Match →
##       每个 TickBundle 驱动 Match.advance_tick（双方指令都来自服务端）→
##       每 HASH_EVERY tick 上报 state_hash → 本地 sim 结束上报 BattleEndReport →
##       收 BattleResultPush 出结算。
##
## 本地出兵不当场落子：send_deploy 发 DeployCmd(tick=当前+TICK_OFFSET)，等服务端把它
## 打进 TickBundle 回来，两端同 tick 落子（确定性）。
##
## ws 可注入（默认 net/ws_client.gd；单测传 fake 记录发送）。

const MatchScript := preload("res://logic/match.gd")
const WSClientScript := preload("res://net/ws_client.gd")
const _CommonPb := preload("res://net/proto/common.gd")
const _BattlePb := preload("res://net/proto/battle.gd")

const HASH_EVERY := 10     # 每 10 tick 上报一次状态哈希
const TICK_OFFSET := 2     # 出兵指令 tick = 当前 + 2（RTT 缓冲，决策 1）

signal joined(your_side: int, opponent_name: String)
signal result(winner: int, reason: int)
signal disconnected

var ws                     # WSClient 或 fake
var config                 # ConfigLoader
var match_obj              # Match（收到 JoinRoomResp 后建）
var your_side: int = 0

var _deck: Array = []
var _end_reported := false
var _playing := false


func _init(config_, ws_ = null) -> void:
	config = config_
	ws = ws_ if ws_ != null else WSClientScript.new()
	ws.frame_received.connect(_on_frame)
	ws.opened.connect(_on_opened)
	ws.closed.connect(_on_closed)


## 连接 gateway 并准备 join。token 走 query 参数鉴权。
func start(server_ws_url: String, token: String, deck: Array) -> int:
	_deck = deck
	return ws.connect_to("%s?token=%s" % [server_ws_url, token])


func poll() -> void:
	ws.poll()


# —— 连接事件 ——

func _on_opened() -> void:
	var req = _BattlePb.JoinRoomReq.new()
	for c in _deck:
		req.add_deck(str(c))
	ws.send_frame(_CommonPb.MsgId.JOIN_ROOM_REQ, req.to_bytes())


func _on_closed() -> void:
	_playing = false
	disconnected.emit()


func _on_frame(msg_id: int, payload: PackedByteArray) -> void:
	match msg_id:
		_CommonPb.MsgId.JOIN_ROOM_RESP:
			_handle_join_resp(payload)
		_CommonPb.MsgId.TICK_BUNDLE:
			_handle_tick_bundle(payload)
		_CommonPb.MsgId.BATTLE_RESULT_PUSH:
			_handle_result(payload)


# —— 消息处理 ——

func _handle_join_resp(payload: PackedByteArray) -> void:
	var resp = _BattlePb.JoinRoomResp.new()
	if resp.from_bytes(payload) != _BattlePb.PB_ERR.NO_ERRORS:
		return
	your_side = resp.get_your_side()
	# side1→player(OWNER_PLAYER)，side2→opponent(OWNER_OPPONENT)，两端一致建同一初始态。
	match_obj = MatchScript.new(config)
	match_obj.setup(resp.get_level_id(), resp.get_side1_deck(), [], resp.get_side2_deck())
	_playing = true
	_end_reported = false
	var opp_name := ""
	var opp = resp.get_opponent()
	if opp != null:
		opp_name = opp.get_nickname()
	joined.emit(your_side, opp_name)


func _handle_tick_bundle(payload: PackedByteArray) -> void:
	if match_obj == null:
		return
	var b = _BattlePb.TickBundle.new()
	if b.from_bytes(payload) != _BattlePb.PB_ERR.NO_ERRORS:
		return
	var deploys: Array = []
	for sd in b.get_deploys():
		var d = sd.get_deploy()
		if d == null:
			continue
		deploys.append({
			"side": sd.get_side(),
			"card_id": d.get_card_id(),
			"pos": Vector2(d.get_x_milli() / 1000.0, d.get_y_milli() / 1000.0),
		})
	match_obj.advance_tick(deploys)
	if match_obj.net_tick % HASH_EVERY == 0:
		_send_hash()
	if match_obj.is_over() and not _end_reported:
		_report_end()


func _send_hash() -> void:
	var up = _BattlePb.StateHashUp.new()
	up.set_tick(match_obj.net_tick)
	up.set_hash(match_obj.state_hash())
	ws.send_frame(_CommonPb.MsgId.STATE_HASH_UP, up.to_bytes())


func _report_end() -> void:
	_end_reported = true
	var b = match_obj.battle
	var winner := 0
	if b.result == b.RESULT_PLAYER_WIN:
		winner = 1
	elif b.result == b.RESULT_OPPONENT_WIN:
		winner = 2
	var king_down: bool = (b.player_king != null and b.player_king.is_destroyed()) \
		or (b.opponent_king != null and b.opponent_king.is_destroyed())
	var rep = _BattlePb.BattleEndReport.new()
	rep.set_tick(match_obj.net_tick)
	rep.set_winner(winner)
	rep.set_reason(1 if king_down else 2)   # 1=KING_DESTROYED / 2=TIMEOUT
	rep.set_side_1_score(int(b.total_tower_hp(b.player_towers)))
	rep.set_side_2_score(int(b.total_tower_hp(b.opponent_towers)))
	ws.send_frame(_CommonPb.MsgId.BATTLE_END_REPORT, rep.to_bytes())


func _handle_result(payload: PackedByteArray) -> void:
	var res = _BattlePb.BattleResultPush.new()
	if res.from_bytes(payload) != _BattlePb.PB_ERR.NO_ERRORS:
		return
	_playing = false
	result.emit(res.get_winner(), res.get_reason())


# —— 本地出兵（不当场落子，发指令等服务端广播回来）——

func send_deploy(card_id: String, pos: Vector2) -> void:
	if match_obj == null or not _playing:
		return
	var d = _BattlePb.DeployCmd.new()
	d.set_tick(match_obj.net_tick + TICK_OFFSET)
	d.set_card_id(card_id)
	d.set_x_milli(int(round(pos.x * 1000.0)))
	d.set_y_milli(int(round(pos.y * 1000.0)))
	ws.send_frame(_CommonPb.MsgId.DEPLOY_CMD, d.to_bytes())


## 本地玩家对应的 Player（按 your_side），供 view 读手牌/圣水。
func local_player():
	if match_obj == null:
		return null
	return match_obj.player if your_side == 1 else match_obj.opponent
