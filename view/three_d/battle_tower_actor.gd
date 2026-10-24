## 单座塔的 3D 表现：几何代理塔身 + 血条 + 受击闪白 + 开火脉冲 + 摧毁废墟；只读 Tower 状态。
extends Node3D

const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")
const FieldProjection := preload("res://view/three_d/field_projection.gd")
const HpBar := preload("res://view/three_d/hp_bar_3d.gd")

const FLASH_DUR := 0.15
const PULSE_DUR := 0.25
const RUIN_COLOR := Color("8b8478")

var tower_ref = null
var destroyed := false
var hp_ratio := 1.0
var attack_count := 0

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
	_intact = ArenaPresenter.make_tower_proxy(king, float(tower.fw), float(tower.fh), info.color)
	_intact.name = "Intact"
	add_child(_intact)
	_ruin = _build_ruin(float(tower.fw), float(tower.fh))
	_ruin.visible = false
	add_child(_ruin)
	_hp_bar = HpBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.position.y = (3.0 if king else 2.2) + 2.0
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


## 废墟代理：矮基座 + 几块倾倒碎石（与 2D 王塔废墟一致：敌我共用、不带阵营色）。
func _build_ruin(fw: float, fh: float) -> Node3D:
	var ruin := Node3D.new()
	ruin.name = "Ruin"
	ArenaPresenter.box(ruin, "RuinBase", Vector3(fw * 0.8, 0.45, fh * 0.8), Vector3(0, 0.22, 0), RUIN_COLOR)
	var chunks := [Vector3(-0.35, 0.6, 0.2), Vector3(0.4, 0.55, -0.25), Vector3(0.05, 0.75, -0.05)]
	for i in chunks.size():
		var piece := ArenaPresenter.box(ruin, "Rubble%d" % i, Vector3(0.6, 0.35, 0.45),
			chunks[i] * Vector3(fw * 0.4, 1.0, fh * 0.4), RUIN_COLOR.lightened(0.1 * i))
		piece.rotation = Vector3(0.3 * i, 0.7 * i, 0.25)
	return ruin
