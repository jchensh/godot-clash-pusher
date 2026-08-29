# 决策 49 缩池规约锁定（P1-7/KAN-121）：17 张锁定卡（等卡通素材）不可解锁/不上阵/无掉落源，
# 31 张可玩（21 卡通角色单位卡 + 10 法术）。配置一致性由本测试焊死：
# locked 恰 17 / starter 恰 8 且无锁卡 / levels player_deck 零锁卡 / stages 掉落零锁卡 /
# PlayerData.STARTER_CARDS 与 card_progression starter 同步 / can_unlock 对锁卡恒 false。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const PlayerDataScript = preload("res://logic/player_data.gd")

const EXPECT_LOCKED := 17
const EXPECT_PLAYABLE := 31


func _loader():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return loader


func _locked_ids(loader) -> Array:
	var out: Array = []
	for cid in loader.card_progression:
		if String(cid).begins_with("_"):
			continue
		var cp = loader.card_progression[cid]
		if typeof(cp) == TYPE_DICTIONARY and bool((cp as Dictionary).get("locked", false)):
			out.append(String(cid))
	return out


func test_locked_pool_counts() -> void:
	var loader = _loader()
	var locked := _locked_ids(loader)
	assert_eq(locked.size(), EXPECT_LOCKED, "锁定卡恰 %d 张" % EXPECT_LOCKED)
	assert_eq(loader.cards.size() - locked.size(), EXPECT_PLAYABLE, "可玩卡恰 %d 张" % EXPECT_PLAYABLE)
	for cid in locked:
		assert_true(loader.cards.has(cid), "锁定卡 %s 配置仍保留（决策 49：只锁不删）" % cid)


func test_starters_playable_and_synced() -> void:
	var loader = _loader()
	var starters: Array = []
	for cid in loader.card_progression:
		if String(cid).begins_with("_"):
			continue
		var cp = loader.card_progression[cid]
		if typeof(cp) == TYPE_DICTIONARY and bool((cp as Dictionary).get("starter", false)):
			starters.append(String(cid))
			assert_false(bool((cp as Dictionary).get("locked", false)), "starter %s 不得是锁定卡" % cid)
	assert_eq(starters.size(), 8, "starter 恰 8 张")
	starters.sort()
	var client: Array = PlayerDataScript.STARTER_CARDS.duplicate()
	client.sort()
	assert_eq(starters, client, "card_progression starter 与 PlayerData.STARTER_CARDS 同步")


func test_level_player_decks_exclude_locked() -> void:
	# 玩家侧强制卡组（战役/教学关）零锁卡；ai_deck 不查（决策 49：AI 沿用全卡池保平衡）。
	var loader = _loader()
	var locked := _locked_ids(loader)
	for lid in loader.levels:
		var lv = loader.levels[lid]
		if typeof(lv) != TYPE_DICTIONARY:
			continue
		for cid in (lv as Dictionary).get("player_deck", []):
			assert_false(locked.has(String(cid)), "关卡 %s player_deck 含锁定卡 %s" % [lid, cid])


func test_stage_drops_exclude_locked() -> void:
	var loader = _loader()
	var locked := _locked_ids(loader)
	var stages: Dictionary = loader.stages
	for sid in stages:
		if String(sid).begins_with("_"):
			continue
		var st = stages[sid]
		if typeof(st) != TYPE_DICTIONARY:
			continue
		for key in ["first_clear", "repeat"]:
			var shards = ((st as Dictionary).get(key, {}) as Dictionary).get("shards", {})
			if typeof(shards) == TYPE_DICTIONARY:
				for cid in shards:
					assert_false(locked.has(String(cid)), "%s %s 掉锁定卡 %s 碎片" % [sid, key, cid])
		var drop = (st as Dictionary).get("shard_drop", {})
		if typeof(drop) == TYPE_DICTIONARY:
			for cid in drop:
				assert_false(locked.has(String(cid)), "%s shard_drop 含锁定卡 %s" % [sid, cid])


func test_can_unlock_blocked_for_locked_card() -> void:
	var loader = _loader()
	var pd = PlayerDataScript.new()
	pd.init_new(loader.cards.keys())
	# 给锁定卡灌满碎片（模拟 GM add_shards_all 旁路）→ 仍不可解锁。
	pd.cards["giant"]["shards"] = 99999
	assert_false(pd.can_unlock("giant", loader), "锁定卡碎片再多也不可解锁")
	# 对照组：可玩未解锁卡灌碎片 → 可解锁（缩池不误伤正常链路）。
	pd.cards["princess"]["shards"] = 99999
	assert_true(pd.can_unlock("princess", loader), "可玩卡解锁链路不受缩池影响")
