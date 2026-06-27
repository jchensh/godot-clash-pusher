# V5-S6：经济产出——关卡奖励(首通/重复/碎片掉落) + 解锁新卡 + 挂机离线金币(累计/封顶/领取)。
extends "res://tests/test_case.gd"

const PlayerDataScript = preload("res://logic/player_data.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

func _pd(config):
	var ids: Array = []
	for cid in config.cards:
		ids.append(cid)
	var p = PlayerDataScript.new()
	p.init_new(ids)
	return p

# —— 关卡奖励 ——
# 配置驱动（S8c 后 stages.json 由生成器铺 100 关，勿钉魔数）：首通发 first_clear.gold + 配置碎片。
func test_grant_stage_reward_first_clear() -> void:
	var config = _config()
	var p = _pd(config)
	var stage = config.get_stage("stage_1_2")
	var fc: Dictionary = stage["first_clear"]
	var exp_gold := int(fc["gold"])
	var g = p.grant_stage_reward("stage_1_2", true, config)
	assert_eq(p.gold, exp_gold, "首通金币 = 配置 first_clear.gold (%d)" % exp_gold)
	assert_eq(int(g["gold"]), exp_gold, "返回实发金币")
	var fc_shards: Dictionary = fc.get("shards", {})
	assert_true(fc_shards.size() >= 1, "stage_1_2 首通含碎片（解锁铺垫）")
	for cid in fc_shards:
		var n := int(fc_shards[cid])
		assert_eq(int(p.card_state(cid).get("shards")), n, "%s 碎片发放 %d" % [str(cid), n])
		assert_eq(int(g["shards"].get(cid, 0)), n, "返回 %s 碎片" % str(cid))

func test_grant_stage_reward_repeat_small() -> void:
	var config = _config()
	var p = _pd(config)
	var stage = config.get_stage("stage_1_2")
	var first_gold := int((stage["first_clear"] as Dictionary)["gold"])
	var repeat_gold := int((stage["repeat"] as Dictionary)["gold"])
	p.grant_stage_reward("stage_1_2", false, config)
	assert_eq(p.gold, repeat_gold, "重复奖励 = 配置 repeat.gold (%d)" % repeat_gold)
	assert_true(repeat_gold < first_gold, "重复 < 首通")

func test_grant_reward_generic() -> void:
	var config = _config()
	var p = _pd(config)
	p.grant_reward({"gold": 100, "gems": 5, "shards": {"golem": 10}})
	assert_eq(p.gold, 100, "金币")
	assert_eq(p.gems, 5, "宝石")
	assert_eq(int(p.card_state("golem").get("shards")), 10, "golem +10 碎片")

func test_shard_drop_seeded_reproducible() -> void:
	var config = _config()
	var p = _pd(config)
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var p2 = _pd(config)
	var rng2 = RandomNumberGenerator.new()
	rng2.seed = 12345
	p.grant_stage_reward("stage_1_2", false, config, rng)
	p2.grant_stage_reward("stage_1_2", false, config, rng2)
	assert_eq(int(p.card_state("skeletons").get("shards")), int(p2.card_state("skeletons").get("shards")), "同种子 shard_drop 确定可复现")

# —— 解锁新卡 ——
func test_unlock_card_spends_shards() -> void:
	var config = _config()
	var p = _pd(config)
	p.cards["golem"]["shards"] = 120   # legendary 门槛 120
	assert_true(p.unlock_card("golem", config), "够碎片解锁")
	assert_true(p.is_unlocked("golem"), "已解锁")
	assert_eq(int(p.card_state("golem").get("shards")), 0, "扣 120 碎片")

func test_unlock_card_rejects_insufficient() -> void:
	var config = _config()
	var p = _pd(config)
	p.cards["golem"]["shards"] = 100   # < 120
	assert_false(p.unlock_card("golem", config), "碎片不足拒绝")
	assert_false(p.is_unlocked("golem"), "仍锁定")

# —— 挂机离线金币 ——
func test_idle_accrual_and_cap() -> void:
	var config = _config()
	var p = _pd(config)
	p.highest_cleared = "stage_1_1"   # chapter 1 → rate 50/hr
	p.idle_last_collect_ts = 1000
	assert_eq(p.idle_rate_per_hour(config), 50, "rate = 50*chapter1")
	assert_eq(p.idle_pending(1000 + 3600 * 2, config), 100, "2h → 100 金")
	assert_eq(p.idle_pending(1000 + 3600 * 20, config), 400, "封顶 8h → 400 金")

func test_idle_collect_resets_baseline() -> void:
	var config = _config()
	var p = _pd(config)
	p.highest_cleared = "stage_1_1"
	p.idle_last_collect_ts = 1000
	var now = 1000 + 3600 * 3   # 3h → 150
	assert_eq(p.collect_idle(now, config), 150, "领取 150")
	assert_eq(p.gold, 150, "金币 +150")
	assert_eq(p.idle_last_collect_ts, now, "基准刷新")
	assert_eq(p.idle_pending(now, config), 0, "领取后即时再领 = 0")

func test_idle_zero_without_progress() -> void:
	var config = _config()
	var p = _pd(config)
	p.idle_last_collect_ts = 1000   # 无通关 → chapter 0 → rate 0
	assert_eq(p.idle_rate_per_hour(config), 0, "无进度 0 产出")
	assert_eq(p.idle_pending(1000 + 3600 * 5, config), 0, "0 产出")
