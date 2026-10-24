## 单座塔的 3D 表现：正式塔模型（阵营色染旗帜/屋顶）+ 血条 + 受击闪白 + 开火脉冲 + 摧毁换废墟；只读 Tower 状态。
extends Node3D

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const HpBar := preload("res://view/three_d/hp_bar_3d.gd")
const ToonStyle := preload("res://view/three_d/toon_style.gd")
const KING_MODEL := preload("res://assets/models/king_tower/king_tower.glb")
const ARROW_MODEL := preload("res://assets/models/arrow_tower/arrow_tower.glb")
const RUIN_MODEL := preload("res://assets/models/tower_ruin/tower_ruin.glb")

const FLASH_DUR := 0.15
const PULSE_DUR := 0.25
const KING_AUTHORED_FW := 4.0    # 王塔模型按 4×4 格制作
const ARROW_AUTHORED_FW := 3.0   # 箭塔/废墟模型按 3×3 格制作
const FACE_CAMERA_YAW := PI * 0.5   # 模型正面(+Z)转向镜头所在的 +X 侧：门与旗帜朝玩家

var tower_ref = null
var team_color := Color.WHITE
var destroyed := false
var hp_ratio := 1.0
var attack_count := 0
var top_height := 4.0        # 塔顶高度（世界米）：D8 箭口/伤害数字锚点

var _intact: Node3D
var _ruin: Node3D
var _hp_bar: Node3D
var _overlay: StandardMaterial3D
var _prev_hp := 0.0
var _prev_cooldown := 0.0
var _flash := 0.0
var _pulse := 0.0


func setup(tower, info: Dictionary) -> void:
	tower_ref = tower
	name = "Tower_%s_%d_%d" % [tower.kind, tower.owner_id, tower.get_instance_id()]
	position = FieldProjection.tile_to_world(tower.pos, info.grid, info.get("flipped", false))
	var king: bool = tower.is_king()
	team_color = info.color
	var fw := float(tower.fw)
	_intact = _wrap("Intact", KING_MODEL if king else ARROW_MODEL,
		fw / (KING_AUTHORED_FW if king else ARROW_AUTHORED_FW), team_color)
	_ruin = _wrap("Ruin", RUIN_MODEL, fw / ARROW_AUTHORED_FW, Color.WHITE)
	_ruin.visible = false
	_hp_bar = HpBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.position.y = (4.9 if king else 4.3) * fw / (KING_AUTHORED_FW if king else ARROW_AUTHORED_FW)
	top_height = _hp_bar.position.y - 0.5
	_hp_bar.setup(float(tower.fw) * 0.8, info.color)
	_hp_bar.visible = false
	add_child(_hp_bar)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	for node in _intact.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _overlay
	_prev_hp = tower.hp
	_prev_cooldown = tower._attack_cooldown
	sync(tower, 0.0)


func sync(tower, delta: float) -> void:
	if tower.hp < _prev_hp - 0.01:
		_flash = FLASH_DUR
	_prev_hp = tower.hp
	var cooldown: float = tower._attack_cooldown
	if cooldown > _prev_cooldown + 0.01:
		attack_count += 1
		_pulse = PULSE_DUR
	_prev_cooldown = cooldown
	hp_ratio = tower.hp / tower.max_hp if tower.max_hp > 0.0 else 0.0
	if tower.is_destroyed() and not destroyed:
		destroyed = true
		_intact.visible = false
		_ruin.visible = true
	_hp_bar.visible = not destroyed and hp_ratio < 0.999
	_hp_bar.set_ratio(hp_ratio)
	_flash = maxf(_flash - delta, 0.0)
	_pulse = maxf(_pulse - delta, 0.0)
	_overlay.albedo_color.a = (_flash / FLASH_DUR) * 0.7
	_intact.scale = Vector3.ONE * (1.0 + sin((_pulse / PULSE_DUR) * PI) * 0.06)


## 包一层节点承载缩放/朝向；脉冲缩放作用在外层，不改模型本身的占位缩放。
func _wrap(label: String, scene: PackedScene, scale_k: float, tint: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	add_child(holder)
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * scale_k
	model.rotation.y = FACE_CAMERA_YAW
	holder.add_child(model)
	ToonStyle.apply(model, tint)
	return holder
