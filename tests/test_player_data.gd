# V5-S0：PlayerData 默认新档 + to_dict/load_dict 往返。
extends "res://tests/test_case.gd"

const PlayerDataScript = preload("res://logic/player_data.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _all_card_ids() -> Array:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var ids: Array = []
	for cid in loader.cards:
		ids.append(cid)
	return ids

func test_new_player_defaults() -> void:
	var ids = _all_card_ids()
	var p = PlayerDataScript.new()
	p.init_new(ids)
	assert_eq(p.gold, 0, "新档金币 0")
	assert_eq(p.gems, 0, "新档宝石 0")
	assert_eq(p.cards.size(), ids.size(), "每张卡都有条目")
	# 初始解锁恰好 8 张（starter）。
	assert_eq(p.unlocked_card_ids().size(), 8, "初始解锁 8 张")
	for cid in ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]:
		assert_true(p.is_unlocked(cid), "%s 应解锁" % cid)
	for cid in ["golem", "musketeer", "skeletons", "lightning"]:
		assert_false(p.is_unlocked(cid), "%s 应锁定" % cid)
	# 默认 level1 / rank1。
	assert_eq(int(p.card_state("knight").get("level")), 1, "默认 level 1")
	assert_eq(int(p.card_state("knight").get("rank")), 1, "默认 rank 1")

func test_round_trip() -> void:
	var p = PlayerDataScript.new()
	p.init_new(["knight", "golem"])
	p.gold = 1234
	p.gems = 7
	p.cards["knight"]["level"] = 5
	p.cards["knight"]["rank"] = 2
	p.cards["golem"]["shards"] = 40
	p.stages["stage_1_1"] = {"stars": 3, "cleared": true}
	p.highest_cleared = "stage_1_1"
	p.idle_last_collect_ts = 99999
	var d = p.to_dict()
	var p2 = PlayerDataScript.new()
	p2.load_dict(d)
	assert_eq(p2.gold, 1234, "金币往返")
	assert_eq(p2.gems, 7, "宝石往返")
	assert_eq(int(p2.card_state("knight").get("level")), 5, "等级往返")
	assert_eq(int(p2.card_state("knight").get("rank")), 2, "阶往返")
	assert_eq(int(p2.card_state("golem").get("shards")), 40, "碎片往返")
	assert_eq(p2.highest_cleared, "stage_1_1", "最高通关往返")
	assert_eq(int(p2.stages["stage_1_1"]["stars"]), 3, "星级往返")
	assert_eq(p2.idle_last_collect_ts, 99999, "挂机时间戳往返")

func test_load_defaults_missing() -> void:
	var p = PlayerDataScript.new()
	p.load_dict({})
	assert_eq(p.gold, 0, "缺字段金币默认 0")
	assert_eq(p.gems, 0, "缺字段宝石默认 0")
	assert_true(p.cards.is_empty(), "缺字段 cards 空")
	assert_true(p.stages.is_empty(), "缺字段 stages 空")
	assert_eq(p.highest_cleared, "", "缺字段最高通关空")
	assert_eq(p.idle_last_collect_ts, 0, "缺字段挂机时间 0")
