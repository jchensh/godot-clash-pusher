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
const _MatchPb := preload("res://net/proto/match.gd")

const HASH_EVERY := 10           # 每 10 tick 上报一次状态哈希
const TICK_OFFSET := 2           # 出兵指令 tick = 当前 + 2（RTT 缓冲，决策 1）
const HEARTBEAT_INTERVAL := 5.0  # 每 5s 发一次心跳（服务端 30s 无活动判掉线）
const RECONNECT_RETRY := 2.0     # 断线后每 2s 重试一次连接
const RECONNECT_MAX := 60.0      # 重连窗口（对齐服务端 room TTL）；超过则放弃

signal matched(your_side: int, opponent_name: String)  # 匹配到对手（MatchFound）
signal joined(your_side: int, opponent_name: String)   # 进房建好 Match（JoinRoomResp）
signal result(winner: int, reason: int)
signal reconnecting            # 断线、正在重连中（UI 提示）
signal disconnected            # 重连窗口耗尽、彻底掉线
signal deploy_applied(side: int, card_id: String, pos: Vector2)  # 某条出兵指令两端同 tick 落子 → view 触发 FX/音效

var ws                     # WSClient 或 fake
var config                 # ConfigLoader
var match_obj              # Match（收到 JoinRoomResp 后建）
var your_side: int = 0

var _deck_slot: int = 1
var _room_id := ""             # MatchFound 给的房间号；非空=已匹配（重连走 JoinRoom）
var _ws_url := ""
var _token := ""
var _end_reported := false
var _playing := false
var _ended := false              # 收到结算（正常结束，不再重连）
var _started := false            # 至少 join 过一次（才需断线重连）
var _hb_accum := 0.0
var _reconnecting := false
var _reconnect_accum := 0.0
var _reconnect_elapsed := 0.0


func _init(config_, ws_ = null) -> void:
	config = config_
	ws = ws_ if ws_ != null else WSClientScript.new()
	ws.frame_received.connect(_on_frame)
	ws.opened.connect(_on_opened)
	ws.closed.connect(_on_closed)


## 连接 gateway 并准备匹配。token 走 query 参数鉴权;deck_slot = 用哪个卡组槽(1..3)。
func start(server_ws_url: String, token: String, deck_slot: int = 1) -> int:
	_ws_url = server_ws_url
	_token = token
	_deck_slot = deck_slot
	print("[net] 连接 + 匹配中 (卡组槽 %d)" % deck_slot)
	return ws.connect_to(_full_url())


func _full_url() -> String:
	return "%s?token=%s" % [_ws_url, _token]


## 每帧调用（传入帧时间）：推进 WS + 心跳 + 断线自动重连。
func poll(delta: float = 0.0) -> void:
	ws.poll()
	if _ended:
		return
	if _playing and ws.is_open():
		_hb_accum += delta
		if _hb_accum >= HEARTBEAT_INTERVAL:
			_hb_accum = 0.0
			_send_heartbeat()
	if _reconnecting:
		_reconnect_elapsed += delta
		_reconnect_accum += delta
		if _reconnect_elapsed > RECONNECT_MAX:
			_reconnecting = false
			disconnected.emit()
		elif _reconnect_accum >= RECONNECT_RETRY:
			_reconnect_accum = 0.0
			ws.connect_to(_full_url())


# —— 连接事件 ——

func _on_opened() -> void:
	if _room_id == "":
		# 首次连上 → 发 FindMatch 入队匹配。
		print("[net] 已连上 gateway，发送 FindMatch（卡组槽=%d，arena=1）" % _deck_slot)
		var req = _MatchPb.FindMatchReq.new()
		req.set_deck_slot(_deck_slot)
		req.set_arena(1)
		ws.send_frame(_CommonPb.MsgId.FIND_MATCH_REQ, req.to_bytes())
	else:
		# 已匹配后断线重连 → 用 room_id 回到原房。
		print("[net] 重连已连上，发送 JoinRoom（房=%s）回原局" % _room_id)
		var jr = _BattlePb.JoinRoomReq.new()
		jr.set_room_id(_room_id)
		ws.send_frame(_CommonPb.MsgId.JOIN_ROOM_REQ, jr.to_bytes())


func _on_closed() -> void:
	if _ended:
		return
	if not _started:
		print("[net] 连接关闭（尚未进房，多为匹配前连不上服务器/被拒）→ 掉线")
		disconnected.emit()   # 还没 join 成功就断 → 直接报掉线
		return
	if not _reconnecting:
		# 对战中断线 → 进入重连窗口，poll 会按 RECONNECT_RETRY 重试连接。
		_reconnecting = true
		_reconnect_accum = 0.0
		_reconnect_elapsed = 0.0
		print("[net] 连接中断, 重连中…")
		reconnecting.emit()


func _send_heartbeat() -> void:
	var hb = _BattlePb.HeartbeatPing.new()
	hb.set_client_time(Time.get_ticks_msec())
	ws.send_frame(_CommonPb.MsgId.HEARTBEAT_PING, hb.to_bytes())


func _on_frame(msg_id: int, payload: PackedByteArray) -> void:
	match msg_id:
		_CommonPb.MsgId.MATCH_FOUND_PUSH:
			_handle_match_found(payload)
		_CommonPb.MsgId.JOIN_ROOM_RESP:
			_handle_join_resp(payload)
		_CommonPb.MsgId.TICK_BUNDLE:
			_handle_tick_bundle(payload)
		_CommonPb.MsgId.BATTLE_RESULT_PUSH:
			_handle_result(payload)


func _handle_match_found(payload: PackedByteArray) -> void:
	var mf = _MatchPb.MatchFoundPush.new()
	if mf.from_bytes(payload) != _MatchPb.PB_ERR.NO_ERRORS:
		print("[net] ⚠ MatchFoundPush 解析失败，丢弃")
		return
	_room_id = mf.get_room_id()   # 非空后,断线重连走 JoinRoom(room_id)
	var opp_name := ""
	var opp = mf.get_opponent()
	if opp != null:
		opp_name = opp.get_nickname()
	print("[net] 已匹配: 对手=%s 我方=%d 房间=%s" % [opp_name, mf.get_your_side(), _room_id])
	matched.emit(mf.get_your_side(), opp_name)


## 匹配中取消(退队)。服务端按账号出队,不需要 queue_id。
func cancel_match() -> void:
	print("[net] 发送取消匹配（退队）")
	ws.send_frame(_CommonPb.MsgId.CANCEL_MATCH_REQ, _MatchPb.CancelMatchReq.new().to_bytes())


# —— 消息处理 ——

func _handle_join_resp(payload: PackedByteArray) -> void:
	var resp = _BattlePb.JoinRoomResp.new()
	if resp.from_bytes(payload) != _BattlePb.PB_ERR.NO_ERRORS:
		print("[net] ⚠ JoinRoomResp 解析失败，丢弃")
		return
	your_side = resp.get_your_side()
	# side1→player(OWNER_PLAYER)，side2→opponent(OWNER_OPPONENT)，两端一致建同一初始态。
	match_obj = MatchScript.new(config)
	match_obj.setup(resp.get_level_id(), resp.get_side1_deck(), [], resp.get_side2_deck())
	_playing = true
	_end_reported = false
	_started = true
	_reconnecting = false
	_hb_accum = 0.0
	var opp_name := ""
	var opp = resp.get_opponent()
	if opp != null:
		opp_name = opp.get_nickname()
	print("[net] 进房, 我方=%d, 开打" % your_side)
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
	# 两端收到同一份 TickBundle → 同 tick 广播落子事件，让 view 双端对齐触发 FX/音效
	# （含本方自己的指令，服务端会回广播；纯表现层，不影响 sim/hash）。
	for dp in deploys:
		deploy_applied.emit(dp["side"], dp["card_id"], dp["pos"])
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
	_ended = true
	_reconnecting = false
	print("[net] 对局结束: winner=%d reason=%d" % [res.get_winner(), res.get_reason()])
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
