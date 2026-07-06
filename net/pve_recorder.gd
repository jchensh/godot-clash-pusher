extends RefCounted
## KAN-79：PVE 战斗录制器 + 周期批量上报（客户端侧）。
## attach 到 Match：挂 tick_observer（每 10 tick 记 state_hash）+ 双方 Player 的
## play_observer（记出牌指令：tick + 相位 gap/in + side + card + 毫 tile 落点）。
## flush 走 /v5/pve/report 批量追加；服务器按批次到达时间记录 → 时序真实性
## （想上报完整一局必须让墙钟真实流逝）。战后 view 调最后一次 flush 兜底全量。
## 录制/相位语义与重放器（logic/pve_replay.gd）严格对偶。纯 RefCounted、无场景依赖，可单测。
class_name PveRecorder

const HASH_EVERY := 10          # 与 lockstep 的 HASH_EVERY 同款
const FLUSH_INTERVAL := 10.0    # 秒；攒批周期

const UnitScript = preload("res://logic/unit.gd")

var match_obj = null
var battle_id: int = 0          # PveStart 下发；<=0 时不上报（离线/失败降级）
var deploy_count: int = 0       # 玩家(side1)出牌总数（战报摘要用）
var cmds: Array = []            # 未上报指令 [{t,ph,s,c,x,y}]
var hashes: Array = []          # 未上报哈希 [{t:int, h:PackedByteArray}]
var _accum := 0.0
var _flushing := false


## 挂到一局 Match（在 setup_stage 之后、开打之前调）。
func attach(match_) -> void:
	match_obj = match_
	match_obj.tick_observer = self
	match_obj.player.play_observer = self
	match_obj.opponent.play_observer = self


## Player.try_play_card 成功回调（双方都挂）。pos 已被量化到毫 tile（录制值=执行值）。
## tick 戳语义（与 pve_replay 严格对偶）：gap 牌记「已完成 tick 数 N」（间隙左边界，重放在
## 第 N+1 个 tick 的 regen 前应用）；in 牌记「所在 tick 序号 N+1」（pve_tick 在 tick 完成后
## 才 ++，AI 出牌时计数还是 N，故 +1；重放在第 N+1 个 tick 的 regen 后应用）。
func on_card_played(owner_id: int, card_id: String, pos: Vector2) -> void:
	var side := 1 if owner_id == UnitScript.OWNER_PLAYER else 2
	if side == 1:
		deploy_count += 1
	cmds.append({
		"t": match_obj.pve_tick + (1 if match_obj.in_tick else 0),
		"ph": 1 if match_obj.in_tick else 0,   # in=AI 在 tick 内出 / gap=玩家在间隙出
		"s": side,
		"c": card_id,
		"x": int(round(pos.x * 1000.0)),
		"y": int(round(pos.y * 1000.0)),
	})


## Match.update 每 tick 完成后回调。
func on_tick(t: int) -> void:
	if t % HASH_EVERY == 0:
		hashes.append({"t": t, "h": match_obj.state_hash()})


## view 每帧调（fire-and-forget 协程）：攒批周期到 → 上报一批。
func poll(delta: float, econ_client, http, token: String) -> void:
	_accum += delta
	if _accum >= FLUSH_INTERVAL:
		_accum = 0.0
		await flush(econ_client, http, token)


## 把当前攒的 cmds/hashes 发一批。失败 → 数据放回队头下批重试（尽力而为，保序）。
func flush(econ_client, http, token: String) -> void:
	if _flushing or battle_id <= 0 or (cmds.is_empty() and hashes.is_empty()):
		return
	_flushing = true
	var send_cmds := cmds
	var send_hashes := hashes
	cmds = []
	hashes = []
	var res: Dictionary = await econ_client.pve_report(http, token, battle_id, send_cmds, send_hashes)
	if bool(res.get("ok", false)):
		Log.d("[V5][pve] 上报批次 ok（%d 指令 / %d 哈希）" % [send_cmds.size(), send_hashes.size()])
	else:
		cmds = send_cmds + cmds
		hashes = send_hashes + hashes
		Log.w("[V5][pve] 上报批次失败 status=%d（并入下批重试）" % int(res.get("status_code", 0)))
	_flushing = false


## 战报摘要（StageClear 附带；king_hp_permille 由 view 按王塔血算好传入）。
func summary(king_hp_permille: int) -> Dictionary:
	return {
		"duration_ticks": match_obj.pve_tick if match_obj != null else 0,
		"deploy_count": deploy_count,
		"king_hp_permille": king_hp_permille,
	}
