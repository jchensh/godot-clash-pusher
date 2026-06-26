# PlayerData —— V5 单机玩家存档数据（钱包 + 卡牌养成 + 关卡进度 + 挂机）。
#
# V5-S0 草案：只定义数据结构 + 默认新档 + to_dict/load_dict 往返。
# 完整的 SaveSystem 接线、战力计算、解锁解算留 V5-S2；升级/升阶改值留 V5-S4/S5。
# 纯逻辑、确定性、可 headless 单测。存读档由 SaveSystem 落 user://（V5-S2）。
#
# 踩坑遵循（V3-4d）：to_dict/load_dict/init_new 全为**实例方法、不引用自身 class_name**，
# 避免新脚本在 .uid/全局注册前被 test runner 预检判失败。调用方用 `PlayerData.new()` 后再调。
extends RefCounted
class_name PlayerData

# 默认新档解锁的初始 8 张（= levels.json level_01 默认卡组 / card_progression starter=true）。
const STARTER_CARDS := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]

var gold: int = 0
var gems: int = 0
# card_id -> { level:int, rank:int, shards:int, unlocked:bool }
var cards: Dictionary = {}
# stage_id -> { stars:int, cleared:bool }
var stages: Dictionary = {}
var highest_cleared: String = ""
var idle_last_collect_ts: int = 0

# 构造一份全新玩家档：传入全部 card_id（来自 cards.json / card_progression.json），
# 每卡建 level1/rank1/shards0，starter 集合内的 unlocked=true、其余 false。
func init_new(all_card_ids: Array) -> void:
	gold = 0
	gems = 0
	cards = {}
	stages = {}
	highest_cleared = ""
	idle_last_collect_ts = 0
	for cid in all_card_ids:
		cards[String(cid)] = {
			"level": 1,
			"rank": 1,
			"shards": 0,
			"unlocked": STARTER_CARDS.has(String(cid)),
		}

func is_unlocked(card_id: String) -> bool:
	var c = cards.get(card_id, {})
	return typeof(c) == TYPE_DICTIONARY and bool(c.get("unlocked", false))

func card_state(card_id: String) -> Dictionary:
	var c = cards.get(card_id, {})
	return c if typeof(c) == TYPE_DICTIONARY else {}

func unlocked_card_ids() -> Array:
	var out: Array = []
	for cid in cards:
		if is_unlocked(String(cid)):
			out.append(String(cid))
	return out

# —— 存档往返（schema 见 PLAN_V5 §9；实例方法不引用自身 class_name） ——
func to_dict() -> Dictionary:
	return {
		"wallet": { "gold": gold, "gems": gems },
		"cards": cards.duplicate(true),
		"stages": stages.duplicate(true),
		"highest_cleared": highest_cleared,
		"idle": { "last_collect_ts": idle_last_collect_ts },
	}

func load_dict(d: Dictionary) -> void:
	var w = d.get("wallet", {})
	if typeof(w) != TYPE_DICTIONARY:
		w = {}
	gold = int(w.get("gold", 0))
	gems = int(w.get("gems", 0))
	var c = d.get("cards", {})
	cards = (c as Dictionary).duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}
	var s = d.get("stages", {})
	stages = (s as Dictionary).duplicate(true) if typeof(s) == TYPE_DICTIONARY else {}
	highest_cleared = String(d.get("highest_cleared", ""))
	var idle = d.get("idle", {})
	if typeof(idle) != TYPE_DICTIONARY:
		idle = {}
	idle_last_collect_ts = int(idle.get("last_collect_ts", 0))

# V5-N7（决策 48）：从**服务器权威快照**重建自身（瘦客户端化）。
# server_state 形状 = economy_client._state_to_dict 输出（gold/gems/idle_last_collect_ts/
# highest_cleared 在顶层；cards={cid:{level,rank,shards,unlocked}}；stages={sid:{stars,cleared}}）。
# 与 load_dict 的区别：load_dict 读本地存档 schema（wallet/idle 嵌套），本方法读服务器 schema。
# all_card_ids 用于 ensure 缺失卡（服务器快照可能不含未触发的卡）。服务器为准、本地被覆盖。
func apply_server_state(server_state: Dictionary, all_card_ids: Array) -> void:
	gold = int(server_state.get("gold", 0))
	gems = int(server_state.get("gems", 0))
	idle_last_collect_ts = int(server_state.get("idle_last_collect_ts", 0))
	highest_cleared = String(server_state.get("highest_cleared", ""))
	var c = server_state.get("cards", {})
	cards = (c as Dictionary).duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}
	var s = server_state.get("stages", {})
	stages = (s as Dictionary).duplicate(true) if typeof(s) == TYPE_DICTIONARY else {}
	ensure_cards(all_card_ids)   # 服务器快照缺的卡补默认锁定条目（保持卡池一致）

# —— V5-S2：养成/战力解算（config 注入、不存储；纯函数式查询） ——

# 本卡当前出兵数值乘区 = 等级乘 × 阶乘（读 economy 曲线）。
# 等级乘 = 1 + (level-1)·level_stat_per_level；阶乘 = rank_stat_mult^(rank-1)。
# 这是 S1 我方 spawn 乘区的来源（V5-S4 接进战斗：出牌时按本卡 level/rank 注入）。
func card_stat_mult(card_id: String, config) -> float:
	var st := card_state(card_id)
	if st.is_empty() or config == null:
		return 1.0
	var econ: Dictionary = config.get_economy()
	var per_level := float(econ.get("level_stat_per_level", 0.0))
	var rank_mult := float(econ.get("rank_stat_mult", 1.0))
	var level := int(st.get("level", 1))
	var rank := int(st.get("rank", 1))
	var lvl_factor := 1.0 + float(maxi(level - 1, 0)) * per_level
	return lvl_factor * pow(rank_mult, float(maxi(rank - 1, 0)))

# 本卡战力 = base_power（card_progression）× 数值乘区。
func card_power(card_id: String, config) -> float:
	if config == null:
		return 0.0
	var cp: Dictionary = config.get_card_progression(card_id)
	if cp.is_empty():
		return 0.0
	return float(cp.get("base_power", 0)) * card_stat_mult(card_id, config)

# 队伍战力 = 卡组各卡战力之和（取整）。
func team_power(card_ids: Array, config) -> int:
	var total := 0.0
	for cid in card_ids:
		total += card_power(String(cid), config)
	return int(round(total))

# 解锁解算：未解锁 且 碎片 ≥ 该稀有度解锁门槛 → 可解锁（实际解锁动作 V5-S6）。
func can_unlock(card_id: String, config) -> bool:
	if is_unlocked(card_id) or config == null:
		return false
	var cp: Dictionary = config.get_card_progression(card_id)
	if cp.is_empty():
		return false
	var unlock_tbl = config.get_economy().get("unlock_shards", {})
	if typeof(unlock_tbl) != TYPE_DICTIONARY:
		return false
	var need := int(unlock_tbl.get(str(cp.get("rarity", "")), 1 << 30))
	return int(card_state(card_id).get("shards", 0)) >= need

# 补齐缺失卡条目（存档读入后若卡池新增了卡 → 默认锁定 level1/rank1；已有卡不动）。
func ensure_cards(all_card_ids: Array) -> void:
	for cid in all_card_ids:
		var key := String(cid)
		if not cards.has(key):
			cards[key] = {"level": 1, "rank": 1, "shards": 0, "unlocked": STARTER_CARDS.has(key)}

# —— V5-S4：卡牌升级（金币 sink + 数值曲线 + 等级上限受阶限制） ——

# 本阶等级上限（economy.level_cap_per_rank[rank]）。
func level_cap(rank: int, config) -> int:
	if config == null:
		return 1
	var tbl = config.get_economy().get("level_cap_per_rank", {})
	if typeof(tbl) != TYPE_DICTIONARY:
		return 1
	return int(tbl.get(str(rank), 1))

# 本卡当前 level→level+1 的金币成本（随等级线性上涨）。
func upgrade_cost(card_id: String, config) -> int:
	if config == null:
		return 1 << 30
	var cp: Dictionary = config.get_card_progression(card_id)
	var rarity := str(cp.get("rarity", ""))
	var econ: Dictionary = config.get_economy()
	var base_tbl = econ.get("upgrade_cost_base", {})
	if typeof(base_tbl) != TYPE_DICTIONARY or not base_tbl.has(rarity):
		return 1 << 30
	var base := float(base_tbl.get(rarity, 0))
	var growth := float(econ.get("upgrade_cost_growth", 0.0))
	var level := int(card_state(card_id).get("level", 1))
	return int(round(base * (1.0 + float(maxi(level - 1, 0)) * growth)))

# 升级一张卡：花金币、level+1，受当前阶的等级上限钳制。
# 未解锁 / 已达本阶上限（需先升阶）/ 金币不足 → false（不改状态）。
func upgrade_card(card_id: String, config) -> bool:
	if not is_unlocked(card_id) or config == null:
		return false
	var st := card_state(card_id)
	if st.is_empty():
		return false
	var level := int(st.get("level", 1))
	var rank := int(st.get("rank", 1))
	if level >= level_cap(rank, config):
		return false
	var cost := upgrade_cost(card_id, config)
	if gold < cost:
		return false
	gold -= cost
	cards[card_id]["level"] = level + 1
	return true

# —— V5-S5：卡牌升阶（碎片 + 金币 → 数值跳 + 解锁技能积木 + 抬等级上限） ——

# 最高阶 = economy.level_cap_per_rank 的最大 key。
func _max_rank(config) -> int:
	if config == null:
		return 1
	var tbl = config.get_economy().get("level_cap_per_rank", {})
	var m := 1
	if typeof(tbl) == TYPE_DICTIONARY:
		for k in tbl:
			m = maxi(m, int(k))
	return m

# 本卡 rank→rank+1 的成本 {shards, gold}（economy.rank_up[rarity][rank-1]）。空 = 无法升阶。
func rank_up_cost(card_id: String, config) -> Dictionary:
	if config == null:
		return {}
	var cp: Dictionary = config.get_card_progression(card_id)
	var tbl = config.get_economy().get("rank_up", {})
	if typeof(tbl) != TYPE_DICTIONARY:
		return {}
	var arr = tbl.get(str(cp.get("rarity", "")), [])
	var i := int(card_state(card_id).get("rank", 1)) - 1   # rank1→2 = index 0
	if typeof(arr) == TYPE_ARRAY and i >= 0 and i < arr.size() and typeof(arr[i]) == TYPE_DICTIONARY:
		return arr[i]
	return {}

# 升阶一张卡：花碎片 + 金币、rank+1（抬等级上限、解锁技能积木）。
# 未解锁 / 已达最高阶 / 碎片或金币不足 → false（不改状态）。
func rank_up_card(card_id: String, config) -> bool:
	if not is_unlocked(card_id) or config == null:
		return false
	var st := card_state(card_id)
	if st.is_empty():
		return false
	var rank := int(st.get("rank", 1))
	if rank >= _max_rank(config):
		return false
	var cost := rank_up_cost(card_id, config)
	var need_shards := int(cost.get("shards", 1 << 30))
	var need_gold := int(cost.get("gold", 1 << 30))
	var have_shards := int(st.get("shards", 0))
	if have_shards < need_shards or gold < need_gold:
		return false
	cards[card_id]["shards"] = have_shards - need_shards
	gold -= need_gold
	cards[card_id]["rank"] = rank + 1
	return true

# —— V5-S6：经济产出（关卡奖励 / 挂机离线金币 / 解锁新卡 / 通用奖励占位） ——

# 通用奖励发放（任务/成就/章节宝箱占位复用）：reward = {gold, gems, shards:{card:n}}。返回实发。
func grant_reward(reward: Dictionary) -> Dictionary:
	var granted := {"gold": 0, "gems": 0, "shards": {}}
	if typeof(reward) != TYPE_DICTIONARY:
		return granted
	var g := int(reward.get("gold", 0))
	gold += g
	granted["gold"] = g
	var gm := int(reward.get("gems", 0))
	gems += gm
	granted["gems"] = gm
	var sh = reward.get("shards", {})
	if typeof(sh) == TYPE_DICTIONARY:
		for cid in sh:
			_add_shards(String(cid), int(sh[cid]), granted["shards"])
	return granted

func _add_shards(card_id: String, n: int, granted_map: Dictionary) -> void:
	if n <= 0 or not cards.has(card_id):
		return
	cards[card_id]["shards"] = int(cards[card_id].get("shards", 0)) + n
	granted_map[card_id] = int(granted_map.get(card_id, 0)) + n

# 发关卡奖励：first=首通(大额 first_clear) / 否则 repeat(小额)。rng（可选）→ shard_drop 概率掉落。返回实发。
func grant_stage_reward(stage_id: String, first: bool, config, rng = null) -> Dictionary:
	if config == null:
		return {"gold": 0, "gems": 0, "shards": {}}
	var stage: Dictionary = config.get_stage(stage_id)
	var base_reward = stage.get("first_clear", {}) if first else stage.get("repeat", {})
	var granted := grant_reward(base_reward if typeof(base_reward) == TYPE_DICTIONARY else {})
	if rng != null:
		var drop = stage.get("shard_drop", {})
		if typeof(drop) == TYPE_DICTIONARY:
			for cid in drop:
				var d = drop[cid]
				if typeof(d) == TYPE_DICTIONARY and rng.randf() < float(d.get("chance", 0.0)):
					_add_shards(String(cid), int(d.get("amount", 0)), granted["shards"])
	return granted

# 解锁一张卡：碎片够 → 扣碎片 + 置 unlocked。返回是否成功。
func unlock_card(card_id: String, config) -> bool:
	if not can_unlock(card_id, config):
		return false
	var cp: Dictionary = config.get_card_progression(card_id)
	var unlock_tbl = config.get_economy().get("unlock_shards", {})
	var need := int(unlock_tbl.get(str(cp.get("rarity", "")), 1 << 30))
	cards[card_id]["shards"] = int(card_state(card_id).get("shards", 0)) - need
	cards[card_id]["unlocked"] = true
	return true

# —— 挂机离线金币（本地时钟、按最高通关章节产、封顶、领取清零；now_ts 由 caller 注入，不在逻辑层取系统时间） ——

func _highest_chapter(config) -> int:
	if highest_cleared == "" or config == null:
		return 0
	return int(config.get_stage(highest_cleared).get("chapter", 0))

func idle_rate_per_hour(config) -> int:
	if config == null:
		return 0
	var idle = config.get_economy().get("idle", {})
	if typeof(idle) != TYPE_DICTIONARY:
		return 0
	return int(idle.get("gold_per_hour_per_chapter", 0)) * _highest_chapter(config)

# 自 last_collect 以来累计的离线金币（封顶 cap_hours）。未设基准(<=0) → 0。
func idle_pending(now_ts: int, config) -> int:
	if config == null or idle_last_collect_ts <= 0:
		return 0
	var idle = config.get_economy().get("idle", {})
	if typeof(idle) != TYPE_DICTIONARY:
		return 0
	var elapsed := maxi(now_ts - idle_last_collect_ts, 0)
	var cap_h := float(idle.get("cap_hours", 0))
	var hours := minf(float(elapsed) / 3600.0, cap_h)
	return int(floor(float(idle_rate_per_hour(config)) * hours))

# 领取离线金币：发到 gold + 把基准设为 now_ts。返回实发。
func collect_idle(now_ts: int, config) -> int:
	var pend := idle_pending(now_ts, config)
	gold += pend
	idle_last_collect_ts = now_ts
	return pend
