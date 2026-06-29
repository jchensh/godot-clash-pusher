# V5-S2：玩家存档落盘往返 + 战力计算 + 解锁解算 + 卡池补齐。
extends "res://tests/test_case.gd"

const PlayerDataScript = preload("res://logic/player_data.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const SaveSystemScript = preload("res://logic/save_system.gd")

const TMP := "user://_test_v5_player.json"

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

func _all_ids(config) -> Array:
	var ids: Array = []
	for cid in config.cards:
		ids.append(cid)
	return ids

# —— 存档落盘往返 ——
func test_save_load_round_trip() -> void:
	SaveSystemScript.clear_player_save(TMP)
	var config = _config()
	var ids = _all_ids(config)
	var p = PlayerDataScript.new()
	p.init_new(ids)
	p.gold = 5000
	p.gems = 12
	p.cards["knight"]["level"] = 5
	p.cards["knight"]["rank"] = 2
	p.stages["stage_1_1"] = {"stars": 3, "cleared": true}
	p.highest_cleared = "stage_1_1"
	p.idle_last_collect_ts = 123456
	SaveSystemScript.save_player(p, TMP)
	var p2 = SaveSystemScript.load_player(ids, TMP)
	assert_eq(p2.gold, 5000, "金币落盘")
	assert_eq(p2.gems, 12, "宝石落盘")
	assert_eq(int(p2.card_state("knight").get("level")), 5, "等级落盘")
	assert_eq(int(p2.card_state("knight").get("rank")), 2, "阶落盘")
	assert_eq(p2.highest_cleared, "stage_1_1", "最高通关落盘")
	assert_eq(int(p2.stages["stage_1_1"]["stars"]), 3, "星级落盘")
	assert_eq(p2.idle_last_collect_ts, 123456, "挂机时间戳落盘")
	SaveSystemScript.clear_player_save(TMP)

func test_load_missing_creates_new_player() -> void:
	SaveSystemScript.clear_player_save(TMP)
	var config = _config()
	var ids = _all_ids(config)
	assert_false(SaveSystemScript.has_player_save(TMP), "起始无档")
	var p = SaveSystemScript.load_player(ids, TMP)
	assert_eq(p.gold, 0, "新档金币 0")
	assert_eq(p.unlocked_card_ids().size(), 8, "新档解锁 8 张")
	assert_eq(p.cards.size(), ids.size(), "新档全卡建条目")

func test_ensure_cards_adds_missing_keeps_existing() -> void:
	var config = _config()
	var p = PlayerDataScript.new()
	# 模拟旧档只有 knight（卡池后续新增了其余卡）。
	p.load_dict({"cards": {"knight": {"level": 3, "rank": 1, "shards": 0, "unlocked": true}}})
	p.ensure_cards(_all_ids(config))
	assert_true(p.cards.has("golem"), "缺失卡被补齐")
	assert_false(p.is_unlocked("golem"), "补齐的非 starter 卡锁定")
	assert_eq(int(p.card_state("knight").get("level")), 3, "已有卡不被覆盖")

# —— 战力 ——
func test_card_stat_mult_curve() -> void:
	var config = _config()
	var p = PlayerDataScript.new()
	p.init_new(_all_ids(config))
	assert_almost_eq(p.card_stat_mult("knight", config), 1.0, 0.0001, "默认乘区 1.0")
	p.cards["knight"]["level"] = 10
	assert_almost_eq(p.card_stat_mult("knight", config), 1.9, 0.0001, "满级 1.9")
	p.cards["knight"]["rank"] = 3
	assert_almost_eq(p.card_stat_mult("knight", config), 2.96875, 0.0001, "满养成 ≈3.0")

func test_card_and_team_power() -> void:
	var config = _config()
	var p = PlayerDataScript.new()
	p.init_new(_all_ids(config))
	assert_almost_eq(p.card_power("knight", config), 100.0, 0.001, "knight 默认战力 100")
	p.cards["knight"]["level"] = 5
	assert_almost_eq(p.card_power("knight", config), 140.0, 0.001, "knight L5 战力 140")
	# 初始 8 张卡组：common×5(knight L5=140 + archers/goblins/arrows/zap=100×4) + rare×3(giant/minions/fireball=140×3)
	# = 140 + 400 + 420 = 960
	var deck = ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]
	assert_eq(p.team_power(deck, config), 960, "队伍战力求和")

# —— 解锁解算 ——
func test_can_unlock_by_shards() -> void:
	var config = _config()
	var p = PlayerDataScript.new()
	p.init_new(_all_ids(config))
	assert_false(p.can_unlock("golem", config), "0 碎片不可解锁")
	p.cards["golem"]["shards"] = 120   # legendary unlock_shards=120
	assert_true(p.can_unlock("golem", config), "够碎片可解锁")
	assert_false(p.can_unlock("knight", config), "已解锁不可再解锁")
