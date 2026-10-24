## D7 单模型 3D 预览台（卡牌详情等 2D 页面嵌入用）：独立小世界（SubViewport own_world_3d），透明底叠在 2D 框里；
## 慢慢自转、拖动旋转、点一下切换动作（待机 → 走 → 攻击）。
## 资源纪律：同一时刻只持有一个模型实例；换模型 / clear / 离开页面立即 free，场景按需 load、不进全局常驻缓存。
extends SubViewportContainer

signal action_changed(action: String)

const ToonStyle := preload("res://view/three_d/toon_style.gd")
const UnitModels := preload("res://view/three_d/unit_models.gd")
const BattleLighting := preload("res://view/three_d/battle_lighting.gd")
const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")

const ACTIONS := ["Idle", "Walk", "Attack"]
const SPIN_DEG := 22.0           # 自转速度（度/秒）；拖动时暂停
const FIT_HEIGHT := 1.0          # 模型归一身高（世界单位），镜头按此构图
const FIT_WIDTH := 1.3           # 宽体模型（熔岩猎犬/巨人）另按宽度收
const TAP_SLOP := 8.0            # 按下后移动不超过此像素 = 点击

var viewport: SubViewport
var pivot: Node3D
var camera: Camera3D
var auto_spin := true
var action := ""

var _model: Node3D
var _player: AnimationPlayer
var _action_i := 0
var _pressing := false
var _moved := 0.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)
	BattleLighting.setup(viewport)
	var env := (viewport.get_node("BattleEnvironment") as WorldEnvironment).environment
	env.background_mode = Environment.BG_CLEAR_COLOR   # 透明底：露出外面的 2D 框
	camera = Camera3D.new()
	camera.fov = 28.0
	var eye := Vector3(0.0, 0.85, 3.3)
	camera.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.48, 0.0) - eye, Vector3.UP), eye)
	viewport.add_child(camera)
	camera.current = true
	pivot = Node3D.new()
	pivot.name = "Pivot"
	viewport.add_child(pivot)


## 展示一个单位（派生/借用自动解析）；无模型（法术卡等）返回 false，台上清空。
func show_unit(unit_id: String) -> bool:
	clear()
	var asset := UnitModels.asset_of(unit_id)
	if asset.is_empty():
		return false
	_mount(load(UnitModels.glb_path(asset)) as PackedScene, ArenaPresenter.COLOR_BLUE, UnitModels.tint_of(unit_id))
	return true


func has_model() -> bool:
	return _model != null


func model() -> Node3D:
	return _model


## 下一个动作（缺失的片段跳过）；攻击播完自动回待机。
func cycle_action() -> void:
	if _player == null:
		return
	for step in ACTIONS.size():
		_action_i = (_action_i + 1) % ACTIONS.size()
		if _player.has_animation(ACTIONS[_action_i]):
			break
	_play()


func clear() -> void:
	if _model != null:
		_model.free()
	_model = null
	_player = null
	_action_i = 0
	action = ""
	pivot.rotation = Vector3.ZERO


func _mount(scene: PackedScene, team: Color, tint: Color) -> void:
	_model = scene.instantiate()
	ToonStyle.apply(_model, team, tint)
	pivot.add_child(_model)
	_fit()
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] if not players.is_empty() else null
	_play()


## 按静止姿态包围盒归一：身高 FIT_HEIGHT（过宽再按宽收），脚底贴地、水平居中。
func _fit() -> void:
	var box := AABB()
	var first := true
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var b := (node as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var k := minf(FIT_HEIGHT / maxf(box.size.y, 0.01), FIT_WIDTH / maxf(maxf(box.size.x, box.size.z), 0.01))
	_model.scale = Vector3.ONE * k
	_model.position = Vector3(-(box.position.x + box.size.x * 0.5) * k, -box.position.y * k,
		-(box.position.z + box.size.z * 0.5) * k)


func _play() -> void:
	if _player == null:
		return
	var anim: String = ACTIONS[_action_i]
	if not _player.has_animation(anim):
		return
	_player.stop()
	_player.play(anim, 0.15)
	if anim == "Attack":
		_player.queue("Idle")
	action = anim
	action_changed.emit(anim)


func _process(delta: float) -> void:
	if auto_spin and not _pressing and _model != null:
		pivot.rotation.y += deg_to_rad(SPIN_DEG) * delta


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_moved = 0.0
		else:
			if _pressing and _moved <= TAP_SLOP:
				cycle_action()
			_pressing = false
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var dx: float = (event as InputEventMouseMotion).relative.x
		_moved += absf(dx)
		pivot.rotation.y += dx * 0.012
		accept_event()


func _exit_tree() -> void:
	clear()
