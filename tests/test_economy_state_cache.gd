# V5-N7（决策 48）：EconomyStateCache 瘦客户端化测试。
# 验证：开战拿的养成数值来自服务器缓存（EconomyStateCache.for_battle），
# 改本地存档不影响 cache —— 决策 48「改存档无效」的客户端侧落地。
extends "res://tests/test_case.gd"

const EconomyStateCacheScript = preload("res://net/economy_state_cache.gd")
const PlayerDataScript = preload("res://logic/player_data.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

var _config = null

func setup() -> void:
	_config = ConfigLoaderScript.new()
	_config.load_all()


func _all_card_ids() -> Array:
	var ids: Array = []
	for cid in _config.cards:
		ids.append(cid)
	return ids


# 造一份"服务器快照"（shape 同 economy_client._state_to_dict）：knight 满养成（level10/rank3）。
func _server_snapshot_knight_maxed() -> Dictionary:
	return {
		"gold": 0, "gems": 0, "idle_last_collect_ts": 0, "highest_cleared": "",
		"cards": {"knight": {"level": 10, "rank": 3, "shards": 0, "unlocked": true}},
		"stages": {},
	}


# for_battle 未加载 → 返回全默认新档（level1/rank1，乘区 1.0），保证战斗能跑。
func test_for_battle_unloaded_returns_fresh() -> void:
	var cache = EconomyStateCacheScript.new()
	var pd = cache.for_battle(_all_card_ids())
	assert_not_null(pd, "未加载也返回 PlayerData（默认新档）")
	assert_false(cache.is_loaded, "未加载标记")
	assert_eq(int(pd.cards["knight"]["level"]), 1, "默认新档 knight level1")
	assert_almost_eq(float(pd.card_stat_mult("knight", _config)), 1.0, 0.0001, "默认乘区 1.0")


# 模拟 refresh 成功（cache 内部状态 = refresh 后的样子）：for_battle 拿到的养成数值来自服务器。
# 关键：knight 服务器满养成 → 乘区 ≈3.0；而不是本地的默认 1.0。
func test_for_battle_uses_server_progression() -> void:
	var cache = EconomyStateCacheScript.new()
	# 模拟 refresh 成功：从服务器快照重建 cache + 标记已加载（refresh 内部就这么做）。
	var pd = PlayerDataScript.new()
	pd.apply_server_state(_server_snapshot_knight_maxed(), _all_card_ids())
	cache.cache = pd
	cache.is_loaded = true
	# for_battle 返回的就是缓存（服务器养成）。
	var battle_pd = cache.for_battle(_all_card_ids())
	assert_eq(int(battle_pd.cards["knight"]["level"]), 10, "开战 knight level 来自服务器=10")
	assert_eq(int(battle_pd.cards["knight"]["rank"]), 3, "开战 knight rank 来自服务器=3")
	# 满养成乘区 ≈ 1.9（level）× 1.5625（rank3）≈ 2.96875。
	assert_almost_eq(float(battle_pd.card_stat_mult("knight", _config)), 2.96875, 0.001, "开战乘区来自服务器养成 ≈3.0")


# ★ 决策 48 核心验收：改本地存档（player_save.json）不影响 cache.for_battle() 的养成数值。
# cache 持有的是自己的 PlayerData 副本；本地档被篡改后，cache 不受影响 → 开战数值仍是服务器的。
func test_local_save_tamper_does_not_affect_battle() -> void:
	var cache = EconomyStateCacheScript.new()
	# 服务器拉来 knight level1/rank1（未养成）。
	var server_pd = PlayerDataScript.new()
	server_pd.apply_server_state({
		"gold": 0, "gems": 0, "idle_last_collect_ts": 0, "highest_cleared": "",
		"cards": {"knight": {"level": 1, "rank": 1, "shards": 0, "unlocked": true}},
		"stages": {},
	}, _all_card_ids())
	cache.cache = server_pd
	cache.is_loaded = true   # 模拟 refresh 成功

	# 玩家篡改本地存档（SaveSystem.load_player 读出的另一份 PlayerData）：
	# 把本地档的 knight 改成满养成，企图开战变强。
	var tampered_local = PlayerDataScript.new()
	tampered_local.apply_server_state(_server_snapshot_knight_maxed(), _all_card_ids())
	tampered_local.cards["knight"]["level"] = 10
	tampered_local.cards["knight"]["rank"] = 3

	# 但开战用的是 cache.for_battle()（服务器拉的 level1/rank1），不是 tampered_local。
	var battle_pd = cache.for_battle(_all_card_ids())
	assert_eq(int(battle_pd.cards["knight"]["level"]), 1, "改本地档无效：开战仍用服务器 level1")
	assert_eq(int(battle_pd.cards["knight"]["rank"]), 1, "改本地档无效：开战仍用服务器 rank1")
	assert_almost_eq(float(battle_pd.card_stat_mult("knight", _config)), 1.0, 0.0001, "改本地档无效：开战乘区仍 1.0")
	# 篡改的本地档数值（不应被采用）。
	assert_eq(int(tampered_local.cards["knight"]["level"]), 10, "对照：篡改档确是 level10（但未被开战采用）")


# refresh 成功路径（模拟）：apply_server_state 后 cache 更新 + is_loaded 可由调用方置位。
# 这里测 seed→apply 两次：第二次服务器快照覆盖第一次（养成回退也要忠实反映服务器）。
func test_cache_reflects_latest_server_state() -> void:
	var cache = EconomyStateCacheScript.new()
	# 第一次：knight level5。
	var pd1 = PlayerDataScript.new()
	pd1.apply_server_state({
		"gold": 100, "gems": 0, "idle_last_collect_ts": 0, "highest_cleared": "",
		"cards": {"knight": {"level": 5, "rank": 1, "shards": 0, "unlocked": true}},
		"stages": {},
	}, _all_card_ids())
	cache.seed_from_local(pd1)
	assert_eq(int(cache.get_cache().cards["knight"]["level"]), 5, "第一次缓存 level5")

	# 第二次：服务器回退到 level3（玩家花金币升级后又... 不可能回退，但测缓存忠实反映服务器）。
	var pd2 = PlayerDataScript.new()
	pd2.apply_server_state({
		"gold": 50, "gems": 0, "idle_last_collect_ts": 0, "highest_cleared": "",
		"cards": {"knight": {"level": 3, "rank": 1, "shards": 0, "unlocked": true}},
		"stages": {},
	}, _all_card_ids())
	cache.seed_from_local(pd2)
	assert_eq(int(cache.get_cache().cards["knight"]["level"]), 3, "缓存被最新服务器状态覆盖=3")
	assert_eq(int(cache.get_cache().gold), 50, "gold 被最新服务器覆盖=50")


func test_transport_failure_reports_to_online_runtime() -> void:
	var cache = EconomyStateCacheScript.new()
	var reasons: Array = []
	cache.transport_failure_reporter = func(reason: String): reasons.append(reason)
	cache._observe_result({"ok": false, "status_code": 0}, "pve report")
	assert_eq(reasons.size(), 1, "transport failure 必须反向驱动 Online 降级")
	assert_true(String(reasons[0]).contains("pve report"), "原因包含操作名")
	cache._observe_result({"ok": false, "status_code": 400}, "bad claim")
	assert_eq(reasons.size(), 1, "业务 4xx 不应误判整站离线")
	cache._observe_result({"ok": false, "status_code": 503}, "stage clear")
	assert_eq(reasons.size(), 2, "API 5xx 也应 fail-closed")
