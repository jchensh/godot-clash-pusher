# Player —— 一方的对局状态：圣水 + 循环卡组 + 出牌（PLAN §4）。玩家与 AI 共用。
#
# 这是「逻辑/显示分离」与「玩家 AI 对称」的落点：无论指令来自玩家点击还是
# AIController，都走同一个 try_play_card。Player 把圣水门槛 + 抽牌补牌 + 触发技能
# 串起来——SkillSystem 只管执行效果、不管圣水（见 HISTORY 决策日志 21）。
# 纯逻辑：依赖注入 Elixir / Deck / ConfigLoader / SkillSystem，不碰渲染。
extends RefCounted
class_name Player

const UnitScript = preload("res://logic/unit.gd")

var owner_id: int = 0
var elixir            # Elixir
var deck              # Deck
var config            # ConfigLoader：查卡牌 elixir_cost
var skill_system      # SkillSystem：执行技能积木

func _init(owner_id_ = 0, elixir_ = null, deck_ = null, config_ = null, skill_system_ = null) -> void:
	owner_id = owner_id_
	elixir = elixir_
	deck = deck_
	config = config_
	skill_system = skill_system_

# 每个逻辑 tick 由 Match 调用：圣水回涨。
func regen(dt: float) -> void:
	if elixir != null:
		elixir.tick(dt)

func card_cost(card_id) -> int:
	if config == null or card_id == null:
		return 0
	return int(config.get_card(card_id).get("elixir_cost", 0))

# 第 hand_index 格手牌当前是否出得起（供 UI 置灰判断）。
func can_play(hand_index: int) -> bool:
	if deck == null or elixir == null:
		return false
	var hand: Array = deck.get_hand()
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id = hand[hand_index]
	if card_id == null:
		return false
	return elixir.get_int() >= card_cost(card_id)

# 尝试出第 hand_index 格手牌到 2D 落点 pos（tile 空间）。
# 圣水不足/下标非法/兵牌落点非法（越界己方半场或落在水/塔）→ 返回 false 且不改任何状态；
# 成功 → 扣圣水、循环卡组、触发技能。
func try_play_card(hand_index: int, pos: Vector2 = Vector2.ZERO) -> bool:
	if deck == null or elixir == null or skill_system == null:
		return false
	var hand: Array = deck.get_hand()
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id = hand[hand_index]
	if card_id == null:
		return false
	if not _deploy_allowed(card_id, pos):
		return false   # 兵牌落点须在己方半场且为可走地面（决策 26 / 36）；纯法术不受限
	var cost := card_cost(card_id)
	if elixir.get_int() < cost:
		return false
	if not elixir.spend(float(cost)):
		return false
	deck.play(hand_index)
	skill_system.play_card(card_id, owner_id, pos)
	return true

# 该卡是否会生成单位（含 spawn_unit 积木）。纯伤害法术（fireball/arrows/zap）返回 false。
func _spawns_troops(card_id) -> bool:
	if config == null:
		return false
	for sk in config.get_card(card_id).get("skills", []):
		if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
			return true
	return false

# 部署是否合法（决策 26 / 36）：纯法术不限；兵牌落点须落在出牌方己方半场且为可走地面（非水/塔）。
# 校验委托给 Arena.can_deploy（2D 场地权威）。
func _deploy_allowed(card_id, pos: Vector2) -> bool:
	if not _spawns_troops(card_id):
		return true
	var arena = skill_system.battle.arena if skill_system != null and skill_system.battle != null else null
	if arena == null:
		return true   # 无 arena（理论不应发生）→ 不拦截，交由上层
	return arena.can_deploy(owner_id, pos)
