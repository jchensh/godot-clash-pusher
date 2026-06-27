extends "res://tests/test_case.gd"

# V4-S0f smoke 测试: godobuf 生成的 GDScript pb 能 encode -> decode 圆环对接。
# 真正的 net/ 收发逻辑留到 V4-S3 (lockstep) 起再加。

const Auth = preload("res://net/proto/auth.gd")
const Profile = preload("res://net/proto/profile.gd")
const Battle = preload("res://net/proto/battle.gd")


func test_login_req_roundtrip() -> void:
	var req = Auth.LoginReq.new()
	req.set_device_id("dev-abc-123")
	req.set_client_version("0.4.0")
	req.set_platform("windows")

	var bytes: PackedByteArray = req.to_bytes()
	assert_true(bytes.size() > 0, "to_bytes 应当产出非空 PackedByteArray")

	var req2 = Auth.LoginReq.new()
	var rc: int = req2.from_bytes(bytes)
	assert_eq(rc, Auth.PB_ERR.NO_ERRORS, "from_bytes 应当成功")
	assert_eq(req2.get_device_id(), "dev-abc-123", "device_id 圆环一致")
	assert_eq(req2.get_client_version(), "0.4.0", "client_version 圆环一致")
	assert_eq(req2.get_platform(), "windows", "platform 圆环一致")


func test_profile_field_defaults_after_empty_roundtrip() -> void:
	# 空 message 序列化 -> 空 bytes；反序列化字段是默认值 (空串/0)。
	var p = Profile.Profile.new()
	var bytes: PackedByteArray = p.to_bytes()
	# proto3 空消息可能是 0 bytes,这是合法的。
	var p2 = Profile.Profile.new()
	p2.from_bytes(bytes)
	assert_eq(p2.get_account_id(), 0, "未设置的 int64 默认 0")
	assert_eq(p2.get_nickname(), "", "未设置的 string 默认空串")
	assert_eq(p2.get_version(), 0, "未设置的 int32 默认 0")


func test_deploy_cmd_fixed_point_coords() -> void:
	# 验证 DeployCmd 的 x_milli/y_milli 定点坐标设计:
	# tile (4.5, 17.0) -> x_milli=4500, y_milli=17000
	var cmd = Battle.DeployCmd.new()
	cmd.set_tick(100)
	cmd.set_card_id("knight")
	cmd.set_x_milli(4500)
	cmd.set_y_milli(17000)

	var bytes: PackedByteArray = cmd.to_bytes()
	var cmd2 = Battle.DeployCmd.new()
	cmd2.from_bytes(bytes)
	assert_eq(cmd2.get_tick(), 100)
	assert_eq(cmd2.get_card_id(), "knight")
	assert_eq(cmd2.get_x_milli(), 4500)
	assert_eq(cmd2.get_y_milli(), 17000)


func test_battle_result_push_winner_enum() -> void:
	# 验证嵌套 enum (BattleResultPush.Winner) 能正确编解码。
	var result = Battle.BattleResultPush.new()
	result.set_winner(Battle.BattleResultPush.Winner.SIDE_1)
	result.set_reason(Battle.BattleResultPush.Reason.KING_DESTROYED)
	result.set_side_1_score(2)
	result.set_side_2_score(1)

	var bytes: PackedByteArray = result.to_bytes()
	var result2 = Battle.BattleResultPush.new()
	result2.from_bytes(bytes)
	assert_eq(result2.get_winner(), Battle.BattleResultPush.Winner.SIDE_1)
	assert_eq(result2.get_reason(), Battle.BattleResultPush.Reason.KING_DESTROYED)
	assert_eq(result2.get_side_1_score(), 2)
	assert_eq(result2.get_side_2_score(), 1)
