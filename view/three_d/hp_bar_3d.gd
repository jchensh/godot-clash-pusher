## 3D 血条：始终朝向相机的底框 + 填充条；只读传入比例，不持有血量真相。
## batched=true（D8b）：本节点只存数据（宽度/颜色/比例/显隐/位置），由 presenter 的 BattleBatches 合批画（全场 2 个 draw call）。
extends Node3D

const BG_COLOR := Color(0.12, 0.12, 0.14, 0.85)

var ratio := 1.0
var bar_color := Color.WHITE
var batched := false
var _width := 1.0
var _fill_mesh: QuadMesh


func setup(width: float, color: Color, batch := false) -> void:
	_width = width
	bar_color = color
	batched = batch
	if batched:
		return
	_quad("Back", Vector2(width + 0.08, 0.2), BG_COLOR, 0)
	_fill_mesh = _quad("Fill", Vector2(width, 0.12), color, 1).mesh as QuadMesh
	set_ratio(1.0)


## 填充条左对齐缩短：改网格尺寸与中心偏移（偏移在网格局部、随公告板一起朝向相机）。
func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	if batched:
		return
	_fill_mesh.size.x = maxf(_width * ratio, 0.001)
	_fill_mesh.center_offset.x = -_width * (1.0 - ratio) * 0.5


func width() -> float:
	return _width


func _quad(label: String, size: Vector2, color: Color, priority: int) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = priority
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
