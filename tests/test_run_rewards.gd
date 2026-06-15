# V3-4b/d 测试：RunRewards —— 战间三选一确定性候选（draft 卡 / relic 奖励）。
extends "res://tests/test_case.gd"

const RunRewardsScript = preload("res://logic/run_rewards.gd")

func _unique(a: Array) -> Array:
	var s := {}
	for x in a:
		s[x] = true
	return s.keys()

func test_offer_cards_excludes_owned_distinct_count() -> void:
	var pool := ["a", "b", "c", "d", "e", "f"]
	var owned := ["a", "b"]
	var offer := RunRewardsScript.offer_cards(pool, owned, 3, 42)
	assert_eq(offer.size(), 3, "三选一给 3 张")
	assert_eq(offer.size(), _unique(offer).size(), "候选互不相同")
	for c in offer:
		assert_false(c in owned, "不 offer 已持有的卡")
		assert_true(c in pool, "候选来自卡池")

func test_offer_is_deterministic_per_seed() -> void:
	var pool := ["a", "b", "c", "d", "e", "f", "g"]
	assert_eq(RunRewardsScript.offer_cards(pool, [], 3, 7), RunRewardsScript.offer_cards(pool, [], 3, 7), "同 seed → 同候选")

func test_seed_varies_offer() -> void:
	var pool := ["a", "b", "c", "d", "e", "f", "g"]
	var seen := {}
	for s in range(1, 11):
		seen[str(RunRewardsScript.offer_cards(pool, [], 3, s))] = true
	assert_true(seen.size() >= 2, "不同 seed 能产生不同候选")

func test_offer_caps_at_available() -> void:
	var offer := RunRewardsScript.offer_cards(["a", "b"], [], 3, 1)
	assert_eq(offer.size(), 2, "候选不足 n 时给现有的（不报错）")

func test_offer_relics_excludes_owned() -> void:
	var offer := RunRewardsScript.offer_relics(["x", "y", "z"], ["x"], 3, 5)
	assert_false("x" in offer, "不 offer 已持有 relic")
	assert_true(offer.size() <= 2, "剔除已持有后最多 2 个候选")
