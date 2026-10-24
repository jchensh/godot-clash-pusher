## 单个战斗单位的 3D 表现：读 Unit 状态做位置插值、朝向、血条、动作；不写回任何逻辑量。
## 有 GLB 动画的单位播 Idle/Walk/Attack；几何代理与缺失的 Death 片段走程序化回退（明确标注）。
extends Node3D

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const HpBar := preload("res://view/three_d/hp_bar_3d.gd")
const LABEL_FONT := preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")
const ToonStyle := preload("res://view/three_d/toon_style.gd")

const STATE_IDLE := "idle"
const STATE_WALK := "walk"
const STATE_ATTACK := "attack"
const STATE_DYING := "dying"
const MODE_MODEL := "model"
const MODE_PROXY := "proxy"

const SMOOTH_K := 18.0          # 与 2D 战斗同口径的指数平滑（10Hz 逻辑位 → 每帧显示位）
const WALK_SPEED_MIN := 0.25    # tile/秒：显示位移速度高于此视为行走
const WALK_HOLD := 0.18         # 秒：tick 间隙速度回落时保持行走，防动作闪烁
const TURN_K := 12.0
const AIR_HEIGHT := 1.8         # 纯表现高度，不进逻辑坐标/hash
const FLASH_DUR := 0.15
const DEATH_DUR := 0.6
const PROXY_ATTACK_DUR := 0.3

var unit_ref = null
var mode := MODE_PROXY
var state := STATE_IDLE
var clip := ""                  # 最近一次播放的动画片段名（代理为程序化动作名）
var death_mode := ""            # clip=播 Death 片段；fallback=程序化下沉缩小
var display_tile := Vector2.ZERO
var hp_ratio := 1.0
var attack_count := 0
var flying := false

var _grid := Vector2.ZERO
var _flipped := false
var _visual: Node3D
var _player: AnimationPlayer
var _hp_bar: Node3D
var _overlay: StandardMaterial3D
var _prev_hp := 0.0
var _prev_cooldown := 0.0
var _walk_hold := 0.0
var _attack_left := 0.0
var _attack_total := 0.0
var _flash := 0.0
var _death_t := 0.0
var _time := 0.0
var _yaw := 0.0
var _base_scale := 1.0


## info：{grid, flipped, color, model(PackedScene|null), model_scale, model_tint, name}
func setup(unit, info: Dictionary) -> void:
	unit_ref = unit
	_grid = info.grid
	_flipped = info.get("flipped", false)
	flying = unit.is_flying()
	display_tile = unit.pos
	_prev_hp = unit.hp
	_prev_cooldown = unit._attack_cooldown
	name = "Unit_%s_%d" % [unit.unit_id, unit.get_instance_id()]
	var color: Color = info.color
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var scene: PackedScene = info.get("model")
	if scene != null:
		_build_model(scene, float(info.get("model_scale", 1.0)), info.get("model_tint", Color.WHITE))
	else:
		_build_proxy(unit, color, str(info.get("name", unit.unit_id)))
	_add_team_ring(unit.body_radius, color)
	_hp_bar = HpBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.position.y = (AIR_HEIGHT if flying else 0.0) + 2.0
	_hp_bar.setup(clampf(unit.body_radius * 2.2, 0.8, 1.8), color)
	_hp_bar.visible = false
	add_child(_hp_bar)
	_apply_overlay()
	_yaw = _default_yaw(unit.owner_id)
	_place()
	state = ""   # 强制首次进入 Idle 真正播放片段
	_play(STATE_IDLE)


## 每帧从逻辑单位读状态；delta 只影响表现插值与动作时间。
func sync(unit, delta: float) -> void:
	_time += delta
	var prev_tile := display_tile
	var alpha := 1.0 - exp(-SMOOTH_K * delta)
	display_tile = display_tile.lerp(unit.pos, alpha)
	var moved := display_tile - prev_tile
	if delta > 0.0 and moved.length() / delta > WALK_SPEED_MIN:
		_walk_hold = WALK_HOLD
		_face_tile_dir(prev_tile, display_tile, delta)
	else:
		_walk_hold = maxf(_walk_hold - delta, 0.0)
	# 冷却跳升 = 逻辑层刚 mark_attacked（同 2D 战斗的上升沿判定）。
	var cooldown: float = unit._attack_cooldown
	if cooldown > _prev_cooldown + 0.01:
		_on_attack(unit)
	_prev_cooldown = cooldown
	if unit.hp < _prev_hp - 0.01:
		_flash = FLASH_DUR
	_prev_hp = unit.hp
	hp_ratio = unit.hp / unit.max_hp if unit.max_hp > 0.0 else 0.0
	_hp_bar.visible = hp_ratio < 0.999
	_hp_bar.set_ratio(hp_ratio)
	if _attack_left > 0.0:
		_attack_left = maxf(_attack_left - delta, 0.0)
		var target = unit.current_target
		if target != null and is_instance_valid(target):
			_face_tile_dir(display_tile, target.pos, delta)
	if _attack_left <= 0.0:
		_play(STATE_WALK if _walk_hold > 0.0 else STATE_IDLE)
	_tick_visual(delta)
	_place()


func begin_death() -> void:
	if state == STATE_DYING:
		return
	state = STATE_DYING
	unit_ref = null
	_hp_bar.visible = false
	_death_t = 0.0
	if _player != null and _player.has_animation("Death"):
		death_mode = "clip"
		clip = "Death"
		_player.play("Death", 0.1)
	else:
		death_mode = "fallback"
		clip = "fallback_death"
		if _player != null:
			_player.pause()


## 死亡表现推进；返回 true 表示播完、可释放节点。
func step_death(delta: float) -> bool:
	_death_t += delta
	var k := clampf(_death_t / DEATH_DUR, 0.0, 1.0)
	if death_mode == "fallback":
		_visual.scale = Vector3.ONE * _base_scale * (1.0 - k * 0.9)
		_visual.position.y = _height() - k * 0.6
		_visual.rotation.z = k * 1.2
	elif k > 0.75:   # Death 片段末尾快速缩没，避免节点释放时突然消失
		_visual.scale = Vector3.ONE * _base_scale * (1.0 - (k - 0.75) / 0.25)
	return _death_t >= DEATH_DUR


func _on_attack(unit) -> void:
	attack_count += 1
	var target = unit.current_target
	if target != null and is_instance_valid(target):
		_face_tile_dir(display_tile, target.pos, 1.0)
	var interval := maxf(float(unit.attack_speed) * 0.9, 0.1)
	if _player != null and _player.has_animation("Attack"):
		var length := _player.get_animation("Attack").length
		var speed := maxf(1.0, length / interval)
		_attack_total = length / speed
		_player.stop()
		_player.play("Attack", 0.05, speed)
		clip = "Attack"
	else:
		_attack_total = minf(PROXY_ATTACK_DUR, interval)
		clip = "proxy_attack"
	_attack_left = _attack_total
	state = STATE_ATTACK


func _play(next: String) -> void:
	if state == next:
		return
	state = next
	if _player != null:
		var wanted := "Walk" if next == STATE_WALK else "Idle"
		if _player.has_animation(wanted):
			_player.play(wanted, 0.15)
			clip = wanted
	else:
		clip = "proxy_" + next


## 程序化表现：受击闪白、飞行浮动、代理的走路颠步与攻击前冲（代理/缺片段时的明确回退）。
func _tick_visual(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_overlay.albedo_color.a = (_flash / FLASH_DUR) * 0.75
	var y := _height()
	if flying:
		y += sin(_time * 3.0) * 0.12
	_visual.position = Vector3(0, y, 0)
	if mode == MODE_PROXY:
		if state == STATE_WALK:
			_visual.position.y += absf(sin(_time * 10.0)) * 0.12
		elif state == STATE_ATTACK and _attack_total > 0.0:
			var k := 1.0 - _attack_left / _attack_total
			_visual.position.z += sin(k * PI) * 0.35


func _place() -> void:
	position = FieldProjection.tile_to_world(display_tile, _grid, _flipped)
	rotation.y = _yaw


func _face_tile_dir(from: Vector2, to: Vector2, delta: float) -> void:
	var a := FieldProjection.tile_to_world(from, _grid, _flipped)
	var b := FieldProjection.tile_to_world(to, _grid, _flipped)
	var dir := b - a
	if Vector2(dir.x, dir.z).length() < 0.0001:
		return
	var goal := atan2(dir.x, dir.z)   # 模型正面朝 +Z
	_yaw = lerp_angle(_yaw, goal, clampf(TURN_K * delta, 0.0, 1.0))


## 出生朝向：面向对方王塔所在的逻辑方向（玩家向 y 减小、对手向 y 增大），经投影换算视角翻转。
func _default_yaw(owner_id: int) -> float:
	var ahead := Vector2(0, -1) if owner_id == 0 else Vector2(0, 1)
	var a := FieldProjection.tile_to_world(display_tile, _grid, _flipped)
	var b := FieldProjection.tile_to_world(display_tile + ahead, _grid, _flipped)
	return atan2(b.x - a.x, b.z - a.z)


func _height() -> float:
	return AIR_HEIGHT if flying else 0.0


func _build_model(scene: PackedScene, model_scale: float, tint: Color) -> void:
	mode = MODE_MODEL
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	_visual.add_child(model)
	ToonStyle.apply(model, Color.WHITE, tint)
	_base_scale = model_scale
	_visual.scale = Vector3.ONE * model_scale
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _build_proxy(unit, color: Color, label: String) -> void:
	mode = MODE_PROXY
	var r := clampf(float(unit.body_radius), 0.25, 0.9)
	var body := MeshInstance3D.new()
	body.name = "ProxyBody"
	var capsule := CapsuleMesh.new()
	capsule.radius = r * 0.75
	capsule.height = maxf(r * 2.8, capsule.radius * 2.0 + 0.1)
	body.mesh = capsule
	body.position.y = capsule.height * 0.5
	body.material_override = _mat(color.lerp(Color.WHITE, 0.35))
	_visual.add_child(body)
	var nose := MeshInstance3D.new()   # 朝向标记：+Z 一侧的小方块
	nose.name = "ProxyFacing"
	var cube := BoxMesh.new()
	cube.size = Vector3(r * 0.5, r * 0.4, r * 0.5)
	nose.mesh = cube
	nose.position = Vector3(0, capsule.height * 0.7, capsule.radius)
	nose.material_override = _mat(color.darkened(0.3))
	_visual.add_child(nose)
	var tag := Label3D.new()
	tag.name = "ProxyLabel"
	tag.text = "代理 · %s" % label
	tag.font = LABEL_FONT
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 40
	tag.pixel_size = 0.01
	tag.outline_size = 8
	tag.position.y = capsule.height + 0.45
	_visual.add_child(tag)


func _add_team_ring(radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "TeamRing"
	var torus := TorusMesh.new()
	var r := clampf(radius, 0.25, 0.9)
	torus.inner_radius = r * 0.85
	torus.outer_radius = r * 1.05
	ring.mesh = torus
	ring.scale.y = 0.15
	ring.position.y = 0.04
	ring.material_override = _mat(color)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _apply_overlay() -> void:
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	for node in _visual.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D:
			(node as MeshInstance3D).material_overlay = _overlay


static func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat
