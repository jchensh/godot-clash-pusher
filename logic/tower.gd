# Tower —— 塔的纯逻辑状态：血量与摧毁判定（PLAN §4，Step 5）。
#
# 三塔制：每方 1 王塔（king）+ 2 公主塔（princess）。
# 胜负规则（Step 5 决策）：
#   - 王塔归零 → 该方立即负；
#   - 公主塔归零不结束对局，只减少该方「剩余塔血」（用于超时比拼）。
# Tower 只是血量容器，不关心像素/lane 位置；位置由 Lane / Battle 负责接线。
extends RefCounted
class_name Tower

const KIND_KING := "king"
const KIND_PRINCESS := "princess"
const _EPSILON := 0.000001

var kind: String = KIND_KING
var owner_id: int = 0          # 约定与 Unit.OWNER_PLAYER / OWNER_OPPONENT 一致
var max_hp: float = 0.0
var hp: float = 0.0

# V3 2D 场地（tile 空间）位置与占位。
var pos: Vector2 = Vector2.ZERO
var fw: int = 0
var fh: int = 0

# V3-1e 塔反击：射程内最近敌兵按冷却出手。damage<=0 视为不反击。
var damage: float = 0.0
var attack_range: float = 0.0      # tile 距离（从塔中心起算）
var attack_speed: float = 1.0      # 攻击间隔（秒/次）
var _attack_cooldown: float = 0.0

func _init(kind_: String = KIND_KING, owner_id_: int = 0, hp_: float = 0.0) -> void:
	kind = kind_
	owner_id = owner_id_
	max_hp = maxf(hp_, 0.0)
	hp = max_hp

func is_king() -> bool:
	return kind == KIND_KING

func is_alive() -> bool:
	return hp > 0.0

func is_destroyed() -> bool:
	return hp <= 0.0

func take_damage(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	hp = maxf(hp - amount, 0.0)

# —— 反击冷却（与 Unit 同口径，V3-1e）——
func tick_cooldown(dt: float) -> void:
	if dt <= 0.0 or _attack_cooldown <= 0.0:
		return
	_attack_cooldown = maxf(_attack_cooldown - dt, 0.0)

func can_attack() -> bool:
	return is_alive() and damage > 0.0 and _attack_cooldown <= _EPSILON

func mark_attacked() -> void:
	_attack_cooldown = attack_speed
