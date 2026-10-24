## 无需点界面的 D1/D2 预览冒烟（真实场景树）：
## ①BattleCamera 纯数学投影/射线与 Camera3D 实机一致 ②手牌拖卡出兵（本方 + 翻转后 side2）
## ③暂停冻结 ④观战模式 4 倍速跑完整局、中途翻转，节点数始终 = 存活单位数 ⑤重开回到空场。
extends SceneTree

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const BattleCamera := preload("res://view/three_d/battle_camera.gd")


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var scene: Node3D = load("res://view/labs/battle_3d_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var failures: Array[String] = []
	var presenter: Node3D = scene.get("_presenter")
	var deploy: Node3D = scene.get("_deploy")
	var camera: Camera3D = scene.get("_camera")
	_check_camera_math(camera, deploy, failures)
	for i in 80:
		scene._process(0.1)   # 攒圣水
	_human_play(scene, deploy, Vector2(6.5, 24.5), 0, failures)
	scene.set("_flipped", true)
	scene._setup_view()
	_check_camera_math(camera, deploy, failures)
	for i in 40:
		scene._process(0.1)
	_human_play(scene, deploy, Vector2(19.5, 5.5), 1, failures)
	scene._set_paused(true)
	var frozen: float = scene.get("_match").battle.elapsed
	scene._process(0.5)
	if scene.get("_match").battle.elapsed != frozen or presenter.can_process():
		failures.append("暂停未冻结 sim 或 presenter 动画")
	scene._set_paused(false)
	scene.set("_watch", true)
	scene.set("_flipped", false)
	scene._restart()
	var max_units := 0
	var steps := 0
	while not scene.get("_match").is_over() and steps < 2400:
		scene._process(0.1)
		steps += 1
		if steps == 600:
			scene.set("_flipped", true)
			scene._setup_view()
		var alive: int = scene.get("_match").battle.arena.get_units().size()
		max_units = maxi(max_units, alive)
		if presenter.unit_actor_count() != alive:
			failures.append("第 %d 步节点数 %d ≠ 存活单位 %d" % [steps, presenter.unit_actor_count(), alive])
			break
	if not scene.get("_match").is_over():
		failures.append("对局未在预期内结束")
	if max_units < 3:
		failures.append("AI 对局几乎没有出兵（max=%d）" % max_units)
	if not str(scene.get("_status").text).contains("对局结束"):
		failures.append("结束后状态栏未显示结果")
	print("BATTLE_3D_PREVIEW: steps=%d max_units=%d result=%d" % [steps, max_units, scene.get("_match").get_result()])
	for i in 30:
		scene._process(0.1)
	if presenter.dying_count() != 0:
		failures.append("结束后仍有未释放的死亡节点")
	scene._restart()
	if presenter.unit_actor_count() != 0 or scene.get("_match").is_over():
		failures.append("重开后未回到空场新局")
	root.remove_child(scene)
	scene.free()
	for failure in failures:
		push_error(failure)
	print("BATTLE_3D_PREVIEW: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)


## 纯数学投影（单测依赖）必须与引擎 Camera3D 逐像素一致。
func _check_camera_math(camera: Camera3D, deploy, failures: Array[String]) -> void:
	var grid: Vector2 = deploy.grid
	var size: Vector2 = deploy.viewport_size
	for tile in [Vector2.ZERO, grid, Vector2(3.5, 20.0), Vector2(20.0, 4.0)]:
		var world := FieldProjection.tile_to_world(tile, grid, deploy.flipped)
		var ours: Vector2 = deploy.tile_to_screen(tile)
		var engine := camera.unproject_position(world)
		if ours.distance_to(engine) > 0.5:
			failures.append("投影不一致 tile=%s ours=%s engine=%s" % [tile, ours, engine])
		# 反投影比对用 project_position（unproject 的精确逆）：headless 窗口是 64×64 退化尺寸，
		# project_ray_* 会叠加失真的 stretch 变换；真实窗口 keep 等比拉伸下二者一致。
		var ray := BattleCamera.screen_ray(camera.global_transform, camera.size, size, engine)
		for depth in [1.0, 40.0]:
			var on_engine_ray := camera.project_position(engine, depth)
			var offset: Vector3 = on_engine_ray - (ray[0] as Vector3)
			var off_line: float = (offset - (ray[1] as Vector3) * offset.dot(ray[1])).length()
			if off_line > 0.01:
				failures.append("射线不一致 tile=%s depth=%.0f off_line=%.4f" % [tile, depth, off_line])


## 走手牌按钮同一入口：按下第 i 格 → 松手在 tile 上方抬手位置；应在 tile 附近出现该方新单位或法术生效。
func _human_play(scene, deploy, tile: Vector2, owner: int, failures: Array[String]) -> void:
	var who = scene._human()
	var index := -1
	for i in 4:
		var cid = who.deck.get_hand()[i]
		if cid != null and who.can_play(i) and deploy.card_info(scene.get("_loader"), str(cid))["spawn"]:
			index = i
			break
	if index < 0:
		failures.append("owner=%d 没有可出的兵牌" % owner)
		return
	var before: int = _count_near(scene, owner, tile)
	var elixir: int = who.elixir.get_int()
	var screen: Vector2 = deploy.tile_to_screen(tile) + Vector2(0.0, deploy.lift_pixels())
	scene._on_card_down(index)
	scene._on_card_up(index, screen)
	if who.elixir.get_int() >= elixir:
		failures.append("owner=%d 拖卡后未扣圣水" % owner)
	if _count_near(scene, owner, tile) <= before:
		failures.append("owner=%d 落点 %s 附近没有新单位" % [owner, tile])
	print("BATTLE_3D_PREVIEW: owner=%d 出兵 OK=%s" % [owner, _count_near(scene, owner, tile) > before])


func _count_near(scene, owner: int, tile: Vector2) -> int:
	var n := 0
	for unit in scene.get("_match").battle.arena.get_units():
		if unit.owner_id == owner and unit.pos.distance_to(tile) < 1.5:
			n += 1
	return n
