## D7：页面内 3D 预览——单模型预览台（每个可玩角色都能上台、动作循环、身高归一、换模型不叠实例、
## 不进全局常驻缓存、离台即释放）与菜单小场景（模型齐、独立小世界）。
extends "res://tests/test_case.gd"

const ModelStage := preload("res://view/three_d/model_stage.gd")
const MenuDiorama := preload("res://view/three_d/menu_diorama.gd")
const UnitModels := preload("res://view/three_d/unit_models.gd")


func _height(stage) -> float:
	var top := -INF
	var bottom := INF
	var m: Node3D = stage.model()
	for node in m.find_children("*", "MeshInstance3D", true, false):
		var b := (node as MeshInstance3D).get_aabb()
		top = maxf(top, b.end.y)
		bottom = minf(bottom, b.position.y)
	return (top - bottom) * m.scale.y


func test_model_stage_every_unit_and_actions() -> void:
	var stage = ModelStage.new()
	var cache_before: int = UnitModels._scenes.size()
	for uid in UnitModels.MODELS:
		assert_true(stage.show_unit(uid), "%s 可上台" % uid)
		assert_eq(stage.pivot.get_child_count(), 1, "%s 台上只有一个模型实例" % uid)
		assert_eq(stage.action, "Idle", "%s 上台先播待机" % uid)
		var h: float = _height(stage)
		assert_true(h <= ModelStage.FIT_HEIGHT + 0.01 and h > 0.3, "%s 身高归一（%.2f）" % [uid, h])
	stage.show_unit("archer_body")
	stage.cycle_action()
	assert_eq(stage.action, "Walk", "点一下 → 走")
	stage.cycle_action()
	assert_eq(stage.action, "Attack", "再点 → 攻击")
	stage.cycle_action()
	assert_eq(stage.action, "Idle", "再点 → 回待机")
	# 借用/派生单位也能上台（解析到池内模型）。
	assert_true(stage.show_unit("bat_body") and stage.show_unit("phoenix_reborn_body"), "借用/派生单位可上台")
	assert_eq(UnitModels._scenes.size(), cache_before, "预览按需 load，不进全局常驻缓存")
	var held: Node3D = stage.model()
	assert_false(stage.show_unit("no_such_unit"), "无模型（法术卡）返回 false")
	assert_false(is_instance_valid(held), "换台时旧模型立即释放")
	assert_false(stage.has_model(), "无模型时台上为空")
	stage.free()


func test_menu_diorama_builds_own_world() -> void:
	var dio = MenuDiorama.new()
	dio.build(false)
	assert_true(dio.viewport.own_world_3d, "小场景是独立世界（不与页面其他 3D 混）")
	assert_eq(dio.model_count(), MenuDiorama.PROPS.size() + MenuDiorama.UNITS.size(), "王城/箭塔/树丛/角色齐")
	assert_eq(dio.mouse_filter, Control.MOUSE_FILTER_IGNORE, "小场景不吃点击（主视觉按钮照常可点）")
	dio.free()
