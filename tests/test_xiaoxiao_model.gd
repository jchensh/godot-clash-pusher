## 导入契约：动画、蒙皮和动作驱动的骨骼姿态都必须真实存在。
extends "res://tests/test_case.gd"

const MODEL := preload("res://assets/models/xiaoxiao/xiaoxiao_animated.glb")


func test_imported_clips_and_loop_modes() -> void:
	var model := MODEL.instantiate()
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(player, "导入 AnimationPlayer")
	if player != null:
		for clip in ["Idle", "Walk", "Attack"]:
			assert_true(player.has_animation(clip), "具备 %s 动画" % clip)
			if player.has_animation(clip):
				var animation := player.get_animation(clip)
				assert_true(animation.get_track_count() > 0, "动画含轨道")
				assert_true(animation.length > 1.0, "完整动作时长")
				var expected := Animation.LOOP_NONE if clip == "Attack" else Animation.LOOP_LINEAR
				assert_eq(animation.loop_mode, expected, "循环设置正确")
	model.free()


func test_imported_skeleton_and_skin() -> void:
	var model := MODEL.instantiate()
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skeleton, "导入 Skeleton3D")
	if skeleton != null:
		assert_eq(skeleton.get_bone_count(), 14, "14 根变形骨骼（静态 root 不导出）")
		var mesh := skeleton.find_child("SK_Xiaoxiao", true, false) as MeshInstance3D
		assert_not_null(mesh, "蒙皮模型存在")
		if mesh != null:
			assert_not_null(mesh.skin, "模型有蒙皮绑定")
	model.free()


func test_animation_actually_moves_bones_and_closes_walk_loop() -> void:
	var model := MODEL.instantiate()
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(player)
	assert_not_null(skeleton)
	if player != null and skeleton != null:
		var leg := skeleton.find_bone("leg_L")
		if leg < 0:
			leg = skeleton.find_bone("leg.L")
		assert_true(leg >= 0, "左腿骨骼存在")
		if leg >= 0:
			player.play("Walk")
			player.seek(0.0, true)
			var start := skeleton.get_bone_pose_rotation(leg)
			player.seek(0.3, true)
			assert_true(start.angle_to(skeleton.get_bone_pose_rotation(leg)) > 0.1, "行走确实驱动骨骼")
			player.seek(player.get_animation("Walk").length - 0.001, true)
			assert_true(start.angle_to(skeleton.get_bone_pose_rotation(leg)) < 0.03, "首尾姿态闭合")
	root.remove_child(model)
	model.free()
