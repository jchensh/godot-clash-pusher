# PveReplay —— KAN-79：PVE 战斗重放验证器（纯逻辑，服务端 verifier 经 tools/pve_verify.gd 调用）。
#
# 输入 = 录制材料（关卡/卡组/服务器权威养成快照/双方指令流/周期哈希），输出 = verdict。
# 重放不跑 AI（AI 的出牌也在指令流里）——逐 bit 复现原局的 tick 内操作顺序：
#   原局 update()：       [玩家在间隙出牌] → regen → [AI 在 tick 内出牌] → battle.step
#   重放 第 t 个 tick：   gap 牌(t-1)      → regen → in 牌(t)            → battle.step
# 每 HASH_EVERY tick 与录制的 state_hash 比对：任何篡改（改内存/改指令/改养成）→ 分叉现形。
#
# 确定性前提与 lockstep 相同（10Hz 无随机 float64 sim）；出牌落点已在 Player.try_play_card
# 量化到毫 tile（录制值=执行值）。纯逻辑、可 headless 单测。
extends RefCounted
class_name PveReplay

const MatchScript = preload("res://logic/match.gd")
const PlayerDataScript = preload("res://logic/player_data.gd")
const SimClockScript = preload("res://logic/sim_clock.gd")
const BattleScript = preload("res://logic/battle.gd")

# 重放一局。参数：
#   config      — ConfigLoader（与录制端同版本配置）
#   stage_id    — 闯关关卡 id
#   deck        — 玩家 8 张卡组（服务器记录）
#   progress    — {card_id: {level:int, rank:int}} 开战时服务器权威养成快照
#   cmds        — [{t:int, ph:int(0=gap/1=in), s:int(1/2), c:String, x:int, y:int}] 毫 tile
#   hashes      — [{t:int, h:String(hex)}] 每 10 tick 的录制哈希
#   max_ticks   — 安全上限（防坏数据死循环）
# 返回 verdict：
#   {status:"pass"|"mismatch"|"error", reason:String, mismatch_tick:int,
#    win:bool, ticks:int, king_hp_permille:int}
static func replay(config, stage_id: String, deck: Array, progress: Dictionary,
		cmds: Array, hashes: Array, max_ticks: int = 6000) -> Dictionary:
	if config == null or deck.is_empty():
		return _err("bad input: no config/deck")
	var m = MatchScript.new(config)
	# K4：progress 的 "_towers" 保留键 = 王国城防塔加成（服务器 PveStart 写入）——
	# 与客户端 sim 同源注入，别当卡牌解析。
	var towers: Dictionary = {}
	var tw = progress.get("_towers")
	if typeof(tw) == TYPE_DICTIONARY:
		towers = {"hp_pct": int(tw.get("hp_pct", 0)), "dmg_pct": int(tw.get("dmg_pct", 0))}
	m.setup_stage(stage_id, deck, _pd(progress), towers)
	if m.battle == null or m.battle.arena == null:
		return _err("stage setup failed: %s" % stage_id)

	# 按 tick 分桶（gap 桶键 = 出牌时已完成的 tick；in 桶键 = 出牌所在 tick）。
	# 同 tick 同相位内保持录制顺序（Array 追加序）。
	var gap_by_tick := {}
	var in_by_tick := {}
	for c in cmds:
		if typeof(c) != TYPE_DICTIONARY:
			return _err("bad cmd entry")
		var t := int(c.get("t", -1))
		var ph := int(c.get("ph", -1))
		if t < 0 or (ph != 0 and ph != 1):
			return _err("bad cmd tick/phase")
		var bucket = gap_by_tick if ph == 0 else in_by_tick
		if not bucket.has(t):
			bucket[t] = []
		bucket[t].append(c)
	var hash_by_tick := {}
	for h in hashes:
		if typeof(h) != TYPE_DICTIONARY:
			return _err("bad hash entry")
		var ht := int(h.get("t", -1))
		if ht <= 0:
			return _err("bad hash tick")
		hash_by_tick[ht] = String(h.get("h", ""))

	# 跑到 battle 结束（复算胜负/王塔血）或安全上限；空 tick 推进很快，上限只防坏数据。
	var t := 1
	while t <= max_ticks:
		# ① gap 牌：原局发生在「第 t-1 tick 完成后、第 t tick 的 regen 前」。
		for c in gap_by_tick.get(t - 1, []):
			_apply(m, c)
		# ② regen（与 update 同序）。
		m.player.regen(SimClockScript.TICK_DELTA)
		m.opponent.regen(SimClockScript.TICK_DELTA)
		# ③ in 牌：原局 AI 在本 tick 的 controller.tick 内出牌（regen 后、step 前）。
		for c in in_by_tick.get(t, []):
			_apply(m, c)
		# ④ step + 哈希对帐。
		m.battle.step(SimClockScript.TICK_DELTA)
		if hash_by_tick.has(t):
			var got: String = m.state_hash().hex_encode()
			if got != hash_by_tick[t]:
				return {
					"status": "mismatch", "reason": "hash mismatch at tick %d" % t,
					"mismatch_tick": t, "win": false, "ticks": t,
					"king_hp_permille": _king_permille(m),
				}
		if m.battle.is_over():
			break
		t += 1

	return {
		"status": "pass", "reason": "", "mismatch_tick": -1,
		"win": m.battle.result == BattleScript.RESULT_PLAYER_WIN,
		"ticks": t,
		"king_hp_permille": _king_permille(m),
	}

# {card_id:{level,rank}} → 最小 PlayerData（与 battle_client._inject_progress 同构；
# 用服务器快照而非客户端缓存——改本地缓存的养成会在这里 hash 对不上）。
static func _pd(progress: Dictionary):
	var pd = PlayerDataScript.new()
	for cid in progress:
		if String(cid).begins_with("_"):   # K4："_towers" 等保留键不是卡
			continue
		var e = progress[cid]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		pd.cards[String(cid)] = {
			"level": int(e.get("level", 1)), "rank": int(e.get("rank", 1)),
			"shards": 0, "unlocked": true,
		}
	return pd

# 应用一条录制指令：按 side 选 Player、card_id 反查手牌、毫 tile 还原落点。
# 卡不在手/非法 → 确定性 no-op（与录制端一致：录的都是成功出牌，正常必命中）。
static func _apply(m, c: Dictionary) -> void:
	var p = m.player if int(c.get("s", 0)) == 1 else (m.opponent if int(c.get("s", 0)) == 2 else null)
	if p == null:
		return
	var idx: int = p.deck.get_hand().find(String(c.get("c", "")))
	if idx < 0:
		return
	p.try_play_card(idx, Vector2(int(c.get("x", 0)) / 1000.0, int(c.get("y", 0)) / 1000.0))

static func _king_permille(m) -> int:
	for tw in m.battle.player_towers:
		if tw.is_king():
			return int(round(clampf(tw.hp / tw.max_hp, 0.0, 1.0) * 1000.0))
	return 0

static func _err(reason: String) -> Dictionary:
	return {"status": "error", "reason": reason, "mismatch_tick": -1,
		"win": false, "ticks": 0, "king_hp_permille": 0}
