extends "res://tests/test_case.gd"

## KAN-79：PVE 录制→重放闭环单测（层2 的命门）。
## 真实一局（真 config + setup_stage + 真 AIController 驱动敌方 + 玩家间隙出牌）由
## PveRecorder 录制，PveReplay 重放必须逐 hash 全等（pass）；篡改任一指令/养成 → mismatch
## （证明重放对帐真能抓「改内存/改指令/改本地养成缓存」）。录制钩子必须零侵入 sim。

const ConfigLoaderScript := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const PlayerDataScript := preload("res://logic/player_data.gd")
const PveReplayScript := preload("res://logic/pve_replay.gd")
const PveRecorderScript := preload("res://net/pve_recorder.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")

const DECK := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]
const STAGE := "stage_1_1"

var _loader

func _loader_ready():
	if _loader == null:
		_loader = ConfigLoaderScript.new()
		_loader.load_all()
	return _loader

func _progress() -> Dictionary:
	# 玩家练过两张卡（覆盖乘区路径；服务器快照形状）。
	return {"knight": {"level": 4, "rank": 2}, "giant": {"level": 3, "rank": 1}}

func _pd_from(progress: Dictionary):
	var pd = PlayerDataScript.new()
	for cid in progress:
		pd.cards[cid] = {"level": progress[cid]["level"], "rank": progress[cid]["rank"], "shards": 0, "unlocked": true}
	return pd

# 跑一局真实 PVE（AI 驱动敌方 + 玩家周期在间隙出牌），录制并返回
# {cmds, hashes(hex 化), win, ticks, recorder}。ticks_budget 控制局长。
func _play_recorded(ticks_budget: int, towers: Dictionary = {}) -> Dictionary:
	var config = _loader_ready()
	var m = MatchScript.new(config)
	m.setup_stage(STAGE, DECK, _pd_from(_progress()), towers)
	m.set_opponent_controller(AIControllerScript.new(m, config, m.ai_difficulty))
	var rec = PveRecorderScript.new()
	rec.attach(m)
	# 玩家行为脚本：每当出得起手牌第 0 格就出到固定合法点（间隙出牌 = gap 相位）。
	var p_pos := _valid_pos(m.battle.arena, 0)
	var frames: int = int(ceil(ticks_budget / 3.0))
	for f in frames:
		if m.player.can_play(0):
			m.player.try_play_card(0, p_pos)
		m.update(0.3)   # 每帧 3 tick（考验一帧多 tick 时的相位/戳正确性）
		if m.is_over():
			break
	var hex_hashes: Array = []
	for h in rec.hashes:
		hex_hashes.append({"t": h["t"], "h": (h["h"] as PackedByteArray).hex_encode()})
	return {
		"cmds": rec.cmds.duplicate(true), "hashes": hex_hashes,
		"win": m.battle.result == m.battle.RESULT_PLAYER_WIN, "ticks": m.pve_tick,
		"recorder": rec, "match": m,
	}

func _valid_pos(arena, owner_id: int) -> Vector2:
	var ys: Array = range(arena.grid_h) if owner_id == 1 else range(arena.grid_h - 1, -1, -1)
	for yy in ys:
		for xx in range(arena.grid_w):
			var p := Vector2(xx + 0.5, yy + 0.5)
			if arena.can_deploy(owner_id, p):
				return p
	return Vector2(arena.grid_w * 0.5, arena.grid_h * 0.5)


func test_record_then_replay_passes() -> void:
	var rec := _play_recorded(400)
	assert_true((rec["cmds"] as Array).size() > 0, "一局里应录到出牌（玩家+AI）")
	assert_true((rec["hashes"] as Array).size() >= 3, "应录到周期哈希")
	var has_ai := false
	for c in rec["cmds"]:
		if int(c["s"]) == 2:
			has_ai = true
	assert_true(has_ai, "AI 的出牌也应被录（in 相位）")
	var v: Dictionary = PveReplayScript.replay(_loader_ready(), STAGE, DECK, _progress(), rec["cmds"], rec["hashes"])
	assert_eq(String(v["status"]), "pass", "重放应逐 hash 全等: %s" % String(v.get("reason", "")))

func test_tampered_cmd_forks() -> void:
	var rec := _play_recorded(300)
	var cmds: Array = rec["cmds"]
	assert_true(cmds.size() > 0, "需要至少一条指令")
	# 篡改第一条出牌的落点（作弊者伪造指令流）→ 重放 hash 必分叉。
	cmds[0]["x"] = int(cmds[0]["x"]) + 3000
	var v: Dictionary = PveReplayScript.replay(_loader_ready(), STAGE, DECK, _progress(), cmds, rec["hashes"])
	assert_eq(String(v["status"]), "mismatch", "篡改指令后重放应 mismatch")

func test_tampered_progress_forks() -> void:
	# 客户端本地把养成缓存改满级打的局（hash 反映满级数值），但服务器快照是真实养成
	# → 重放用服务器快照 → hash 对不上（改本地缓存作弊现形）。
	var rec := _play_recorded(300)
	var fake := {"knight": {"level": 10, "rank": 3}, "giant": {"level": 10, "rank": 3}}
	# 用假养成重打一局同指令（模拟作弊端的 hash 来源）：直接用真录制 + 假快照重放即可。
	var v: Dictionary = PveReplayScript.replay(_loader_ready(), STAGE, DECK, fake, rec["cmds"], rec["hashes"])
	assert_eq(String(v["status"]), "mismatch", "养成快照不符应 mismatch")

func test_recorder_is_sim_neutral() -> void:
	# 挂录制器与否，同输入序列的 sim 状态必须逐 bit 一致（观察者零侵入）。
	var config = _loader_ready()
	var m1 = MatchScript.new(config)
	m1.setup_stage(STAGE, DECK, _pd_from(_progress()))
	var m2 = MatchScript.new(config)
	m2.setup_stage(STAGE, DECK, _pd_from(_progress()))
	var rec = PveRecorderScript.new()
	rec.attach(m1)   # 只挂 m1
	var pos := _valid_pos(m1.battle.arena, 0)
	for f in 80:
		if m1.player.can_play(0):
			m1.player.try_play_card(0, pos)
		if m2.player.can_play(0):
			m2.player.try_play_card(0, pos)
		m1.update(0.25)
		m2.update(0.25)
		assert_eq(m1.state_hash().hex_encode(), m2.state_hash().hex_encode(), "录制器不得影响 sim（帧 %d）" % f)

func test_replay_reports_win_and_ticks() -> void:
	# 3000 tick 预算 > match_duration（超时也 is_over）→ 原局必然打完，胜负可复算。
	var rec := _play_recorded(3000)
	assert_true((rec["match"] as Object).is_over(), "预算内原局应已结束（含超时判定）")
	var v: Dictionary = PveReplayScript.replay(_loader_ready(), STAGE, DECK, _progress(), rec["cmds"], rec["hashes"])
	assert_eq(String(v["status"]), "pass")
	assert_eq(bool(v["win"]), bool(rec["win"]), "重放复算的胜负应与原局一致")
	assert_eq(int(v["ticks"]), int(rec["ticks"]), "重放复算的时长应与原局一致")


func test_failed_flush_requeues_evidence_and_reports_false() -> void:
	var recorder = PveRecorderScript.new()
	recorder._flushing = true
	recorder.cmds = [{"t": 30}]
	recorder.hashes = [{"t": 40}]
	var ok := recorder._finish_flush([{"t": 10}, {"t": 20}], [{"t": 10}], {"ok": false, "status_code": 0})
	assert_false(ok, "失败 flush 不得允许战后离场")
	assert_false(recorder._flushing, "失败后释放 single-flight 供重试")
	assert_eq(recorder.cmds.size(), 3, "发送失败的指令回队头")
	assert_eq(int(recorder.cmds[0]["t"]), 10, "重排保持发送批次在前")
	assert_eq(recorder.hashes.size(), 2, "发送失败的哈希回队头")


func test_successful_flush_reports_true_without_requeue() -> void:
	var recorder = PveRecorderScript.new()
	recorder._flushing = true
	var ok := recorder._finish_flush([{"t": 10}], [{"t": 10}], {"ok": true})
	assert_true(ok, "成功 flush 才允许战后离场")
	assert_false(recorder._flushing, "成功后释放 single-flight")
	assert_true(recorder.cmds.is_empty() and recorder.hashes.is_empty(), "成功批次不回队")


# K4：城防塔加成进重放证据链——录制端注入 (hp/dmg pct)、progress 带 "_towers" 保留键
# → 重放同源注入逐 hash 全等；缺键（伪造无加成快照）→ 必分叉（塔数值进 state_hash）。
func test_tower_bonus_replay_roundtrip_and_forks() -> void:
	var towers := {"hp_pct": 30, "dmg_pct": 20}
	var rec := _play_recorded(300, towers)
	assert_true((rec["hashes"] as Array).size() >= 2, "应录到周期哈希")
	var prog: Dictionary = _progress().duplicate(true)
	prog["_towers"] = {"hp_pct": 30, "dmg_pct": 20}
	var v: Dictionary = PveReplayScript.replay(_loader_ready(), STAGE, DECK, prog, rec["cmds"], rec["hashes"])
	assert_eq(String(v["status"]), "pass", "带 _towers 重放应全等: %s" % String(v.get("reason", "")))
	var v2: Dictionary = PveReplayScript.replay(_loader_ready(), STAGE, DECK, _progress(), rec["cmds"], rec["hashes"])
	assert_eq(String(v2["status"]), "mismatch", "缺 _towers 重放应分叉（塔数值进 hash）")
