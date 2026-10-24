## D1/D2 预览：本地天梯局，真人拖卡出兵（3D 出牌输入）对 AI，验证 3D 战斗表现与部署手感。
## 实验场景：不接服务端、不写经济/进度、不进正式路由；正式 PvE/PvP 入口仍是 2D（D4/D5 才接线）。
extends Node3D

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const BattleScript := preload("res://logic/battle.gd")
const SimClockScript := preload("res://logic/sim_clock.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")
const Presenter := preload("res://view/three_d/battle_presenter.gd")
const DeployInput := preload("res://view/three_d/deploy_input_3d.gd")
const BattleCamera := preload("res://view/three_d/battle_camera.gd")

const LEVEL_ID := "ladder_01"
const SPEEDS := [1.0, 2.0, 4.0]
const TEXT_COLOR := Color("244632")
const HUD_TEXT := Color("f4f1e6")
const TOP_H := 150.0             # 顶部说明/状态区（像素，750×1334 基准）
const HUD_H := 230.0             # 底部手牌栏
const HAND_SIZE := 4

var _loader = Loader.new()
var _match = null
var _player_ai = null
var _enemy_ai = null
var _presenter := Presenter.new()
var _deploy := DeployInput.new()
var _camera: Camera3D
var _status: Label
var _hud: Control
var _cards: Array = []
var _next_label: Label
var _elixir_label: Label
var _unit_names: Dictionary = {}
var _acc := 0.0
var _paused := false
var _flipped := false
var _watch := false              # true = 双方都交 AI（观战）；false = 真人操作本方
var _speed_index := 0


func _ready() -> void:
	get_window().title = "全 3D 迁移 · D2 出牌与战斗预览"
	_loader.load_all()
	for unit_id in _loader.units:
		_unit_names[unit_id] = str(_loader.units[unit_id].get("name", unit_id))
	_presenter.name = "BattlePresenter"
	_presenter.auto_advance = false
	add_child(_presenter)
	_deploy.name = "DeployInput"
	_deploy.deploy_requested.connect(_on_deploy_requested)
	add_child(_deploy)
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
	add_child(_camera)
	_camera.make_current()
	_build_labels()
	_build_hud()
	_restart()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _restart() -> void:
	_deploy.cancel_drag()
	_match = MatchScript.new(_loader)
	_match.setup(LEVEL_ID)
	_player_ai = AIControllerScript.new(_match, _loader, "normal", AIControllerScript.OWNER_PLAYER)
	_enemy_ai = AIControllerScript.new(_match, _loader, "normal", AIControllerScript.OWNER_OPPONENT)
	_acc = 0.0
	_setup_view()
	Log.i("[3D-D2] 预览开局 level=%s flipped=%s watch=%s" % [LEVEL_ID, _flipped, _watch])


## 翻转视角 = 联机 side2：真人改操作 opponent、整场 180°；只换表现与操作方，不动正在进行的这局 sim。
func _setup_view() -> void:
	_presenter.setup(_match.battle, _loader.get_arena("default"), {
		"local_owner": _human_owner(),
		"flipped": _flipped,
		"unit_names": _unit_names,
	})
	_deploy.configure(_camera, _match.battle.arena, _loader, _human_owner(), _flipped,
		get_viewport().get_visible_rect().size)


func _human_owner() -> int:
	return 1 if _flipped else 0


func _human():
	return _match.opponent if _flipped else _match.player


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
		# 与 tools/balance_probe.gd 同序：双方回涨 → 我方 AI → 敌方 AI → battle.step；真人方的 AI 不出牌。
		_match.player.regen(dt)
		_match.opponent.regen(dt)
		if _watch or _human_owner() != 0:
			_player_ai.tick(dt)
		if _watch or _human_owner() != 1:
			_enemy_ai.tick(dt)
		_match.battle.step(dt)
		_acc -= dt
	if _deploy.dragging:
		_deploy.update_drag(get_viewport().get_mouse_position())
	_presenter.advance(scaled)
	_sync_hand()
	_update_status()


# —— 手牌栏：按下卡牌开始拖拽、松手落子（同 2D CR 式交互）——
func _on_card_down(index: int) -> void:
	if _watch or _match.is_over():
		return
	var hand: Array = _human().deck.get_hand()
	if index >= hand.size() or hand[index] == null or not _human().can_play(index):
		return
	_deploy.begin_drag(index, str(hand[index]))
	_deploy.update_drag(get_viewport().get_mouse_position())


func _on_card_up(index: int, screen: Vector2) -> void:
	if _deploy.dragging and _deploy.hand_index == index:
		_deploy.end_drag(screen)


## 合法落点走与 2D 相同的权威入口；PvP 接线（D5）时这里换成发送 DeployCmd。
func _on_deploy_requested(index: int, tile: Vector2) -> void:
	var ok: bool = _human().try_play_card(index, tile)
	Log.i("[3D-D2] 出牌 hand=%d tile=(%.3f, %.3f) owner=%d ok=%s" % [index, tile.x, tile.y, _human_owner(), ok])


func _sync_hand() -> void:
	var who = _human()
	var hand: Array = who.deck.get_hand()
	for i in _cards.size():
		var button: Button = _cards[i]
		var cid = hand[i] if i < hand.size() else null
		if cid == null:
			button.text = "—"
			button.disabled = true
			continue
		button.text = "%s\n%d 费" % [_loader.get_card(str(cid)).get("name", cid), who.card_cost(cid)]
		button.disabled = _watch or _match.is_over() or not who.can_play(i)
		button.modulate = Color(1, 1, 1, 0.55) if _deploy.dragging and _deploy.hand_index == i else Color.WHITE
	var next = who.deck.peek_next()
	_next_label.text = "下一张\n%s" % ("—" if next == null else _loader.get_card(str(next)).get("name", next))
	_elixir_label.text = "圣水 %d / %d" % [who.elixir.get_int(), int(who.elixir.maximum)]


func _update_status() -> void:
	var battle = _match.battle
	var lines: Array = []
	lines.append("剩余 %.0f 秒 · 场上单位 %d · 速度 x%d%s" % [battle.remaining_time(),
		_presenter.unit_actor_count(), int(SPEEDS[_speed_index]), " · 已暂停" if _paused else ""])
	lines.append("视角：%s · %s" % ["对方（side2 翻转）" if _flipped else "本方", "AI 观战" if _watch else "你操作蓝方"])
	if _deploy.dragging:
		var tile: Variant = _deploy.drop_tile
		lines.append("落点：%s" % ("场外" if tile == null else "(%.2f, %.2f) %s" % [tile.x, tile.y,
			"可部署" if _deploy.legal else "禁止部署"]))
	else:
		var proxies: Array = []
		for unit_id in _presenter.proxy_unit_ids():
			proxies.append(_unit_names.get(unit_id, unit_id))
		lines.append("当前代理：%s" % ("无" if proxies.is_empty() else "、".join(proxies)))
	if _match.is_over():
		var result: int = _match.get_result()
		var mine: int = BattleScript.RESULT_OPPONENT_WIN if _flipped else BattleScript.RESULT_PLAYER_WIN
		var theirs: int = BattleScript.RESULT_PLAYER_WIN if _flipped else BattleScript.RESULT_OPPONENT_WIN
		var text := "平局"
		if result == mine:
			text = "蓝方胜"
		elif result == theirs:
			text = "红方胜"
		lines.append("对局结束：%s（R 重开）" % text)
	_status.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_deploy.cancel_drag()   # 右键取消拖拽
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE:
			_set_paused(not _paused)
		KEY_R:
			_restart()
		KEY_F:
			_flipped = not _flipped
			_deploy.cancel_drag()
			_setup_view()
		KEY_T:
			_watch = not _watch
			_deploy.cancel_drag()
		KEY_1, KEY_2, KEY_3:
			_set_speed((event as InputEventKey).keycode - KEY_1)


func _fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	BattleCamera.fit(_camera, _presenter.grid_size, size, _field_zone(size))
	_deploy.viewport_size = size
	_deploy.blocked_rects = [Rect2(0, 0, size.x, TOP_H), Rect2(0, size.y - HUD_H, size.x, HUD_H)]


func _field_zone(size: Vector2) -> Rect2:
	return Rect2(0.0, TOP_H, size.x, size.y - TOP_H - HUD_H)


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
	labels.offset_top = 12
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(labels)
	labels.add_child(_label("D2 · 3D 出牌与战斗预览（本地，不联网）", 22))
	labels.add_child(_label("拖卡出兵 · 右键取消 · 空格 暂停 · R 重开 · F 翻转 · T 观战 · 1/2/3 速度", 15))
	_status = _label("", 17)
	labels.add_child(_status)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = PanelContainer.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hud.offset_top = -HUD_H
	layer.add_child(_hud)
	var rows := VBoxContainer.new()
	_hud.add_child(rows)
	_elixir_label = _label("", 20, HUD_TEXT)
	rows.add_child(_elixir_label)
	var bar := HBoxContainer.new()
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 10)
	rows.add_child(bar)
	_next_label = _label("", 16, HUD_TEXT)
	_next_label.custom_minimum_size = Vector2(110, 0)
	bar.add_child(_next_label)
	for i in HAND_SIZE:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.button_down.connect(_on_card_down.bind(i))
		button.button_up.connect(func(): _on_card_up(i, get_viewport().get_mouse_position()))
		bar.add_child(button)
		_cards.append(button)


func _label(text: String, size: int, color := TEXT_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
