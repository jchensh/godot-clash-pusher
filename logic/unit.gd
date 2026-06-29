# Unit —— 场上单位的纯逻辑运行时状态（V3 2D 重构）。
#
# 位置使用抽象 2D 场地坐标 pos:Vector2（tile 空间，非屏幕像素）；移动/寻路/朝向
# 由 Arena 据流场与目标决定，Unit 自身只持状态。不关心像素、节点或动画。
# 量纲（V3）：move_speed = tile/秒；attack_range = tile 距离；attack_speed = 攻击间隔(秒/次)。
extends RefCounted
class_name Unit

const OWNER_PLAYER := 0
const OWNER_OPPONENT := 1
const _EPSILON := 0.000001

var unit_id: String = ""
var owner_id: int = OWNER_PLAYER
var pos: Vector2 = Vector2.ZERO    # 抽象 2D 场地坐标（tile 空间）

var hp: float = 0.0
var max_hp: float = 0.0
var damage: float = 0.0
var attack_speed: float = 1.0      # 攻击间隔（秒/次）
var move_speed: float = 0.0        # tile/秒
var attack_range: float = 0.0      # tile 距离
var aggro_radius: float = 0.0      # tile：敌方单位进此半径 → 分心转火（CR 仇恨，V3-1c）
var body_radius: float = 0.0       # tile：软推挤体积半径（V3-1d）
var target_type: String = "ground" # 单位自身类型：ground / air（决定谁能打我 + 是否飞行）
var attack_targets: String = "ground" # 我能攻击的目标类型：ground / air / both（V3-2 对空克制）

# 亡语召唤（V3-3）：死亡时在原地生成 death_spawn_count 个 death_spawn_id。
# death_spawn_config 由 SkillSystem 在生成时注入（被召唤单位的配置模板），使 Arena 无需依赖 ConfigLoader。
var death_spawn_id: String = ""
var death_spawn_count: int = 0
var death_spawn_config: Dictionary = {}

# 当前索敌目标（Unit 或 Tower，运行时由 Arena 每 tick 设置；攻击/显示用）。
var current_target = null

var _attack_cooldown: float = 0.0

func _init(
		unit_id_: String = "",
		owner_id_: int = OWNER_PLAYER,
		config: Dictionary = {},
		pos_: Vector2 = Vector2.ZERO
) -> void:
	if not unit_id_.is_empty() or not config.is_empty():
		setup(unit_id_, owner_id_, config, pos_)

func setup(
		unit_id_: String,
		owner_id_: int,
		config: Dictionary,
		pos_: Vector2 = Vector2.ZERO
) -> void:
	unit_id = unit_id_
	owner_id = owner_id_
	pos = pos_

	max_hp = maxf(float(config.get("hp", 0.0)), 0.0)
	hp = max_hp
	damage = maxf(float(config.get("damage", 0.0)), 0.0)
	attack_speed = maxf(float(config.get("attack_speed", 1.0)), 0.0)
	move_speed = maxf(float(config.get("move_speed", 0.0)), 0.0)
	attack_range = maxf(float(config.get("attack_range", 0.0)), 0.0)
	aggro_radius = maxf(float(config.get("aggro_radius", 0.0)), 0.0)
	body_radius = maxf(float(config.get("body_radius", 0.0)), 0.0)
	target_type = str(config.get("target_type", "ground"))
	attack_targets = str(config.get("attack_targets", "ground"))
	death_spawn_id = str(config.get("death_spawn_unit", ""))
	death_spawn_count = int(config.get("death_spawn_count", 0))
	death_spawn_config = {}
	current_target = null
	_attack_cooldown = 0.0

# V5-S1：出兵数值乘区——按养成（我方卡 level/rank）/ 难度系数（敌方）缩放 hp 与 damage，
# 不动 attack_speed/move_speed/attack_range/aggro/body（保手感与确定性）。出生即满血故 hp 同步到新 max_hp。
# mult==1.0 为 no-op → 保证乘区未启用时与现状逐位一致（零回归）。
func apply_stat_mult(mult: float) -> void:
	if mult == 1.0:
		return
	max_hp = max_hp * mult
	hp = max_hp
	damage = damage * mult

func is_enemy(other: Unit) -> bool:
	return other != null and owner_id != other.owner_id

# 飞行单位（V3-2）：忽略地形（直线越河），且只有「能打空」的来源可命中。
func is_flying() -> bool:
	return target_type == "air"

# 我能否攻击 type 类型（ground/air）的目标。建筑(塔)不受此限，由调用方处理。
func can_hit_type(t: String) -> bool:
	return attack_targets == "both" or attack_targets == t

func is_alive() -> bool:
	return hp > 0.0

func take_damage(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	hp = maxf(hp - amount, 0.0)

# 治疗（V3-3）：仅对存活单位生效、不超过最大血量。
func heal(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return
	hp = minf(hp + amount, max_hp)

func tick_cooldown(dt: float) -> void:
	if dt <= 0.0 or _attack_cooldown <= 0.0:
		return
	_attack_cooldown = maxf(_attack_cooldown - dt, 0.0)

func can_attack() -> bool:
	return is_alive() and damage > 0.0 and _attack_cooldown <= _EPSILON

func mark_attacked() -> void:
	_attack_cooldown = attack_speed

func distance_to(p: Vector2) -> float:
	return pos.distance_to(p)
