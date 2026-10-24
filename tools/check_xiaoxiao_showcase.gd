## 无需点界面的展示台冒烟：启动、动作切换、暂停续播、攻击结束回待机。
extends SceneTree


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var scene: Node3D = load("res://view/labs/xiaoxiao_showcase.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player: AnimationPlayer = scene.get("_player")
	var failures: Array[String] = []
	if player == null:
		failures.append("展示场景缺少动画播放器")
	else:
		if player.assigned_animation != &"Idle":
			failures.append("初始未播放待机")
		scene.play_clip("Walk")
		player.advance(0.3)
		if player.assigned_animation != &"Walk" or not player.is_playing():
			failures.append("行走未启动")
		scene._toggle_pause()
		if player.is_playing():
			failures.append("暂停无效")
		scene._toggle_pause()
		if not player.is_playing():
			failures.append("续播无效")
		scene._set_speed(0.5)
		if not is_equal_approx(player.speed_scale, 0.5):
			failures.append("播放速度设置无效")
		scene._set_speed(1.0)
		scene.play_clip("Attack")
		player.advance(player.get_animation("Attack").length + 0.2)
		if player.assigned_animation != &"Idle":
			failures.append("攻击结束未回待机")
	root.remove_child(scene)
	scene.free()
	for failure in failures:
		push_error(failure)
	print("XIAOXIAO_SHOWCASE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
