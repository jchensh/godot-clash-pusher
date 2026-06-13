# AIController —— 规则 AI（V3 2D 重构）。
#
# 攻防结合、按「侧」选向、难度分级（决策日志 33，2D 化）。确定性、无随机。
# 一律经对称入口 opponent.try_play_card(hand_index, pos) 向逻辑层发指令——与玩家同路径。
# 本身不碰渲染、不碰圣水回涨（那是 Match/Player）。
#
# AI = match.opponent（OWNER_OPPONENT）：塔在上方(y 小)，单位部署己方半场(y<=enemy_y_max)、
# 向 y 增大方向推进打玩家塔。玩家单位 y 越小越逼近 AI 塔 → y<=THREAT_LINE 视为威胁。
extends RefCounted
class_name AIController

# 难度档位（决策日志 33）：threshold 出牌圣水阈值 / cooldown 出牌最小间隔 /
# defends 是否防守 / smart 进攻是否集火最弱塔侧（否则固定中路）。
const DIFF := {
	"easy":   {"threshold": 8, "cooldown": 2.0, "defends": false, "smart": false},
	"normal": {"threshold": 6, "cooldown": 1.2, "defends": true,  "smart": true},
	"hard":   {"threshold": 4, "cooldown": 0.6, "defends": true,  "smart": true},
}
const DEFAULT_DIFF := "normal"

const OWNER_PLAYER := 0
const OWNER_OPPONENT := 1
const DEPLOY_Y := 12.0       # AI 进攻部署 y（己方半场 y<=15，靠前推进）
const THREAT_LINE := 14.0    # 玩家单位 y <= 此 → 越河进 AI 半场、威胁 AI 塔
const DEFEND_Y_MIN := 10.0   # 防守空投 y 钳制（避开自家塔占位 / 河）
const DEFEND_Y_MAX := 14.0
const FALLBACK_X := 9.0      # easy 固定中路 x

var match_ref      # Match：读战局、经 opponent 出牌
var config         # ConfigLoader
var _diff_name := ""
var _params := {}
var _cooldown := 0.0

func _init(match_ = null, config_ = null, difficulty: String = "") -> void:
	match_ref = match_
	config = config_
	_diff_name = difficulty

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

# 决策一次：防守优先，其次进攻。
func _decide() -> bool:
	if match_ref == null or config == null:
		return false
	var me = match_ref.opponent
	if me == null or me.elixir == null or me.deck == null:
		return false
	if me.elixir.get_int() < int(_params["threshold"]):
		return false
	# 1) 防守（normal/hard）：越河威胁 AI 的玩家单位处空投拦截兵。
	if bool(_params["defends"]):
		var threat = _most_threatening_player_unit()
		if threat != null:
			var dpos := Vector2(float(threat.pos.x), clampf(float(threat.pos.y), DEFEND_Y_MIN, DEFEND_Y_MAX))
			if _deploy_best_troop(me, dpos):
				return true
	# 2) 进攻。
	return _attack(me)

# 进攻：最贵可用兵 → 部署在进攻侧；最贵可用是法术且场上有玩家单位 → 落在最前玩家单位处。
func _attack(me) -> bool:
	var spell_pos = _lead_player_unit_pos()   # Vector2 或 null
	var hand: Array = me.deck.get_hand()
	var best_index := -1
	var best_cost := -1
	for i in hand.size():
		if not me.can_play(i):
			continue
		var card: Dictionary = config.get_card(str(hand[i]))
		var is_spell: bool = not _has_spawn(card)
		if is_spell and spell_pos == null:
			continue
		var cost: int = me.card_cost(str(hand[i]))
		if cost > best_cost:
			best_cost = cost
			best_index = i
	if best_index < 0:
		return false
	var chosen: Dictionary = config.get_card(str(hand[best_index]))
	if _has_spawn(chosen):
		return me.try_play_card(best_index, _attack_pos())
	return me.try_play_card(best_index, spell_pos)

# 进攻部署点：智能档 = 集火「最弱玩家塔」所在的 x 侧；easy = 固定中路。
func _attack_pos() -> Vector2:
	if not bool(_params["smart"]):
		return Vector2(FALLBACK_X, DEPLOY_Y)
	var t = _weakest_player_tower()
	var x: float = FALLBACK_X if t == null else float(t.pos.x)
	return Vector2(x, DEPLOY_Y)

# 在 pos 空投「出得起的最贵兵」（防守 body-block 用）。返回是否出牌成功。
func _deploy_best_troop(me, pos: Vector2) -> bool:
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
	return me.try_play_card(best_index, pos)

func _has_spawn(card: Dictionary) -> bool:
	for sk in card.get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

func _player_units() -> Array:
	var out: Array = []
	if match_ref == null or match_ref.battle == null or match_ref.battle.arena == null:
		return out
	for u in match_ref.battle.arena.get_units():
		if u.owner_id == OWNER_PLAYER and u.is_alive():
			out.append(u)
	return out

# 最威胁 AI 的玩家单位：越过威胁线(y<=THREAT_LINE)且最逼近 AI 塔(y 最小)者；无则 null。
func _most_threatening_player_unit():
	var best = null
	var best_y := INF
	for u in _player_units():
		var y: float = float(u.pos.y)
		if y <= THREAT_LINE and y < best_y:
			best_y = y
			best = u
	return best

# 全场最逼近 AI 塔(y 最小)的玩家单位位置（法术目标）；无则 null。
func _lead_player_unit_pos():
	var best = null
	var best_y := INF
	for u in _player_units():
		var y: float = float(u.pos.y)
		if y < best_y:
			best_y = y
			best = u
	return best.pos if best != null else null

# 存活玩家塔中塔血最低者（集火）；tie-break = player_towers 先序。
func _weakest_player_tower():
	var best = null
	var best_hp := INF
	if match_ref == null or match_ref.battle == null:
		return null
	for t in match_ref.battle.player_towers:
		if t.is_alive() and float(t.hp) < best_hp:
			best_hp = float(t.hp)
			best = t
	return best
