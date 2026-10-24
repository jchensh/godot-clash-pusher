## 小小 3D 资产独立展示台：仅表现预览，不接玩法、账号或经济。
extends Node3D

const CLIP_LABELS := {"Idle": "待机", "Walk": "行走", "Attack": "攻击"}
const VIEW_YAW := 0.45
const VIEW_DISTANCE := 6.5

@onready var _model: Node3D = $Model
@onready var _orbit: Node3D = $CameraOrbit
@onready var _camera: Camera3D = $CameraOrbit/Camera3D

var _player: AnimationPlayer
var _status: Label
var _pause_button: Button
var _speed_label: Label
var _clip_buttons: Dictionary = {}
var _paused := false
var _turntable := false


func _ready() -> void:
	get_window().title = "小小 · 3D 动作展示"
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_build_hud()
	if _player == null:
		_status.text = "动画资源未加载"
		push_error("小小模型缺少 AnimationPlayer")
		return
	_player.animation_finished.connect(_on_animation_finished)
	get_viewport().size_changed.connect(_fit_camera)
	_reset_view()
	play_clip("Idle")


func _process(delta: float) -> void:
	if _turntable:
		_orbit.rotation.y += delta * 0.35


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_orbit.rotation.y -= event.relative.x * 0.008
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_orbit.rotation.y -= event.relative.x * 0.008
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-0.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.4)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: play_clip("Idle")
			KEY_2: play_clip("Walk")
			KEY_3: play_clip("Attack")
			KEY_SPACE: _toggle_pause()
			KEY_R: _reset_view()


func play_clip(clip: String) -> void:
	if _player == null or not _player.has_animation(clip):
		push_error("小小动画不存在：%s" % clip)
		return
	_paused = false
	_pause_button.text = "暂停"
	_player.play(clip, 0.12)
	_status.text = "%s · %s" % [CLIP_LABELS[clip], "单次播放后回到待机" if clip == "Attack" else "循环播放"]
	for name in _clip_buttons:
		(_clip_buttons[name] as Button).set_pressed_no_signal(name == clip)


func _on_animation_finished(clip: StringName) -> void:
	if clip == &"Attack":
		play_clip("Idle")


func _toggle_pause() -> void:
	if _player == null:
		return
	_paused = not _paused
	if _paused:
		_player.pause()
	else:
		_player.play()
	_pause_button.text = "继续" if _paused else "暂停"


func _set_speed(value: float) -> void:
	if _player != null:
		_player.speed_scale = value
	_speed_label.text = "播放速度  %.2f×" % value


func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	_camera.size = maxf(4.8, 4.4 / aspect)


func _reset_view() -> void:
	_orbit.rotation = Vector3(0.0, VIEW_YAW, 0.0)
	_camera.position = Vector3(0.0, 0.65, VIEW_DISTANCE)
	_camera.look_at(Vector3(0.0, 1.4, 0.0))
	_fit_camera()


func _zoom(step: float) -> void:
	_camera.size = clampf(_camera.size + step, 3.8, 12.0)


func _button(text: String, callback: Callable, parent: Container) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(text: String, font_size: int, parent: Container) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("244632"))
	parent.add_child(label)
	return label


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var header := VBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 44
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(header)
	_label("小小", 54, header)
	_label("3D 角色动作展示", 24, header)
	_status = _label("正在加载…", 22, header)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -282
	panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.98, 0.93, 0.96)
	style.set_corner_radius_all(20)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var clips := HBoxContainer.new()
	clips.add_theme_constant_override("separation", 12)
	box.add_child(clips)
	for clip in CLIP_LABELS:
		var button := _button(CLIP_LABELS[clip], play_clip.bind(clip), clips)
		button.toggle_mode = true
		_clip_buttons[clip] = button
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	box.add_child(controls)
	_pause_button = _button("暂停", _toggle_pause, controls)
	_button("重置视角", _reset_view, controls)
	var turn := _button("自动旋转", func(): _turntable = not _turntable, controls)
	turn.toggle_mode = true
	_speed_label = _label("播放速度  1.00×", 20, box)
	var speed := HSlider.new()
	speed.min_value = 0.25
	speed.max_value = 2.0
	speed.step = 0.05
	speed.value = 1.0
	speed.custom_minimum_size.y = 28
	speed.value_changed.connect(_set_speed)
	box.add_child(speed)
	_label("拖动旋转 · 滚轮缩放 · 1/2/3 切动作 · 空格暂停", 17, box)
