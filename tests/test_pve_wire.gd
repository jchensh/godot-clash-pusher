extends "res://tests/test_case.gd"

## KAN-78/79：PVE 防作弊 proto 消息编解码往返（economy.gd godobuf 生成代码用法验证）。
## economy_client.pve_start/pve_report/report_stage_clear 构造的就是这些消息。

const EconomyPb := preload("res://net/proto/economy.gd")

func test_stage_clear_req_with_battle_and_summary_roundtrip() -> void:
	var req = EconomyPb.StageClearReq.new()
	req.set_stage_id("stage_2_3")
	req.set_stars(2)
	req.set_battle_id(12345)
	var s = req.new_summary()
	s.set_duration_ticks(978)
	s.set_deploy_count(45)
	s.set_king_hp_permille(154)
	var back = EconomyPb.StageClearReq.new()
	assert_eq(back.from_bytes(req.to_bytes()), EconomyPb.PB_ERR.NO_ERRORS)
	assert_eq(back.get_stage_id(), "stage_2_3")
	assert_eq(back.get_stars(), 2)
	assert_eq(int(back.get_battle_id()), 12345)
	assert_eq(back.get_summary().get_duration_ticks(), 978)
	assert_eq(back.get_summary().get_deploy_count(), 45)
	assert_eq(back.get_summary().get_king_hp_permille(), 154)

func test_pve_start_req_roundtrip() -> void:
	var req = EconomyPb.PveStartReq.new()
	req.set_stage_id("stage_1_1")
	for c in ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]:
		req.add_deck(c)
	var back = EconomyPb.PveStartReq.new()
	assert_eq(back.from_bytes(req.to_bytes()), EconomyPb.PB_ERR.NO_ERRORS)
	assert_eq(back.get_stage_id(), "stage_1_1")
	assert_eq(back.get_deck().size(), 8)
	assert_eq(String(back.get_deck()[0]), "knight")

func test_pve_report_req_roundtrip() -> void:
	var req = EconomyPb.PveReportReq.new()
	req.set_battle_id(77)
	var c1 = req.add_cmds()
	c1.set_tick(30)
	c1.set_phase(0)
	c1.set_side(1)
	c1.set_card_id("knight")
	c1.set_x_milli(4500)
	c1.set_y_milli(17000)
	var c2 = req.add_cmds()
	c2.set_tick(91)
	c2.set_phase(1)
	c2.set_side(2)
	c2.set_card_id("giant")
	c2.set_x_milli(4500)
	c2.set_y_milli(5500)
	var h = req.add_hashes()
	h.set_tick(10)
	h.set_hash(PackedByteArray([1, 2, 3, 4]))
	var back = EconomyPb.PveReportReq.new()
	assert_eq(back.from_bytes(req.to_bytes()), EconomyPb.PB_ERR.NO_ERRORS)
	assert_eq(int(back.get_battle_id()), 77)
	assert_eq(back.get_cmds().size(), 2)
	assert_eq(back.get_cmds()[0].get_card_id(), "knight")
	assert_eq(back.get_cmds()[1].get_phase(), 1, "AI in 相位")
	assert_eq(back.get_cmds()[1].get_side(), 2)
	assert_eq(back.get_hashes().size(), 1)
	assert_eq(back.get_hashes()[0].get_hash(), PackedByteArray([1, 2, 3, 4]))

func test_pve_start_resp_roundtrip() -> void:
	var resp = EconomyPb.PveStartResp.new()
	resp.set_battle_id(9876543210)   # int64 大值（BIGSERIAL）
	var back = EconomyPb.PveStartResp.new()
	assert_eq(back.from_bytes(resp.to_bytes()), EconomyPb.PB_ERR.NO_ERRORS)
	assert_eq(int(back.get_battle_id()), 9876543210)
