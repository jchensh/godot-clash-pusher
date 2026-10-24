## 无需点界面的 D1 预览冒烟：启动 → 中途翻转视角 → 4 倍速跑完整局 → 重开；节点数始终等于存活单位数。
extends SceneTree


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var scene: Node3D = load("res://view/labs/battle_3d_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var failures: Array[String] = []
	var presenter: Node3D = scene.get("_presenter")
	scene._set_paused(true)
	var frozen_tick: float = scene.get("_match").battle.elapsed
	scene._process(0.5)
	if scene.get("_match").battle.elapsed != frozen_tick or presenter.can_process():
		failures.append("暂停未冻结 sim 或 presenter 动画")
	scene._set_paused(false)
	var max_units := 0
	var steps := 0
	while not scene.get("_match").is_over() and steps < 2400:
		scene._process(0.1)
		steps += 1
		if steps == 600:
			scene.set("_flipped", true)
			scene._setup_presenter()
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
