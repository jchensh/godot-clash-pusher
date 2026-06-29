# V5 KAN-67：CardSort 养成卡格多维排序单测（各键单调性 + 可养成优先 + 稳定排序）。
extends "res://tests/test_case.gd"

const CardSortScript := preload("res://logic/card_sort.gd")
const ConfigLoaderScript := preload("res://logic/config_loader.gd")
const PlayerDataScript := preload("res://logic/player_data.gd")

func _mk() -> Array:
	var config = ConfigLoaderScript.new()
	config.load_all()
	var pd = PlayerDataScript.new()
	pd.init_new(config.cards.keys())
	return [config, pd]

func _assert_monotonic(ids: Array, pd, config, key: String, ascending: bool) -> void:
	for i in range(ids.size() - 1):
		var va := CardSortScript.key_value(String(ids[i]), pd, config, key)
		var vb := CardSortScript.key_value(String(ids[i + 1]), pd, config, key)
		if ascending:
			assert_true(va <= vb, "%s 升序应非降: %s(%d) 后接 %s(%d)" % [key, ids[i], va, ids[i + 1], vb])
		else:
			assert_true(va >= vb, "%s 降序应非升: %s(%d) 后接 %s(%d)" % [key, ids[i], va, ids[i + 1], vb])

func test_rarity_sort() -> void:
	var r := _mk(); var config = r[0]; var pd = r[1]
	var ids: Array = config.cards.keys()
	var asc := CardSortScript.sort_ids(ids, pd, config, "rarity", true)
	assert_eq(asc.size(), ids.size(), "排序不丢卡")
	_assert_monotonic(asc, pd, config, "rarity", true)
	var desc := CardSortScript.sort_ids(ids, pd, config, "rarity", false)
	assert_eq(String(desc[0]), "golem", "降序首位应为传说 golem")

func test_cost_sort() -> void:
	var r := _mk(); var config = r[0]; var pd = r[1]
	var ids: Array = config.cards.keys()
	_assert_monotonic(CardSortScript.sort_ids(ids, pd, config, "cost", true), pd, config, "cost", true)
	_assert_monotonic(CardSortScript.sort_ids(ids, pd, config, "cost", false), pd, config, "cost", false)

func test_level_sort() -> void:
	var r := _mk(); var config = r[0]; var pd = r[1]
	pd.cards["knight"]["level"] = 5   # 升级后 level 键值更大
	var ids: Array = config.cards.keys()
	_assert_monotonic(CardSortScript.sort_ids(ids, pd, config, "level", true), pd, config, "level", true)
	assert_eq(CardSortScript.key_value("knight", pd, config, "level"), 105, "rank1·level5 = 1*100+5")

func test_actionable_priority() -> void:
	var r := _mk(); var config = r[0]; var pd = r[1]
	pd.gold = 9999999   # 金币充足 → 已解锁未满级卡可升级 = 可养成
	var ids: Array = config.cards.keys()
	var desc := CardSortScript.sort_ids(ids, pd, config, "actionable", false)   # 可养成优先
	_assert_monotonic(desc, pd, config, "actionable", false)
	assert_true(CardSortScript.actionable(pd, config, String(desc[0])), "可养成优先：首位应可养成")
	assert_false(CardSortScript.actionable(pd, config, "golem"), "golem 未解锁+0碎片 → 不可养成")

func test_stable_sort() -> void:
	var r := _mk(); var config = r[0]; var pd = r[1]
	# 未知 id（不在 config）→ cost 键值全 0 → 全部并列 → 保持原序（稳定排序）
	var out := CardSortScript.sort_ids(["zzz", "aaa", "mmm"], pd, config, "cost", true)
	assert_eq(out, ["zzz", "aaa", "mmm"], "并列项保持原序（稳定）")
