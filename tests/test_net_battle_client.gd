extends "res://tests/test_case.gd"

## V4-S3d 客户端网络层单测（无真 socket）：
## WS 帧编解码（大端）+ battle_client 收 JoinRoomResp 建 Match + TickBundle 驱动 advance_tick
## + 每 10 tick 上报哈希 + send_deploy 用 (当前 tick + 2)。
## fake ws 记录所有 send_frame，无需连服务端。

const BattleClient := preload("res://net/battle_client.gd")
const WSClient := preload("res://net/ws_client.gd")
const CommonPb := preload("res://net/proto/common.gd")
const BattlePb := preload("res://net/proto/battle.gd")
const MatchPb := preload("res://net/proto/match.gd")
const ConfigLoaderScript := preload("res://logic/config_loader.gd")

const DECK := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]


# —— 记录发送的 fake ws（带 battle_client 需要的三个信号）——
class FakeWS extends RefCounted:
	signal opened
	signal closed
	signal frame_received(msg_id: int, payload: PackedByteArray)
	var sent: Array = []
	var connect_calls := 0
	var connectable := true
	func can_connect() -> bool: return connectable
	func connect_to(_url: String) -> int:
		connect_calls += 1
		connectable = false
		return OK
	func poll() -> void: pass
	func is_open() -> bool: return true
	func send_frame(msg_id: int, payload: PackedByteArray) -> void:
		sent.append({"msg_id": msg_id, "payload": payload})
	func count(msg_id: int) -> int:
		var n := 0
		for s in sent:
			if s["msg_id"] == msg_id:
				n += 1
		return n


func _join_resp_bytes(your_side: int, side1_progress: Dictionary = {}, side2_progress: Dictionary = {}) -> PackedByteArray:
	# sideN_progress：{card_id: [level, rank]}（KAN-76 服务端下发的养成；空 = 白板局）。
	var r = BattlePb.JoinRoomResp.new()
	r.set_ok(true)
	r.set_your_side(your_side)
	r.set_level_id("ladder_01")
	for c in DECK:
		r.add_side1_deck(c)
	for c in DECK:
		r.add_side2_deck(c)
	for cid in side1_progress:
		var cp1 = r.add_side1_progress()
		cp1.set_card_id(cid)
		cp1.set_level(side1_progress[cid][0])
		cp1.set_rank(side1_progress[cid][1])
	for cid in side2_progress:
		var cp2 = r.add_side2_progress()
		cp2.set_card_id(cid)
		cp2.set_level(side2_progress[cid][0])
		cp2.set_rank(side2_progress[cid][1])
	return r.to_bytes()

func _tick_bytes(t: int) -> PackedByteArray:
	var b = BattlePb.TickBundle.new()
	b.set_tick(t)
	return b.to_bytes()

func _new_client():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var fake = FakeWS.new()
	var bc = BattleClient.new(loader, fake)
	return [bc, fake]


# —— WS 帧编解码（static，无连接）——

func test_frame_codec_roundtrip() -> void:
	var payload := PackedByteArray([1, 2, 3, 4, 5])
	var frame := WSClient.encode_frame(44, payload)   # 44 = STATE_HASH_UP
	assert_eq(frame[0], 0, "大端高字节")
	assert_eq(frame[1], 44, "大端低字节")
	var dec := WSClient.decode_frame(frame)
	assert_true(dec["ok"])
	assert_eq(int(dec["msg_id"]), 44)
	assert_eq(dec["payload"], payload)

func test_frame_codec_high_byte() -> void:
	# msg_id 跨过 255，验证大端高字节
	var frame := WSClient.encode_frame(300, PackedByteArray([9]))
	assert_eq(frame[0], 1, "300 >> 8 = 1")
	assert_eq(frame[1], 300 & 0xFF)
	assert_eq(int(WSClient.decode_frame(frame)["msg_id"]), 300)

func test_short_frame_rejected() -> void:
	assert_false(WSClient.decode_frame(PackedByteArray([5]))["ok"])


# —— battle_client ——

func test_join_resp_builds_match() -> void:
	var pair = _new_client()
	var bc = pair[0]
	bc._on_frame(CommonPb.MsgId.JOIN_ROOM_RESP, _join_resp_bytes(2))
	assert_eq(bc.your_side, 2)
	assert_ne(bc.match_obj, null)
	# side 2 的本地玩家 = opponent
	assert_eq(bc.local_player(), bc.match_obj.opponent)
	# 双方卡组都建好（手牌 4 张）
	assert_eq(bc.match_obj.player.deck.get_hand().size(), 4)
	assert_eq(bc.match_obj.opponent.deck.get_hand().size(), 4)

# —— KAN-76：养成注入 ——

func test_join_resp_injects_both_sides_progress() -> void:
	# 服务端下发双方 level/rank → 两个 Player 各挂各的最小 PlayerData，
	# 乘区按本卡养成算（与 PVE 同管线）；两端对同一方数据一致 → lockstep 确定性成立。
	var pair = _new_client()
	var bc = pair[0]
	bc._on_frame(CommonPb.MsgId.JOIN_ROOM_RESP, _join_resp_bytes(1,
		{"knight": [4, 2], "giant": [7, 3]},     # side1 练过
		{"knight": [1, 1], "archers": [2, 1]}))  # side2 略练
	var loader = bc.config
	var pd1 = bc.match_obj.player.player_data
	var pd2 = bc.match_obj.opponent.player_data
	assert_ne(pd1, null, "side1 应注入养成")
	assert_ne(pd2, null, "side2 应注入养成")
	# 4级2阶 = (1+3×0.1)×1.25 = 1.625；7级3阶 = 1.6×1.5625 = 2.5
	assert_almost_eq(float(pd1.card_stat_mult("knight", loader)), 1.625, 0.0001, "side1 knight 4级2阶乘区")
	assert_almost_eq(float(pd1.card_stat_mult("giant", loader)), 2.5, 0.0001, "side1 giant 7级3阶乘区")
	assert_almost_eq(float(pd2.card_stat_mult("knight", loader)), 1.0, 0.0001, "side2 knight 白板乘区")
	assert_almost_eq(float(pd2.card_stat_mult("archers", loader)), 1.1, 0.0001, "side2 archers 2级乘区")
	# progress 未覆盖的卡（服务端漏发/新卡）fallback 乘区 1.0，确定性安全。
	assert_almost_eq(float(pd1.card_stat_mult("zap", loader)), 1.0, 0.0001, "未下发的卡乘区 1.0")

func test_join_resp_without_progress_stays_flat() -> void:
	# 空 progress（旧服务端/白板局）→ 不注入，行为与改前完全一致（向后兼容）。
	var pair = _new_client()
	var bc = pair[0]
	bc._on_frame(CommonPb.MsgId.JOIN_ROOM_RESP, _join_resp_bytes(1))
	assert_eq(bc.match_obj.player.player_data, null, "无 progress 不注入 side1")
	assert_eq(bc.match_obj.opponent.player_data, null, "无 progress 不注入 side2")

func test_tick_bundle_advances_and_reports_hash() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc._on_frame(CommonPb.MsgId.JOIN_ROOM_RESP, _join_resp_bytes(1))
	fake.sent.clear()
	for t in range(10):
		bc._on_frame(CommonPb.MsgId.TICK_BUNDLE, _tick_bytes(t))
	assert_eq(bc.match_obj.net_tick, 10)
	assert_eq(fake.count(CommonPb.MsgId.STATE_HASH_UP), 1, "应在 tick 10 上报一次哈希")

func test_send_deploy_uses_offset_tick() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc._on_frame(CommonPb.MsgId.JOIN_ROOM_RESP, _join_resp_bytes(1))
	for t in range(5):
		bc._on_frame(CommonPb.MsgId.TICK_BUNDLE, _tick_bytes(t))   # net_tick -> 5
	fake.sent.clear()
	bc.send_deploy("knight", Vector2(4.5, 17.0))
	assert_eq(fake.count(CommonPb.MsgId.DEPLOY_CMD), 1)
	var d = BattlePb.DeployCmd.new()
	d.from_bytes(fake.sent[0]["payload"])
	assert_eq(d.get_tick(), 7, "deploy tick = 当前 net_tick(5) + offset(2)")
	assert_eq(d.get_card_id(), "knight")
	assert_eq(d.get_x_milli(), 4500)
	assert_eq(d.get_y_milli(), 17000)

func test_deploy_ignored_before_join() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc.send_deploy("knight", Vector2(1, 1))   # 未 join → 无 match → no-op
	assert_eq(fake.count(CommonPb.MsgId.DEPLOY_CMD), 0)

func test_heartbeat_sent_after_interval() -> void:
	# V4-S3f：对战中每 HEARTBEAT_INTERVAL(5s) 发一次心跳。
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc._on_frame(CommonPb.MsgId.JOIN_ROOM_RESP, _join_resp_bytes(1))
	fake.sent.clear()
	bc.poll(2.0)   # 累计 2s < 5s，不发
	assert_eq(fake.count(CommonPb.MsgId.HEARTBEAT_PING), 0)
	bc.poll(3.5)   # 累计 5.5s ≥ 5s，发一次
	assert_eq(fake.count(CommonPb.MsgId.HEARTBEAT_PING), 1, "5s 后应发一次心跳")


# —— V4-S4 匹配流程 ——

func _match_found_bytes(side: int, opp_name: String, room: String) -> PackedByteArray:
	var mf = MatchPb.MatchFoundPush.new()
	mf.set_room_id(room)
	mf.set_your_side(side)
	var opp = mf.new_opponent()
	opp.set_account_id(99)
	opp.set_nickname(opp_name)
	opp.set_avatar_card_id("giant")   # V5-S9：对手头像（怪物卡）
	return mf.to_bytes()

func test_on_opened_sends_find_match() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc._on_opened()   # 首次连上 → FindMatch
	assert_eq(fake.count(CommonPb.MsgId.FIND_MATCH_REQ), 1)
	var req = MatchPb.FindMatchReq.new()
	req.from_bytes(fake.sent[0]["payload"])
	assert_eq(req.get_deck_slot(), 1)

func test_match_found_sets_room_and_emits() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var got := {"side": -1, "opp": "", "avatar": ""}
	bc.matched.connect(func(s, o, a): got["side"] = s; got["opp"] = o; got["avatar"] = a)
	bc._on_frame(CommonPb.MsgId.MATCH_FOUND_PUSH, _match_found_bytes(2, "Rival", "room-7"))
	assert_eq(bc._room_id, "room-7")
	assert_eq(int(got["side"]), 2)
	assert_eq(got["opp"], "Rival")
	assert_eq(got["avatar"], "giant", "V5-S9：对手头像随 matched 信号带出")

func test_reconnect_after_match_sends_join_room() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc._on_frame(CommonPb.MsgId.MATCH_FOUND_PUSH, _match_found_bytes(1, "X", "room-7"))
	fake.sent.clear()
	bc._on_opened()   # _room_id 已设 → 重连走 JoinRoom，而非 FindMatch
	assert_eq(fake.count(CommonPb.MsgId.JOIN_ROOM_REQ), 1)
	assert_eq(fake.count(CommonPb.MsgId.FIND_MATCH_REQ), 0)


func test_reconnect_waits_until_socket_can_connect() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc._started = true
	bc._reconnecting = true
	fake.connectable = false
	bc.poll(BattleClient.RECONNECT_RETRY + 0.1)
	assert_eq(fake.connect_calls, 0, "PVP CONNECTING 中不得重复拨号")
	fake.connectable = true
	bc.poll(0.0)
	assert_eq(fake.connect_calls, 1, "PVP socket 可连接后立即重试一次")
	bc.poll(BattleClient.RECONNECT_RETRY + 0.1)
	assert_eq(fake.connect_calls, 1, "PVP 新拨号未结束时不得重入")

func test_cancel_sends_cancel_req() -> void:
	var pair = _new_client()
	var bc = pair[0]
	var fake = pair[1]
	bc.cancel_match()
	assert_eq(fake.count(CommonPb.MsgId.CANCEL_MATCH_REQ), 1)
