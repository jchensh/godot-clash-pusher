## 配置驱动的 3D 场地：草地（棋盘格）+ 下沉河道（流水）+ 石岸 + 木桥 + 场边栅栏与点缀（D3 正式地形）。
## 只做表现，不含战斗逻辑；include_towers=true 时附带塔的几何代理（D0 场地预览用，战斗由 presenter 自建塔）。
extends Node3D

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const ToonStyle := preload("res://view/three_d/toon_style.gd")
const Quality := preload("res://view/three_d/quality.gd")
const FxMesh := preload("res://view/three_d/fx_mesh.gd")
const GROUND_SHADER := preload("res://view/three_d/ground.gdshader")
const WATER_SHADER := preload("res://view/three_d/water.gdshader")
const BRIDGE := preload("res://assets/models/bridge/bridge.glb")
const PROPS := {
	"tree": preload("res://assets/models/prop_tree/prop_tree.glb"),
	"bush": preload("res://assets/models/prop_bush/prop_bush.glb"),
	"rock": preload("res://assets/models/prop_rock/prop_rock.glb"),
	"fence": preload("res://assets/models/prop_fence/prop_fence.glb"),
}
const COLOR_BLUE := Color("428bcc")
const COLOR_RED := Color("ca5d55")
const WATER_Y := -0.03           # 水面略高于场外草甸顶面（-0.06），低于两岸石沿与地面（0）
const BRIDGE_AUTHORED := 3.0     # bridge.glb 按 3 格宽、3 格长（河宽 2 + 搭岸 1）制作
const BRIDGE_DROP := 0.27        # 桥板顶面落到地面附近，单位走过不浮空
const FENCE_GAP := 0.9           # 栅栏离场地边缘的距离（米 = 格）
## 场外点缀（tile 坐标，均在场地外；生成时左右镜像）：[类型, x, y, 朝向度, 缩放]。
const DECOR := [
	["tree", -2.6, 2.5, 0.0, 1.0], ["tree", -3.2, 8.0, 40.0, 1.15], ["bush", -1.8, 11.5, 0.0, 1.0],
	["rock", -2.2, 14.6, 20.0, 1.0], ["tree", -3.0, 19.5, 80.0, 1.05], ["bush", -1.9, 23.0, 30.0, 0.9],
	["tree", -2.7, 28.0, 10.0, 1.1], ["rock", 4.0, -2.0, 0.0, 0.9], ["bush", 9.0, -1.8, 0.0, 1.0],
	["tree", 2.0, -3.2, 60.0, 1.0], ["rock", 4.0, 32.0, 0.0, 0.9], ["bush", 9.0, 31.8, 0.0, 1.0],
	["tree", 2.0, 33.2, 30.0, 1.0],
]

var grid_size := Vector2.ZERO
var bridge_count := 0
var tower_count := 0
var _generated: Node3D
var _stone_parts: Array = []     # 石岸 + 外沿石沿：收集后合成一个顶点色网格（D8b：6 个 draw call → 1 个）


func build(config: Dictionary, include_towers := true) -> void:
	if _generated != null:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "GeneratedArena"
	add_child(_generated)
	bridge_count = 0
	tower_count = 0
	_stone_parts.clear()
	grid_size = Vector2(config.grid.w, config.grid.h)
	var river: Dictionary = config.river
	var river_w := float(river.y_max - river.y_min)
	var river_y := (float(river.y_min) + float(river.y_max)) * 0.5
	# 场外草甸 + 场地两半草地（河道处留空）
	_slab("Meadow", Vector3(grid_size.x + 40.0, 0.6, grid_size.y + 40.0), Vector3(0, -0.36, 0), Color("78ab55"), Color("71a24f"))
	_half("FieldEnemy", 0.0, float(river.y_min))
	_half("FieldPlayer", float(river.y_max), grid_size.y)
	var river_center := FieldProjection.tile_to_world(Vector2(grid_size.x * 0.5, river_y), grid_size)
	var water := MeshInstance3D.new()
	water.name = "River"
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_size.x, river_w)
	water.mesh = plane
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	water.material_override = water_mat
	water.position = river_center + Vector3(0, WATER_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(water)
	for edge in [float(river.y_min), float(river.y_max)]:
		var at := FieldProjection.tile_to_world(Vector2(grid_size.x * 0.5, edge), grid_size)
		_stone(Vector3(grid_size.x, 0.4, 0.24), at + Vector3(0, -0.17, 0), Color("a39985"))
	for bridge in river.bridges:
		var width := float(bridge.x_max - bridge.x_min)
		var tile := Vector2((float(bridge.x_min) + float(bridge.x_max)) * 0.5, river_y)
		var model: Node3D = BRIDGE.instantiate()
		model.name = "Bridge%d" % bridge_count
		model.scale = Vector3(width / BRIDGE_AUTHORED, 1.0, (river_w + 1.0) / BRIDGE_AUTHORED)
		model.position = FieldProjection.tile_to_world(tile, grid_size, false, -BRIDGE_DROP)
		_generated.add_child(model)
		Quality.dress(model, "prop")
		bridge_count += 1
	_build_rim()
	_build_stones()
	_build_decor()
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


## 一侧半场草地：tile y∈[y0, y1)，顶面 = 世界 0。
func _half(label: String, y0: float, y1: float) -> void:
	var z0 := FieldProjection.tile_to_world(Vector2(0, y0), grid_size).z
	var z1 := FieldProjection.tile_to_world(Vector2(0, y1), grid_size).z
	_slab(label, Vector3(grid_size.x, 0.6, z1 - z0), Vector3(0, -0.3, (z0 + z1) * 0.5), Color("7fc155"), Color("75b64e"))


func _slab(label: String, size: Vector3, pos: Vector3, color_a: Color, color_b: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	var inst := MeshInstance3D.new()
	inst.name = label
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.cast_shadow = Quality.shadow_setting("prop")
	_generated.add_child(inst)


## 场地外沿矮石沿 + 一圈木栅栏（MultiMesh 合批，控制 draw call）。
func _build_rim() -> void:
	var half := grid_size * 0.5
	for spec in [[Vector3(grid_size.x + 1.0, 0.25, 0.5), Vector3(0, 0.0, -half.y - 0.25)],
			[Vector3(grid_size.x + 1.0, 0.25, 0.5), Vector3(0, 0.0, half.y + 0.25)],
			[Vector3(0.5, 0.25, grid_size.y), Vector3(-half.x - 0.25, 0.0, 0)],
			[Vector3(0.5, 0.25, grid_size.y), Vector3(half.x + 0.25, 0.0, 0)]]:
		_stone(spec[0], spec[1], Color("a89c80"))
	var transforms: Array = []
	var ex := half.x + FENCE_GAP
	var ez := half.y + FENCE_GAP
	var x := -ex + 1.0
	while x <= ex - 0.99:
		transforms.append(Transform3D(Basis(), Vector3(x, 0, -ez)))
		transforms.append(Transform3D(Basis(), Vector3(x, 0, ez)))
		x += 2.0
	var z := -ez + 1.0
	while z <= ez - 0.99:
		transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-ex, 0, z)))
		transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(ex, 0, z)))
		z += 2.0
	_multimesh("Fence", PROPS["fence"], transforms)


func _build_decor() -> void:
	var by_kind: Dictionary = {}
	for item in DECOR:
		for mirror in [false, true]:
			var tile := Vector2(item[1], item[2])
			if mirror:
				tile.x = grid_size.x - tile.x
			var basis := Basis(Vector3.UP, deg_to_rad(float(item[3]) * (-1.0 if mirror else 1.0))).scaled(Vector3.ONE * float(item[4]))
			var pos := FieldProjection.tile_to_world(tile, grid_size)
			by_kind.get_or_add(item[0], []).append(Transform3D(basis, pos))
	for kind in by_kind:
		_multimesh("Decor_" + kind, PROPS[kind], by_kind[kind])


func _multimesh(label: String, scene: PackedScene, transforms: Array) -> void:
	var source: Node3D = scene.instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = label
	inst.multimesh = mm
	inst.material_override = ToonStyle.material(Color.WHITE, Vector2.ONE, Quality.outline("prop"))
	inst.cast_shadow = Quality.shadow_setting("prop")
	_generated.add_child(inst)


func _stone(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	# 合并后颜色走顶点 COLOR（toon 着色器按线性值用，不像 source_color 的 tint 会自动线性化）→ 这里先转线性，与逐块 tint 版同色。
	_stone_parts.append([mesh, Transform3D(Basis.IDENTITY, pos), color.srgb_to_linear()])


func _build_stones() -> void:
	var inst := MeshInstance3D.new()
	inst.name = "Stones"
	inst.mesh = FxMesh.merge(_stone_parts)
	inst.material_override = ToonStyle.material(Color.WHITE, Vector2.ONE, Quality.outline("prop"))
	inst.cast_shadow = Quality.shadow_setting("prop")
	_generated.add_child(inst)


## 塔几何代理（子节点 Footprint/StoneKeep/TeamBand/Roof/Crown；D0 场地预览用）。
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
