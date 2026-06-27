# AIController —— 规则 AI（V3 2D 重构）。
#
# 攻防结合、按「侧」选向、难度分级（决策日志 33，2D 化）。确定性、无随机。
# 一律经对称入口 me.try_play_card(hand_index, pos) 向逻辑层发指令——与玩家同路径。
# 本身不碰渲染、不碰圣水回涨（那是 Match/Player）。
#
# 默认 = match.opponent（OWNER_OPPONENT）：塔在上方(y 小)、部署己方半场(y<=15)、向 y 增大推进。
#
# V5-S8b「可选边」：构造第 4 参 controlled_owner 可选 OWNER_PLAYER（probe AI-vs-AI 用我方驱动）。
# 决策逻辑全留在「进攻规范帧」(= 默认对手视角：我塔在 y 小、向 y 增大进攻)不变，仅在两处边界做 y 镜像：
#   ① 读敌方单位坐标 → _to_norm_y 折到规范帧；② 出兵落点 → _to_real_y 折回真实坐标。
# 镜像轴 = 河中线(river.y_min+y_max，默认场地 32−y)；x 两阵营对称、不镜像。
# 对手侧(默认) _to_norm_y/_to_real_y 为恒等 → 行为与重构前逐位一致（零回归）。
extends RefCounted
class_name AIController

# 难度档位（决策 33；V3-9 扩 5 档）：threshold 出牌圣水阈值 / cooldown 出牌最小间隔 /
# defends 是否防守 / smart 进攻是否集火最弱塔侧（否则固定中路）。
# 梯度 rookie(极缓·纯练手) → easy → normal → hard → extreme(残暴)；cooldown 是「AI出兵节奏」主杠杆。
const DIFF := {
	"rookie":  {"threshold": 9, "cooldown": 7.0, "defends": false, "smart": false},
	"easy":    {"threshold": 9, "cooldown": 5.0, "defends": false, "smart": false},
	"normal":  {"threshold": 7, "cooldown": 2.5, "defends": true,  "smart": false},
	"hard":    {"threshold": 5, "cooldown": 1.2, "defends": true,  "smart": true},
	"extreme": {"threshold": 4, "cooldown": 0.5, "defends": true,  "smart": true},
}
const DEFAULT_DIFF := "normal"

const OWNER_PLAYER := 0
const OWNER_OPPONENT := 1
const DEPLOY_Y := 12.0       # 进攻部署 y（规范帧：己方半场 y<=15，靠前推进）
const THREAT_LINE := 14.0    # 敌方单位规范 y <= 此 → 越河进我方半场、威胁我塔
const DEFEND_Y_MIN := 10.0   # 防守空投 y 钳制（规范帧；避开自家塔占位 / 河）
const DEFEND_Y_MAX := 14.0
const FALLBACK_X := 9.0      # easy 固定中路 x
const DEFAULT_MIRROR_SUM := 32.0   # 河中线镜像轴和（默认场地 river 15+17）

var match_ref      # Match：读战局、经 me 出牌
var config         # ConfigLoader
var controlled_owner := OWNER_OPPONENT   # 本控制器驱动哪一方（默认对手；probe 可传 OWNER_PLAYER）
var _diff_name := ""
var _params := {}
var _cooldown := 0.0
var _mirror_sum := DEFAULT_MIRROR_SUM
var _geom_ready := false

func _init(match_ = null, config_ = null, difficulty: String = "", controlled_owner_: int = OWNER_OPPONENT) -> void:
	match_ref = match_
	config = config_
	_diff_name = difficulty
	controlled_owner = controlled_owner_

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
	var me = _me()
	if me == null or me.elixir == null or me.deck == null:
		return false
	if me.elixir.get_int() < int(_params["threshold"]):
		return false
	# 1) 防守（normal/hard）：越河威胁我方的敌方单位处空投拦截兵（规范帧坐标）。
	if bool(_params["defends"]):
		var threat_norm = _most_threatening_enemy_norm()
		if threat_norm != null:
			var dnorm := Vector2(float(threat_norm.x), clampf(float(threat_norm.y), DEFEND_Y_MIN, DEFEND_Y_MAX))
			if _deploy_best_troop(me, dnorm):
				return true
	# 2) 进攻。
	return _attack(me)

# 进攻：最贵可用兵 → 部署在进攻侧；最贵可用是法术且场上有敌方单位 → 落在最前敌方单位处。
func _attack(me) -> bool:
	var spell_norm = _lead_enemy_norm()   # Vector2(规范帧) 或 null
	var hand: Array = me.deck.get_hand()
	var best_index := -1
	var best_cost := -1
	for i in hand.size():
		if not me.can_play(i):
			continue
		var card: Dictionary = config.get_card(str(hand[i]))
		var is_spell: bool = not _has_spawn(card)
		if is_spell and spell_norm == null:
			continue
		var cost: int = me.card_cost(str(hand[i]))
		if cost > best_cost:
			best_cost = cost
			best_index = i
	if best_index < 0:
		return false
	var chosen: Dictionary = config.get_card(str(hand[best_index]))
	if _has_spawn(chosen):
		return _emit(me, best_index, _attack_pos_norm())
	return _emit(me, best_index, spell_norm)

# 进攻部署点（规范帧）：智能档 = 集火「最弱敌方塔」所在的 x 侧；easy = 固定中路。
func _attack_pos_norm() -> Vector2:
	if not bool(_params["smart"]):
		return Vector2(FALLBACK_X, DEPLOY_Y)
	var t = _weakest_enemy_tower()
	var x: float = FALLBACK_X if t == null else float(t.pos.x)
	return Vector2(x, DEPLOY_Y)

# 在 norm_pos（规范帧）空投「出得起的最贵兵」（防守 body-block 用）。返回是否出牌成功。
func _deploy_best_troop(me, norm_pos: Vector2) -> bool:
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
	return _emit(me, best_index, norm_pos)

# 出牌：把规范帧落点折回真实坐标（对手侧恒等、我方侧 y 镜像），经对称入口下指令。
func _emit(me, hand_index: int, norm_pos) -> bool:
	if norm_pos == null:
		return false
	var p: Vector2 = norm_pos
	return me.try_play_card(hand_index, Vector2(p.x, _to_real_y(p.y)))

func _has_spawn(card: Dictionary) -> bool:
	for sk in card.get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

# —— 我方/敌方 + 坐标镜像（可选边的全部「方向感」集中在此） ——

func _me():
	if match_ref == null:
		return null
	return match_ref.player if controlled_owner == OWNER_PLAYER else match_ref.opponent

func _enemy_owner() -> int:
	return OWNER_OPPONENT if controlled_owner == OWNER_PLAYER else OWNER_PLAYER

func _enemy_towers() -> Array:
	if match_ref == null or match_ref.battle == null:
		return []
	return match_ref.battle.opponent_towers if controlled_owner == OWNER_PLAYER else match_ref.battle.player_towers

func _ensure_geom() -> void:
	if _geom_ready:
		return
	_geom_ready = true
	if config != null:
		var river = config.get_arena("default").get("river", {})
		if typeof(river) == TYPE_DICTIONARY and river.has("y_min") and river.has("y_max"):
			_mirror_sum = float(river["y_min"]) + float(river["y_max"])

# 真实 y → 规范帧 y（对手侧恒等；我方侧绕河中线镜像）。
func _to_norm_y(real_y: float) -> float:
	if controlled_owner == OWNER_OPPONENT:
		return real_y
	_ensure_geom()
	return _mirror_sum - real_y

# 规范帧 y → 真实 y（镜像可逆）。
func _to_real_y(norm_y: float) -> float:
	if controlled_owner == OWNER_OPPONENT:
		return norm_y
	_ensure_geom()
	return _mirror_sum - norm_y

# 存活敌方单位（按 controlled_owner 取对侧）。
func _enemy_units() -> Array:
	var out: Array = []
	if match_ref == null or match_ref.battle == null or match_ref.battle.arena == null:
		return out
	var eo := _enemy_owner()
	for u in match_ref.battle.arena.get_units():
		if u.owner_id == eo and u.is_alive():
			out.append(u)
	return out

# 最威胁我方的敌方单位的规范帧坐标：越过威胁线(规范 y<=THREAT_LINE)且最逼近我塔(规范 y 最小)者；无则 null。
func _most_threatening_enemy_norm():
	var best = null
	var best_y := INF
	for u in _enemy_units():
		var ny := _to_norm_y(float(u.pos.y))
		if ny <= THREAT_LINE and ny < best_y:
			best_y = ny
			best = u
	return Vector2(float(best.pos.x), _to_norm_y(float(best.pos.y))) if best != null else null

# 全场最逼近我塔(规范 y 最小)的敌方单位规范帧坐标（法术目标）；无则 null。
func _lead_enemy_norm():
	var best = null
	var best_y := INF
	for u in _enemy_units():
		var ny := _to_norm_y(float(u.pos.y))
		if ny < best_y:
			best_y = ny
			best = u
	return Vector2(float(best.pos.x), _to_norm_y(float(best.pos.y))) if best != null else null

# 存活敌方塔中塔血最低者（集火）；tie-break = 塔列表先序。
func _weakest_enemy_tower():
	var best = null
	var best_hp := INF
	for t in _enemy_towers():
		if t.is_alive() and float(t.hp) < best_hp:
			best_hp = float(t.hp)
			best = t
	return best
