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

# V5-N7：apply_server_state 从服务器权威快照重建（瘦客户端化）。
# server_state shape = economy_client._state_to_dict 输出（顶层 gold/gems/idle/highest；cards/stages 嵌套）。
func test_apply_server_state_rebuilds_from_snapshot() -> void:
	var p = PlayerDataScript.new()
	p.init_new(["knight", "golem", "archers"])
	# 本地先有养成（应被服务器覆盖）。
	p.gold = 999
	p.cards["knight"]["level"] = 9
	# 服务器快照：knight level3/rank2，golem 未解锁 level1。
	var snap := {
		"gold": 500, "gems": 7, "idle_last_collect_ts": 1234567890,
		"highest_cleared": "stage_1_2",
		"cards": {
			"knight": {"level": 3, "rank": 2, "shards": 5, "unlocked": true},
			"golem": {"level": 1, "rank": 1, "shards": 0, "unlocked": false},
		},
		"stages": {"stage_1_1": {"stars": 3, "cleared": true}},
	}
	p.apply_server_state(snap, ["knight", "golem", "archers"])
	# 服务器覆盖本地。
	assert_eq(p.gold, 500, "gold 从服务器")
	assert_eq(p.gems, 7, "gems 从服务器")
	assert_eq(p.idle_last_collect_ts, 1234567890, "idle ts 从服务器（顶层非嵌套）")
	assert_eq(p.highest_cleared, "stage_1_2", "highest 从服务器")
	assert_eq(int(p.cards["knight"]["level"]), 3, "knight level 被服务器覆盖（非本地 9）")
	assert_eq(int(p.cards["knight"]["rank"]), 2, "knight rank 从服务器")
	assert_false(bool(p.cards["golem"]["unlocked"]), "golem 未解锁")
	# ensure 缺失卡：服务器快照没有 archers → 补默认条目（starter 卡 unlocked=true，卡池一致）。
	assert_true(p.cards.has("archers"), "archers 被 ensure 补齐")
	assert_true(bool(p.cards["archers"]["unlocked"]), "archers 是 starter → 补为解锁")
