## D7 菜单 3D 小场景（主菜单章节主视觉 / 登录页底部）：草地小岛上王城 + 两座蓝顶箭塔 + 树 + 几名角色待机，
## 镜头缓慢左右摆动。独立小世界（SubViewport own_world_3d），可透明底叠在 2D 背景上；纯展示，不吃输入。
## 资源纪律：模型按需 load、不进全局常驻缓存；离开页面随节点释放。王国同款调色（降饱和）。
extends SubViewportContainer

const ToonStyle := preload("res://view/three_d/toon_style.gd")
const UnitModels := preload("res://view/three_d/unit_models.gd")
const BattleLighting := preload("res://view/three_d/battle_lighting.gd")
const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")
const KingdomPresenter := preload("res://view/three_d/kingdom_presenter.gd")
const GROUND_SHADER := preload("res://view/three_d/ground.gdshader")

## [资产, 位置(x, z), 朝向 yaw 度, 目标高度(米)]；王城居中靠后，箭塔左右，角色在前排面朝镜头。
const PROPS := [
	["k_keep", Vector2(0.0, -1.6), 0.0, 3.0],
	["arrow_tower", Vector2(-3.4, -0.9), 20.0, 2.4],
	["arrow_tower", Vector2(3.4, -0.9), -20.0, 2.4],
	["prop_tree", Vector2(-4.6, -2.4), 0.0, 2.0],
	["prop_tree", Vector2(4.8, -2.2), 0.0, 1.7],
	["prop_bush", Vector2(-4.4, 0.6), 0.0, 0.6],
	["prop_bush", Vector2(4.5, 0.9), 0.0, 0.5],
]
const UNITS := [
	["princess_body", Vector2(-1.5, 1.2), 15.0, 1.0],
	["knight_body", Vector2(-0.4, 1.6), 5.0, 1.15],
	["royal_giant_body", Vector2(0.9, 1.3), -10.0, 1.25],
	["phoenix_body", Vector2(2.0, 0.9), -20.0, 0.9],
]
const SWAY_DEG := 16.0           # 镜头左右摆幅
const SWAY_PERIOD := 14.0        # 摆动周期（秒）
const ISLAND_R := 6.2

var viewport: SubViewport
var camera: Camera3D
var _t := 0.0
var _models: Array = []


## transparent：true = 透明底（小岛浮在 2D 背景上）；false = 天空色底。
func build(transparent := true) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = transparent
	add_child(viewport)
	BattleLighting.setup(viewport)
	if transparent:
		(viewport.get_node("BattleEnvironment") as WorldEnvironment).environment.background_mode = \
			Environment.BG_CLEAR_COLOR
	camera = Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	_build_island()
	for p in PROPS:
		_place(str(p[0]), p[1], float(p[2]), float(p[3]), str(p[0]) == "arrow_tower")
	for u in UNITS:
		_place(UnitModels.asset_of(str(u[0])), u[1], float(u[2]), float(u[3]), false, UnitModels.tint_of(str(u[0])))
	_update_camera()


func model_count() -> int:
	return _models.size()


func _process(delta: float) -> void:
	_t += delta
	_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	var yaw := deg_to_rad(SWAY_DEG) * sin(_t * TAU / SWAY_PERIOD)
	var eye := Vector3(sin(yaw) * 16.0, 7.4, cos(yaw) * 16.0)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.7, 0.0) - eye, Vector3.UP), eye)


func _build_island() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = ISLAND_R
	disc.bottom_radius = ISLAND_R - 0.5
	disc.height = 0.6
	disc.radial_segments = 40
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("color_a", KingdomPresenter.GRASS_A)
	mat.set_shader_parameter("color_b", KingdomPresenter.GRASS_B)
	mat.set_shader_parameter("saturation", KingdomPresenter.GRADE.x)
	mat.set_shader_parameter("brightness", KingdomPresenter.GRADE.y)
	var mi := MeshInstance3D.new()
	mi.name = "Island"
	mi.mesh = disc
	mi.material_override = mat
	mi.position = Vector3(0.0, -0.3, 0.0)
	viewport.add_child(mi)


func _place(asset: String, pos: Vector2, yaw: float, height: float, team: bool, tint := Color.WHITE) -> void:
	if asset.is_empty():
		return
	var scene := load("res://assets/models/%s/%s.glb" % [asset, "xiaoxiao_animated" if asset == "xiaoxiao" else asset])
	if scene == null:
		return
	var inst: Node3D = (scene as PackedScene).instantiate()
	ToonStyle.apply(inst, ArenaPresenter.COLOR_BLUE if team else Color.WHITE, tint, KingdomPresenter.GRADE)
	var box := AABB()
	var first := true
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var b := (node as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k := height / maxf(box.size.y, 0.01)
	inst.scale = Vector3.ONE * k
	inst.position = Vector3(pos.x, -box.position.y * k, pos.y)
	inst.rotation.y = deg_to_rad(yaw)
	viewport.add_child(inst)
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty() and (players[0] as AnimationPlayer).has_animation("Idle"):
		(players[0] as AnimationPlayer).play("Idle")
	_models.append(inst)
