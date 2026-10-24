## 3D 迁移首步：只读场地与坐标预览；点击只显示落点，不发出牌/战斗指令。
extends Node3D

const Loader := preload("res://logic/config_loader.gd")
const ArenaLogic := preload("res://logic/arena.gd")
const Presenter := preload("res://view/three_d/arena_presenter.gd")
const FieldProjection := preload("res://view/three_d/field_projection.gd")
const Xiaoxiao := preload("res://assets/models/xiaoxiao/xiaoxiao_animated.glb")

var _arena := ArenaLogic.new()
var _field := Presenter.new()
var _camera: Camera3D
var _status: Label
var _marker: MeshInstance3D


func _ready() -> void:
	get_window().title = "全 3D 迁移 · 场地基础预览"
	var loader := Loader.new()
	loader.load_all()
	var config: Dictionary = loader.get_arena("default")
	_arena.setup(config)
	add_child(_field)
	_field.build(config)
	for side in config.towers:
		for kind in config.towers[side]:
			var tower: Dictionary = config.towers[side][kind]
			_arena.add_tower_footprint(tower.x, tower.y, tower.fw, tower.fh)
	_add_light(Vector3(-55, -25, 0), 1.1)
	_add_light(Vector3(-35, 145, 0), 0.45)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("d8ecfa")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e1ead6")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	_camera = Camera3D.new()
	_camera.position = Vector3(42, 52, 0)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.far = 200
	add_child(_camera)
	_camera.look_at(Vector3.ZERO)
	_camera.make_current()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	_add_mascot(Vector2(_field.grid_size.x * 0.4, config.deploy.player_y_min + 3.0), PI)
	_add_mascot(Vector2(_field.grid_size.x * 0.6, config.deploy.enemy_y_max - 3.0), 0.0)
	_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4
	ring.outer_radius = 0.55
	_marker.mesh = ring
	_marker.visible = false
	add_child(_marker)
	_build_labels()


func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	_camera.size = maxf(_field.grid_size.x + 8.0, (_field.grid_size.y + 6.0) / maxf(size.x / size.y, 0.1))


func _add_mascot(tile: Vector2, yaw: float) -> void:
	var model := Xiaoxiao.instantiate() as Node3D
	model.position = FieldProjection.tile_to_world(tile, _field.grid_size)
	model.rotation.y = yaw
	model.scale = Vector3.ONE * 0.75
	add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play("Idle")


func _add_light(degrees: Vector3, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = degrees
	light.light_energy = energy
	light.shadow_enabled = energy > 1.0
	light.directional_shadow_max_distance = 100
	add_child(light)


func _build_labels() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var labels := VBoxContainer.new()
	labels.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	labels.offset_top = 40
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(labels)
	for text in ["全 3D 场地基础", "我方蓝 · 敌方红 / 六塔与双桥来自现有配置", "塔为几何代理；当前仅验收场地与坐标"]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("244632"))
		labels.add_child(label)
	_status = Label.new()
	_status.text = "点击场地：预览己方部署坐标（不出兵）"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("244632"))
	labels.add_child(_status)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_preview_pick(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_preview_pick(event.position)


func _preview_pick(screen: Vector2) -> void:
	var tile: Variant = FieldProjection.ray_to_tile(_camera.project_ray_origin(screen),
		_camera.project_ray_normal(screen), _field.grid_size)
	if tile == null:
		_marker.visible = false
		return
	var legal: bool = _arena.can_deploy(ArenaLogic.OWNER_PLAYER, tile)
	_marker.position = FieldProjection.tile_to_world(tile, _field.grid_size, false, 0.4)
	_marker.visible = true
	var material := StandardMaterial3D.new()
	material.no_depth_test = true
	material.albedo_color = Color("4dce82") if legal else Color("e76d67")
	_marker.material_override = material
	_status.text = "tile (%.2f, %.2f) · %s" % [tile.x, tile.y, "合法地面" if legal else "禁止部署"]
