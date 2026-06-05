# Unit —— 场上单位的纯逻辑运行时状态。
#
# 位置使用 lane 进度 0.0~1.0；OWNER_PLAYER 从 0 向 1 推进，
# OWNER_OPPONENT 从 1 向 0 推进。这里不关心像素、节点或动画。
extends RefCounted
class_name Unit

const OWNER_PLAYER := 0
const OWNER_OPPONENT := 1
const _EPSILON := 0.000001

var unit_id: String = ""
var owner_id: int = OWNER_PLAYER
var lane_index: int = 0
var progress: float = 0.0

var hp: float = 0.0
var max_hp: float = 0.0
var damage: float = 0.0
var attack_speed: float = 1.0      # V1 解释为攻击间隔（秒/次）
var move_speed: float = 0.0        # lane 进度/秒
var attack_range: float = 0.0      # lane 进度比例
var target_type: String = "ground" # 单位自身类型：ground / air

var _attack_cooldown: float = 0.0

func _init(
		unit_id_: String = "",
		owner_id_: int = OWNER_PLAYER,
		lane_index_: int = 0,
		config: Dictionary = {},
		progress_: float = 0.0
) -> void:
	if not unit_id_.is_empty() or not config.is_empty():
		setup(unit_id_, owner_id_, lane_index_, config, progress_)

func setup(
		unit_id_: String,
		owner_id_: int,
		lane_index_: int,
		config: Dictionary,
		progress_: float = 0.0
) -> void:
	unit_id = unit_id_
	owner_id = owner_id_
	lane_index = lane_index_
	progress = clampf(progress_, 0.0, 1.0)

	max_hp = maxf(float(config.get("hp", 0.0)), 0.0)
	hp = max_hp
	damage = maxf(float(config.get("damage", 0.0)), 0.0)
	attack_speed = maxf(float(config.get("attack_speed", 1.0)), 0.0)
	move_speed = maxf(float(config.get("move_speed", 0.0)), 0.0)
	attack_range = clampf(float(config.get("attack_range", 0.0)), 0.0, 1.0)
	target_type = str(config.get("target_type", "ground"))
	_attack_cooldown = 0.0

func get_direction() -> int:
	return 1 if owner_id == OWNER_PLAYER else -1

func is_enemy(other: Unit) -> bool:
	return other != null and owner_id != other.owner_id

func is_alive() -> bool:
	return hp > 0.0

func take_damage(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	hp = maxf(hp - amount, 0.0)

func tick_cooldown(dt: float) -> void:
	if dt <= 0.0 or _attack_cooldown <= 0.0:
		return
	_attack_cooldown = maxf(_attack_cooldown - dt, 0.0)

func can_attack() -> bool:
	return is_alive() and damage > 0.0 and _attack_cooldown <= _EPSILON

func mark_attacked() -> void:
	_attack_cooldown = attack_speed

func move_to(next_progress: float) -> void:
	progress = clampf(next_progress, 0.0, 1.0)
