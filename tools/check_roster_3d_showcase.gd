## D3 角色图鉴冒烟：遍历全部登记模型与塔，逐个播放四段动作、切塔阵营色，确认无报错且动作真实存在。
extends SceneTree


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var scene: Node3D = load("res://view/labs/roster_3d_showcase.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var failures: Array[String] = []
	var items: Array = scene.get("_items")
	for i in items.size():
		scene.show_item(i)
		await process_frame
		var player: AnimationPlayer = scene.get("_player")
		var item: Dictionary = items[i]
		if item.kind == "unit":
			if player == null:
				failures.append("%s 无 AnimationPlayer" % item.asset)
				continue
			for clip in ["Idle", "Walk", "Attack", "Death"]:
				if not player.has_animation(clip):
					failures.append("%s 缺 %s" % [item.asset, clip])
					continue
				scene.play_clip(clip)
				player.advance(0.2)
				if player.current_animation != clip:
					failures.append("%s 未播放 %s" % [item.asset, clip])
		else:
			scene.set("_blue", false)
			scene.show_item(i)
			scene.set("_blue", true)
	print("ROSTER_3D: items=%d" % items.size())
	root.remove_child(scene)
	scene.free()
	for failure in failures:
		push_error(failure)
	print("ROSTER_3D: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
