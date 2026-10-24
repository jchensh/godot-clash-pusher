## D4 正式战斗页 3D 冒烟（真实场景树，无需点界面）：
## ①自由对战：3D 战场层建好、镜头投影与引擎一致；手牌按钮同一入口拖卡出兵（合法出兵 / 松在手牌栏取消 /
##   松在天空无效均不扣圣水）；整局跑完节点数恒 = 存活单位，分出胜负后结算按钮出现在弹窗层。
## ②新手引导：教程层就位，点击推进到「出兵」步时放行出牌，经 3D 落点出兵后推进；高亮框落在屏内。
## 不联网：移除 Online autoload，GameState 回退仓库 JSON 配置（闯关模式要真服务器，交真人用例）。
## 用法：godot --headless --path . --script res://tools/check_battle_scene_3d.gd
extends SceneTree

const GameStateScript := preload("res://view/game_state.gd")
const CampaignStateScript := preload("res://logic/campaign_state.gd")
const FieldProjection := preload("res://view/three_d/field_projection.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var online := root.get_node_or_null("Online")
	if online != null:
		root.remove_child(online)
		online.free()
	await _check_free_battle()
	await _check_tutorial()
	for failure in _failures:
		push_error(failure)
	print("BATTLE_SCENE_3D: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)


func _open_battle() -> Node:
	var scene: Node = load("res://view/battle_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	return scene


func _close(scene: Node) -> void:
	root.remove_child(scene)
	scene.free()
	await process_frame


func _check_free_battle() -> void:
	GameStateScript.campaign = null
	GameStateScript.run = null
	GameStateScript.tutorial = false
	GameStateScript.stage_id = ""
	GameStateScript.level_id = "ladder_01"
	GameStateScript.player_deck = []
	var scene: Node = await _open_battle()
	var field = scene.get("_field3d")
	if field == null:
		_failures.append("自由对战未建 3D 战场层")
		await _close(scene)
		return
	if not field.camera.current:
		_failures.append("3D 镜头未设为当前相机")
	_check_projection(scene, field)
	var m = scene.get("match_obj")
	for i in 80:
		scene._process(0.1)   # 攒圣水（敌方 AI 同时在出牌）
	var index := _spawn_card(scene)
	if index < 0:
		_failures.append("没有可出的兵牌")
	else:
		var tile := Vector2(10.5, 24.5)
		var finger: Vector2 = field.tile_to_screen(tile) + Vector2(0.0, field.deploy.lift_pixels())
		# 松在手牌栏 = 取消；松在顶部天空 = 场外无效：都不扣圣水。
		for screen in [Vector2(375.0, 1300.0), Vector2(375.0, 70.0)]:
			var before: float = m.player.elixir.get_amount()
			scene._on_card_down(index)
			scene._process(0.016)   # 下一帧同步：ghost 跟手
			if not field.deploy.dragging:
				_failures.append("按下手牌未开始 3D 拖拽")
			scene._release_card(index, screen)
			scene._process(0.016)
			if m.player.elixir.get_amount() < before - 0.001 or field.deploy.dragging:
				_failures.append("松手在 %s 应取消且撤 ghost" % screen)
		var elixir: int = m.player.elixir.get_int()
		var near_before := _count_near(m, 0, tile)
		scene._on_card_down(index)
		scene._process(0.016)   # 拖拽中一帧：ghost 跟手
		scene._release_card(index, finger)
		if m.player.elixir.get_int() >= elixir or _count_near(m, 0, tile) <= near_before:
			_failures.append("3D 拖卡出兵失败（圣水 %d→%d）" % [elixir, m.player.elixir.get_int()])
		print("BATTLE_SCENE_3D: 出兵 tile=%s 附近我方单位 %d→%d" % [tile, near_before, _count_near(m, 0, tile)])
	var presenter = field.presenter
	var steps := 0
	while not m.is_over() and steps < 4000:
		scene._process(0.1)
		steps += 1
		var alive := 0
		for u in m.battle.arena.get_units():
			if u.is_alive():
				alive += 1
		if presenter.unit_actor_count() != alive:
			_failures.append("第 %d 步节点数 %d ≠ 存活单位 %d" % [steps, presenter.unit_actor_count(), alive])
			break
	if not m.is_over():
		_failures.append("对局未在预期内结束")
	for i in 12:
		scene._process(0.1)   # 胜负演出 → 结算按钮淡入
	var layer: Control = scene.get("_result_layer")
	var buttons := 0
	for child in layer.get_children():
		if child is Button:
			buttons += 1
	if not layer.is_inside_tree() or buttons == 0:
		_failures.append("结算层未入弹窗层或没有按钮（buttons=%d）" % buttons)
	print("BATTLE_SCENE_3D: 自由对战 steps=%d result=%d buttons=%d" % [steps, m.get_result(), buttons])
	await _close(scene)


func _check_tutorial() -> void:
	var levels: Array = GameStateScript.config().get_campaign("default").get("levels", [])
	GameStateScript.run = null
	GameStateScript.campaign = CampaignStateScript.new([levels[0]] if not levels.is_empty() else [])
	GameStateScript.tutorial = true
	GameStateScript.stage_id = ""
	var scene: Node = await _open_battle()
	var field = scene.get("_field3d")
	if field == null or scene.get("_tut_layer") == null or int(scene.get("_tut_i")) != 0:
		_failures.append("引导战未建 3D 战场或教程层")
		await _close(scene)
		return
	var vp := Vector2(scene.get("_vw"), scene.get("_vh"))
	for hl in ["elixir", "hand", "field"]:
		var r: Rect2 = scene._tut_rect(hl)
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > vp.x + 0.5 or r.end.y > vp.y + 0.5 or r.get_area() <= 1.0:
			_failures.append("教程高亮 %s 越出屏幕或为空：%s" % [hl, r])
	var steps: Array = scene.get("_tut_steps")
	var deploy_step := -1
	for i in steps.size():
		if str(steps[i].get("advance", "")) == "card_played":
			deploy_step = i
			break
	while int(scene.get("_tut_i")) >= 0 and int(scene.get("_tut_i")) < deploy_step:
		scene._tut_tap()
	if deploy_step >= 0:
		if scene.get("_tut_layer").mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_failures.append("出兵步教程层应放行点击")
		for i in 60:
			scene._process(0.1)
		var index := _spawn_card(scene)
		if index >= 0:
			var finger: Vector2 = field.tile_to_screen(Vector2(12.0, 24.0)) + Vector2(0.0, field.deploy.lift_pixels())
			scene._on_card_down(index)
			scene._release_card(index, finger)
		if int(scene.get("_tut_i")) == deploy_step:
			_failures.append("引导出兵步经 3D 出牌后未推进")
	print("BATTLE_SCENE_3D: 引导 steps=%d deploy_step=%d now=%d" % [steps.size(), deploy_step, int(scene.get("_tut_i"))])
	GameStateScript.tutorial = false
	GameStateScript.campaign = null
	await _close(scene)


## battle_scene 的 tile→屏幕（借 3D 镜头的纯数学）必须与引擎 Camera3D 一致。
func _check_projection(scene, field) -> void:
	var grid: Vector2 = field.deploy.grid
	for tile in [Vector2.ZERO, grid, Vector2(3.5, 20.0), Vector2(20.0, 4.0)]:
		var engine: Vector2 = field.camera.unproject_position(FieldProjection.tile_to_world(tile, grid))
		var ours: Vector2 = scene._t2s(tile)
		if ours.distance_to(engine) > 0.5:
			_failures.append("投影不一致 tile=%s ours=%s engine=%s" % [tile, ours, engine])


func _spawn_card(scene) -> int:
	var m = scene.get("match_obj")
	var field = scene.get("_field3d")
	var hand: Array = m.player.deck.get_hand()
	for i in hand.size():
		if hand[i] != null and m.player.can_play(i) and field.deploy.card_info(scene.get("loader"), str(hand[i]))["spawn"]:
			return i
	return -1


func _count_near(m, owner: int, tile: Vector2) -> int:
	var n := 0
	for unit in m.battle.arena.get_units():
		if unit.owner_id == owner and unit.pos.distance_to(tile) < 1.5:
			n += 1
	return n
