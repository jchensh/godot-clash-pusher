# AIController —— 规则 AI（PLAN §4 AI 层；V2-6 攻防结合 + 难度分级）。
#
# 攻防结合、按 lane 选方向、难度分级（决策日志 33）。确定性、无随机。
# 一律经对称入口 opponent.try_play_card 向逻辑层发指令——与玩家走同一条出牌路径
# （PLAN §3 对称性）。本身不碰渲染、不碰圣水回涨（那是 Match/Player）。
#
# AI = match.opponent（OWNER_OPPONENT）：塔在 progress 1，单位部署 progress 0.9 往 0 推、
# 攻击玩家塔（lane.tower_at_start，侧路公主毁则 lane.king_at_start 兜底）。
# 玩家单位从 0 往 1 推，progress 越大越逼近 AI 塔——故 progress >= THREAT_LINE 视为威胁。
extends RefCounted
class_name AIController

# 难度档位参数表（决策日志 33）：
#   threshold  圣水攒到此值(get_int)才考虑出牌
#   cooldown   两次出牌最小间隔（秒）
#   defends    是否做防守（受威胁 lane 优先空投拦截兵）
#   smart_lane 进攻是否选「守军塔血最低」的 lane 集火（否则固定中路）
const DIFF := {
	"easy":   {"threshold": 8, "cooldown": 2.0, "defends": false, "smart_lane": false},
	"normal": {"threshold": 6, "cooldown": 1.2, "defends": true,  "smart_lane": true},
	"hard":   {"threshold": 4, "cooldown": 0.6, "defends": true,  "smart_lane": true},
}
const DEFAULT_DIFF := "normal"

const DEPLOY_PROGRESS := 0.9     # 兵部署位：AI 塔(progress 1)前、己方半场 [0.5,1.0]
const THREAT_LINE := 0.55        # 玩家单位 progress >= 此值 → 越过中线、威胁 AI 塔
const FALLBACK_LANE := 1         # easy 固定中路；找不到目标塔时的兜底
const LANES := [0, 1, 2]

var match_ref      # Match：读战局、经 opponent 出牌
var config         # ConfigLoader
var _diff_name := ""
var _params := {}
var _cooldown := 0.0

func _init(match_ = null, config_ = null, difficulty: String = "") -> void:
	match_ref = match_
	config = config_
	_diff_name = difficulty

# 解析难度参数（首次用时；构造未指定则读 match.ai_difficulty，再不行用默认）。
func _resolve_params() -> void:
	if not _params.is_empty():
		return
	var name := _diff_name
	if name == "" and match_ref != null and "ai_difficulty" in match_ref:
		name = String(match_ref.ai_difficulty)
	if not DIFF.has(name):
		name = DEFAULT_DIFF
	_diff_name = name
	_params = DIFF[name]

func get_difficulty() -> String:
	_resolve_params()
	return _diff_name

# 由 Match 的固定 tick 循环每 tick 调用。
func tick(dt: float) -> void:
	_resolve_params()
	if _cooldown > 0.0:
		_cooldown -= dt
		return
	if _decide():
		_cooldown = float(_params["cooldown"])

# 决策一次，返回是否出了牌：防守优先，其次进攻。
func _decide() -> bool:
	if match_ref == null or config == null:
		return false
	var me = match_ref.opponent
	if me == null or me.elixir == null or me.deck == null:
		return false
	if me.elixir.get_int() < int(_params["threshold"]):
		return false
	# 1) 防守（normal/hard）：受威胁最大的 lane 空投拦截兵。
	if bool(_params["defends"]):
		var dlane := _most_threatened_lane(me.owner_id)
		if dlane >= 0 and _deploy_best_troop(me, dlane):
			return true
		# 没合适的兵 → 落到进攻逻辑（其中法术会落在威胁处，也算防守削兵）。
	# 2) 进攻。
	return _attack(me)

# 进攻：选 lane（智能档=集火最弱敌塔，easy=固定中路）出最贵可用兵；
# 若最贵可用是法术且场上有敌方单位，则落在最前敌人处（不空放）。
func _attack(me) -> bool:
	var spell_target = _lead_enemy_anywhere(me.owner_id)   # {lane, prog} 或 null
	var hand: Array = me.deck.get_hand()
	var best_index := -1
	var best_cost := -1
	for i in hand.size():
		if not me.can_play(i):
			continue
		var card: Dictionary = config.get_card(str(hand[i]))
		var is_spell: bool = not _has_spawn(card)
		if is_spell and spell_target == null:
			continue
		var cost: int = me.card_cost(str(hand[i]))
		if cost > best_cost:
			best_cost = cost
			best_index = i
	if best_index < 0:
		return false
	var chosen: Dictionary = config.get_card(str(hand[best_index]))
	if _has_spawn(chosen):
		return me.try_play_card(best_index, _attack_lane(me.owner_id), DEPLOY_PROGRESS)
	return me.try_play_card(best_index, int(spell_target["lane"]), float(spell_target["prog"]))

# 进攻 lane：智能档选「守军塔血最低」的 lane（集火，tie-break 取小 index）；easy 固定中路。
func _attack_lane(my_owner: int) -> int:
	if not bool(_params["smart_lane"]):
		return FALLBACK_LANE
	var best_lane := -1
	var best_hp := INF
	for li in LANES:
		var lane = match_ref.battle.get_lane(li)
		if lane == null:
			continue
		var hp := _target_tower_hp(lane, my_owner)
		if hp >= 0.0 and hp < best_hp:
			best_hp = hp
			best_lane = li
	return best_lane if best_lane >= 0 else FALLBACK_LANE

# AI 在该 lane 实际会攻击的玩家塔血：主塔(progress 0 端)活着取主塔，否则取兜底王塔；都没有返回 -1。
func _target_tower_hp(lane, my_owner: int) -> float:
	var primary = lane.tower_at_start
	if primary != null and primary.is_alive() and primary.owner_id != my_owner:
		return float(primary.hp)
	var king = lane.king_at_start
	if king != null and king.is_alive() and king.owner_id != my_owner:
		return float(king.hp)
	return -1.0

# 防守目标 lane：玩家单位 progress >= THREAT_LINE 的 lane 中、最逼近 AI 塔者；无则 -1。
func _most_threatened_lane(my_owner: int) -> int:
	var best_lane := -1
	var best_prog := -1.0
	for li in LANES:
		var lane = match_ref.battle.get_lane(li)
		if lane == null:
			continue
		var lead := _lead_enemy_progress(lane, my_owner)
		if lead >= THREAT_LINE and lead > best_prog:
			best_prog = lead
			best_lane = li
	return best_lane

# 在 lane_index 空投「出得起的最贵兵」（防守用 body-block）。返回是否出牌成功。
func _deploy_best_troop(me, lane_index: int) -> bool:
	var hand: Array = me.deck.get_hand()
	var best_index := -1
	var best_cost := -1
	for i in hand.size():
		if not me.can_play(i):
			continue
		if not _has_spawn(config.get_card(str(hand[i]))):
			continue
		var cost: int = me.card_cost(str(hand[i]))
		if cost > best_cost:
			best_cost = cost
			best_index = i
	if best_index < 0:
		return false
	return me.try_play_card(best_index, lane_index, DEPLOY_PROGRESS)

func _has_spawn(card: Dictionary) -> bool:
	for sk in card.get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

# 全场最逼近 AI 塔的敌方(玩家)单位：返回 {lane, prog}，无则 null。
func _lead_enemy_anywhere(my_owner: int):
	var best_lane := -1
	var best_prog := -1.0
	for li in LANES:
		var lane = match_ref.battle.get_lane(li)
		if lane == null:
			continue
		var lead := _lead_enemy_progress(lane, my_owner)
		if lead > best_prog:
			best_prog = lead
			best_lane = li
	if best_lane < 0 or best_prog < 0.0:
		return null
	return {"lane": best_lane, "prog": best_prog}

# 该 lane 中最逼近 AI 塔(progress 1)的敌方(玩家)单位 progress；无敌方单位返回 -1.0。
func _lead_enemy_progress(lane, my_owner: int) -> float:
	var best := -1.0
	for u in lane.get_units():
		if u.owner_id == my_owner or not u.is_alive():
			continue
		if float(u.progress) > best:
			best = float(u.progress)
	return best
