## D1 预览：本地 AI 对 AI 跑一局天梯配置，验证共用 3D 战斗 presenter 的单位/塔表现。
## 实验场景：不接服务端、不写经济/进度、不进正式路由；正式 PvE/PvP 入口仍是 2D（D4/D5 才接线）。
extends Node3D

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const BattleScript := preload("res://logic/battle.gd")
const SimClockScript := preload("res://logic/sim_clock.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")
const Presenter := preload("res://view/three_d/battle_presenter.gd")

const LEVEL_ID := "ladder_01"
const SPEEDS := [1.0, 2.0, 4.0]
const TEXT_COLOR := Color("244632")

var _loader = Loader.new()
var _match = null
var _player_ai = null
var _enemy_ai = null
var _presenter := Presenter.new()
var _camera: Camera3D
var _status: Label
var _unit_names: Dictionary = {}
var _acc := 0.0
var _paused := false
var _flipped := false
var _speed_index := 0


func _ready() -> void:
	get_window().title = "全 3D 迁移 · D1 战斗表现预览"
	_loader.load_all()
	for unit_id in _loader.units:
		_unit_names[unit_id] = str(_loader.units[unit_id].get("name", unit_id))
	_presenter.name = "BattlePresenter"
	_presenter.auto_advance = false
	add_child(_presenter)
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
	_build_labels()
	_restart()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _restart() -> void:
	_match = MatchScript.new(_loader)
	_match.setup(LEVEL_ID)
	_player_ai = AIControllerScript.new(_match, _loader, "normal", AIControllerScript.OWNER_PLAYER)
	_enemy_ai = AIControllerScript.new(_match, _loader, "normal", AIControllerScript.OWNER_OPPONENT)
	_acc = 0.0
	_setup_presenter()
	Log.i("[3D-D1] 预览开局 level=%s flipped=%s" % [LEVEL_ID, _flipped])


## 翻转视角 = 联机 side2：本方变为 opponent、整场 180°；只换表现，不动正在进行的这局 sim。
func _setup_presenter() -> void:
	_presenter.setup(_match.battle, _loader.get_arena("default"), {
		"local_owner": 1 if _flipped else 0,
		"flipped": _flipped,
		"unit_names": _unit_names,
	})


## 速度走 Engine.time_scale：sim 推进与骨骼动画同倍率（只在本实验场景生效，离开时复原）。
func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _set_speed(index: int) -> void:
	_speed_index = index
	Engine.time_scale = SPEEDS[index]


## 暂停：停 sim，并禁用 presenter 子树处理，使 AnimationPlayer 一并定格。
func _set_paused(value: bool) -> void:
	_paused = value
	_presenter.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT


func _process(delta: float) -> void:
	if _match == null:
		return
	var scaled: float = 0.0 if _paused else delta
	_acc += scaled
	var dt: float = SimClockScript.TICK_DELTA
	while _acc >= dt and not _match.is_over():
		# 与 tools/balance_probe.gd 同序：双方回涨 → 我方 AI → 敌方 AI → battle.step。
		_match.player.regen(dt)
		_match.opponent.regen(dt)
		_player_ai.tick(dt)
		_enemy_ai.tick(dt)
		_match.battle.step(dt)
		_acc -= dt
	_presenter.advance(scaled)
	_update_status()


func _update_status() -> void:
	var battle = _match.battle
	var lines: Array = []
	lines.append("剩余 %.0f 秒 · 场上单位 %d · 速度 x%d%s" % [battle.remaining_time(),
		_presenter.unit_actor_count(), int(SPEEDS[_speed_index]), " · 已暂停" if _paused else ""])
	lines.append("视角：%s" % ("对方（side2 翻转）" if _flipped else "本方"))
	var proxies: Array = []
	for unit_id in _presenter.proxy_unit_ids():
		proxies.append(_unit_names.get(unit_id, unit_id))
	lines.append("当前代理：%s" % ("无" if proxies.is_empty() else "、".join(proxies)))
	if _match.is_over():
		var mine: int = BattleScript.RESULT_OPPONENT_WIN if _flipped else BattleScript.RESULT_PLAYER_WIN
		var theirs: int = BattleScript.RESULT_PLAYER_WIN if _flipped else BattleScript.RESULT_OPPONENT_WIN
		var result: int = _match.get_result()
		var text := "平局"
		if result == mine:
			text = "蓝方胜"
		elif result == theirs:
			text = "红方胜"
		lines.append("对局结束：%s（R 重开）" % text)
	_status.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			_set_paused(not _paused)
		KEY_R:
			_restart()
		KEY_F:
			_flipped = not _flipped
			_setup_presenter()
		KEY_1, KEY_2, KEY_3:
			_set_speed((event as InputEventKey).keycode - KEY_1)


func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var grid: Vector2 = _presenter.grid_size
	_camera.size = maxf(grid.x + 8.0, (grid.y + 6.0) / maxf(size.x / size.y, 0.1))


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
	for text in ["D1 · 3D 战斗表现预览（AI 对 AI，本地不联网）", "空格 暂停 · R 重开 · F 翻转视角 · 1/2/3 速度"]:
		labels.add_child(_label(text, 22))
	_status = _label("", 18)
	labels.add_child(_status)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label
