## 配置驱动的 3D 场地地基；塔是待正式素材替换的几何代理，不含战斗逻辑。
extends Node3D

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const COLOR_BLUE := Color("428bcc")
const COLOR_RED := Color("ca5d55")

var grid_size := Vector2.ZERO
var bridge_count := 0
var tower_count := 0
var _generated: Node3D


## include_towers=false：只建地形（D1 战斗 presenter 按 Battle 实际塔对象自建可受击/摧毁的塔）。
func build(config: Dictionary, include_towers := true) -> void:
	if _generated != null:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "GeneratedArena"
	add_child(_generated)
	bridge_count = 0
	tower_count = 0
	grid_size = Vector2(config.grid.w, config.grid.h)
	box(_generated, "Ground", Vector3(grid_size.x, 0.65, grid_size.y), Vector3(0, -0.325, 0), Color("8dad69"))
	box(_generated, "Border", Vector3(grid_size.x + 1.2, 0.5, grid_size.y + 1.2), Vector3(0, -0.65, 0), Color("756e54"))
	var river: Dictionary = config.river
	var river_width := float(river.y_max - river.y_min)
	var river_y := (float(river.y_min) + float(river.y_max)) * 0.5
	var river_pos := FieldProjection.tile_to_world(Vector2(grid_size.x * 0.5, river_y), grid_size, false, 0.035)
	box(_generated, "River", Vector3(grid_size.x, 0.06, river_width), river_pos, Color("63b9cf"))
	for bridge in river.bridges:
		var width := float(bridge.x_max - bridge.x_min)
		var tile := Vector2((float(bridge.x_min) + float(bridge.x_max)) * 0.5, river_y)
		var center := FieldProjection.tile_to_world(tile, grid_size, false, 0.15)
		box(_generated, "Bridge%d" % bridge_count, Vector3(width, 0.25, river_width + 0.8), center, Color("c29b65"))
		for side in [-1.0, 1.0]:
			box(_generated, "BridgeRail", Vector3(0.12, 0.35, river_width + 0.8),
				center + Vector3(side * (width * 0.5 - 0.1), 0.25, 0), Color("8d6742"))
		bridge_count += 1
	if not include_towers:
		return
	for side in config.towers:
		for kind in config.towers[side]:
			var tower: Dictionary = config.towers[side][kind]
			var base := make_tower_proxy(kind == "king", float(tower.fw), float(tower.fh),
				COLOR_BLUE if side == "player" else COLOR_RED)
			base.name = "%s_%s" % [side, kind]
			base.position = FieldProjection.tile_to_world(Vector2(tower.x, tower.y), grid_size)
			_generated.add_child(base)
			tower_count += 1


## 塔几何代理（子节点 Footprint/StoneKeep/TeamBand/Roof/Crown 供战斗 presenter 换色、摧毁时隐藏）。
static func make_tower_proxy(king: bool, fw: float, fh: float, color: Color) -> Node3D:
	var base := Node3D.new()
	var height := 3.0 if king else 2.2
	var width := fw * 0.7
	box(base, "Footprint", Vector3(fw, 0.12, fh), Vector3(0, 0.06, 0), Color("d8cba7"))
	box(base, "StoneKeep", Vector3(width, height, width), Vector3(0, height * 0.5, 0), Color("d9d2bc"))
	box(base, "TeamBand", Vector3(width + 0.1, 0.35, width + 0.1), Vector3(0, height - 0.3, 0), color)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = width * 0.85
	roof.height = 1.0
	roof.radial_segments = 4
	var cap := MeshInstance3D.new()
	cap.name = "Roof"
	cap.mesh = roof
	cap.material_override = material(color)
	cap.position.y = height + 0.5
	cap.rotation.y = PI * 0.25
	base.add_child(cap)
	if king:
		box(base, "Crown", Vector3(0.45, 0.5, 0.45), Vector3(0, height + 1.15, 0), Color("e8b94c"))
	return base


static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


static func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = pos
	parent.add_child(instance)
	return instance
