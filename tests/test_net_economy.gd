# V5-N3/N4：经济客户端 proto 编解码 + 状态映射（无需 live server）。
extends "res://tests/test_case.gd"

const EconomyClient = preload("res://net/economy_client.gd")
const EconomyProto = preload("res://net/proto/economy.gd")

func test_state_to_dict() -> void:
	var ec = EconomyClient.new()
	var es = EconomyProto.EconomyState.new()
	es.set_gold(500)
	es.set_gems(10)
	es.set_highest_cleared("stage_1_1")
	var c = es.add_cards()
	c.set_card_id("knight"); c.set_level(3); c.set_rank(2); c.set_shards(5); c.set_unlocked(true)
	var s = es.add_stages()
	s.set_stage_id("stage_1_1"); s.set_stars(3); s.set_cleared(true)
	var d = ec._state_to_dict(es)
	assert_eq(int(d["gold"]), 500, "gold")
	assert_eq(int(d["gems"]), 10, "gems")
	assert_eq(d["highest_cleared"], "stage_1_1", "highest_cleared")
	assert_eq(int(d["cards"]["knight"]["level"]), 3, "knight level")
	assert_eq(int(d["cards"]["knight"]["rank"]), 2, "knight rank")
	assert_true(bool(d["cards"]["knight"]["unlocked"]), "knight unlocked")
	assert_eq(int(d["stages"]["stage_1_1"]["stars"]), 3, "stage stars")

func test_proto_roundtrip() -> void:
	var es = EconomyProto.EconomyState.new()
	es.set_gold(1234)
	var c = es.add_cards()
	c.set_card_id("golem"); c.set_shards(40)
	var es2 = EconomyProto.EconomyState.new()
	assert_eq(es2.from_bytes(es.to_bytes()), EconomyProto.PB_ERR.NO_ERRORS, "decode ok")
	assert_eq(es2.get_gold(), 1234, "gold roundtrip")
	assert_eq(es2.get_cards()[0].get_card_id(), "golem", "card roundtrip")
	assert_eq(es2.get_cards()[0].get_shards(), 40, "shards roundtrip")

func test_action_req() -> void:
	var req = EconomyProto.EconomyActionReq.new()
	req.set_card_id("fireball")
	var req2 = EconomyProto.EconomyActionReq.new()
	req2.from_bytes(req.to_bytes())
	assert_eq(req2.get_card_id(), "fireball", "action req card_id")

func test_default_and_override_url() -> void:
	assert_eq(EconomyClient.new().api_url, "http://localhost:8080", "default url")
	assert_eq(EconomyClient.new("http://x").api_url, "http://x", "override url")
