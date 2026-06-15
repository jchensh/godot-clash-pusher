# RunRewards —— 战间奖励的确定性候选生成（V3-4b draft 卡 / V3-4d relic 奖励）。
#
# 三选一（或 N 选一）：从候选池剔除已持有，**确定性**洗牌（seeded RNG，同 seed → 同结果）
# 取前 n 个。无随机副作用、可 headless 单测。draft 选中的卡由 RunState 追加进 run 卡组、
# 带入下一场（Match 用 run 卡组建 Deck）。
extends RefCounted
class_name RunRewards

# 卡牌 draft 候选：卡池中**不在当前 run 卡组**里的卡，确定性取 n 张。
static func offer_cards(all_card_ids: Array, owned_deck: Array, n: int, pick_seed: int) -> Array:
	return _pick_distinct(_exclude(all_card_ids, owned_deck), n, pick_seed)

# relic 奖励候选：可用 relic（base + 已解锁）中**未持有**的，确定性取 n 个。
static func offer_relics(available_relic_ids: Array, owned_relics: Array, n: int, pick_seed: int) -> Array:
	return _pick_distinct(_exclude(available_relic_ids, owned_relics), n, pick_seed)

static func _exclude(pool: Array, owned: Array) -> Array:
	var out: Array = []
	for x in pool:
		if not (x in owned):
			out.append(x)
	return out

# 确定性洗牌取前 n（seeded Fisher-Yates；Array.shuffle 用全局 RNG 不确定，故自写）。
static func _pick_distinct(candidates: Array, n: int, pick_seed: int) -> Array:
	var pool: Array = candidates.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = pick_seed
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(n, pool.size()))
