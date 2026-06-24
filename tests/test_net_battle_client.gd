extends "res://tests/test_case.gd"

## V4-S3d 客户端网络层单测（无真 socket）：
## WS 帧编解码（大端）+ battle_client 收 JoinRoomResp 建 Match + TickBundle 驱动 advance_tick
## + 每 10 tick 上报哈希 + send_deploy 用 (当前 tick + 2)。
## fake ws 记录所有 send_frame，无需连服务端。

const BattleClient := preload("res://net/battle_client.gd")
const WSClient := preload("res://net/ws_client.gd")
const CommonPb := preload("res://net/proto/common.gd")
const BattlePb := preload("res://net/proto/battle.gd")
const ConfigLoaderScript := preload("res://logic/config_loader.gd")

const DECK := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]


# —— 记录发送的 fake ws（带 battle_client 需要的三个信号）——
class FakeWS extends RefCounted:
	signal opened
	signal closed
	signal frame_received(msg_id: int, payload: PackedByteArray)
	var sent: Array = []
	func connect_to(_url: String) -> int: return OK
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


func _join_resp_bytes(your_side: int) -> PackedByteArray:
	var r = BattlePb.JoinRoomResp.new()
	r.set_ok(true)
	r.set_your_side(your_side)
	r.set_level_id("ladder_01")
	for c in DECK:
		r.add_side1_deck(c)
	for c in DECK:
		r.add_side2_deck(c)
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
