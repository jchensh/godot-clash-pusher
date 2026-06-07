# AIController —— 规则 AI（PLAN §4 AI 层 / §6 Step 8）。
#
# 简单进攻型（用户 2026-06-07 确认）：圣水攒到阈值就出「最贵的、出得起的」兵，
# 部署在自家塔前往下推；伤害法术只在对面 lane 有敌方单位时才放（不空放浪费）。
# 确定性、无随机。一律经对称入口 opponent.try_play_card 向逻辑层发指令——与玩家
# 走同一条出牌路径（PLAN §3 对称性）。本身不碰渲染、不碰圣水回涨（那是 Match/Player）。
extends RefCounted
class_name AIController

const PLAY_THRESHOLD := 6        # 圣水 get_int() >= 此值才考虑出牌（中等节奏）
const PLAY_COOLDOWN := 1.0       # 两次出牌最小间隔（秒），避免一次性倾泻
const DEPLOY_PROGRESS := 0.9     # 兵的部署位：自家塔(progress 1)前，往 0 推（己方半场）
const LANE_INDEX := 1            # V2-2 最小适配：固定中路出兵与感知（决策 27）；按 lane 攻防留 V2-6

var match_ref      # Match：读战局、经 opponent 出牌
var config         # ConfigLoader
var _cooldown := 0.0

func _init(match_ = null, config_ = null) -> void:
	match_ref = match_
	config = config_

# 由 Match 的固定 tick 循环每 tick 调用。
func tick(dt: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= dt
		return
	if _decide():
		_cooldown = PLAY_COOLDOWN

# 决策一次，返回是否出了牌。
func _decide() -> bool:
	if match_ref == null or config == null:
		return false
	var me = match_ref.opponent
	if me == null or me.elixir == null:
		return false
	if me.elixir.get_int() < PLAY_THRESHOLD:
		return false

	var lane = match_ref.battle.get_lane(LANE_INDEX)
	if lane == null:
		return false
	var lead_enemy := _lead_enemy_progress(lane, me.owner_id)
	var has_enemy: bool = lead_enemy >= 0.0
	var hand: Array = me.deck.get_hand()

	# 选「出得起、且有用」的最贵牌：兵随时有用；法术仅在有敌方单位时有用（否则空放）。
	var best_index := -1
	var best_cost := -1
	for i in hand.size():
		if not me.can_play(i):
			continue
		var card: Dictionary = config.get_card(str(hand[i]))
		var is_spell: bool = not _has_spawn(card)
		if is_spell and not has_enemy:
			continue
		var cost: int = me.card_cost(str(hand[i]))
		if cost > best_cost:
			best_cost = cost
			best_index = i
	if best_index < 0:
		return false

	var chosen: Dictionary = config.get_card(str(hand[best_index]))
	var prog := DEPLOY_PROGRESS
	if not _has_spawn(chosen):
		prog = lead_enemy           # 法术落在最前敌人处（aoe 圆心；direct 不用）
	return me.try_play_card(best_index, LANE_INDEX, prog)

func _has_spawn(card: Dictionary) -> bool:
	for sk in card.get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

# AI 视角「最前敌人」的 progress：敌方(玩家)单位中最逼近 AI 塔(progress 1)者，即 progress 最大者。
# 无敌方单位返回 -1.0。
func _lead_enemy_progress(lane, my_owner: int) -> float:
	var best := -1.0
	for u in lane.get_units():
		if u.owner_id == my_owner or not u.is_alive():
			continue
		if float(u.progress) > best:
			best = float(u.progress)
	return best
