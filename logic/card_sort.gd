# CardSort —— V5 KAN-67：养成卡格多维排序（纯逻辑、确定性、可 headless 单测）。
#
# 排序键 KEYS：rarity(稀有度) / cost(圣水费) / level(等级·阶) / actionable(可养成优先)。
# 取值依赖 cache(PlayerData 服务器快照) + config(ConfigLoader)；view(card_collection) 接控件即时重排。
# 稳定排序：同键值保持原序（同值按原下标），结果确定。
extends RefCounted
class_name CardSort

const RARITY_RANK := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
const KEYS := ["rarity", "cost", "level", "actionable"]   # 控件遍历顺序

# 该卡是否「有可做的养成」（红点/可养成排序共用此唯一定义）：
# 未解锁 → 碎片够可解锁；已解锁 → 金够可升级 或 碎片+金够可升阶。
static func actionable(cache, config, card_id: String) -> bool:
	if cache == null or config == null:
		return false
	if not cache.is_unlocked(card_id):
		return cache.can_unlock(card_id, config)
	var st: Dictionary = cache.card_state(card_id)
	var level := int(st.get("level", 1))
	var rank := int(st.get("rank", 1))
	if level < int(cache.level_cap(rank, config)) and int(cache.gold) >= int(cache.upgrade_cost(card_id, config)):
		return true
	var rc: Dictionary = cache.rank_up_cost(card_id, config)
	if not rc.is_empty() and int(st.get("shards", 0)) >= int(rc.get("shards", 1 << 30)) and int(cache.gold) >= int(rc.get("gold", 1 << 30)):
		return true
	return false

# 排序键值（越小越靠前，再由 ascending 翻转）。未知卡/缺字段 → 0。
static func key_value(card_id: String, cache, config, key: String) -> int:
	if config == null:
		return 0
	match key:
		"rarity":
			return int(RARITY_RANK.get(str(config.get_card_progression(card_id).get("rarity", "")), 0))
		"cost":
			return int(config.get_card(card_id).get("elixir_cost", 0))
		"level":
			var st: Dictionary = cache.card_state(card_id) if cache != null else {}
			return int(st.get("rank", 1)) * 100 + int(st.get("level", 1))   # 阶为主、等级为次
		"actionable":
			return 1 if actionable(cache, config, card_id) else 0
	return 0

# 返回排序后的 id（稳定：同键值保持原序）。ascending=true → 小键值在前。
static func sort_ids(card_ids: Array, cache, config, key: String, ascending: bool = true) -> Array:
	var rows: Array = []
	for i in card_ids.size():
		var cid := String(card_ids[i])
		rows.append({"id": cid, "v": key_value(cid, cache, config, key), "i": i})
	rows.sort_custom(func(a, b):
		if a["v"] != b["v"]:
			return a["v"] < b["v"] if ascending else a["v"] > b["v"]
		return a["i"] < b["i"])   # 稳定：同值保持原下标顺序
	var out: Array = []
	for r in rows:
		out.append(r["id"])
	return out
