## D3 资产契约：每个登记的 3D 单位/塔模型都要有规定动作与循环设置、蒙皮、顶点色，并守住三角面/骨骼预算。
## 预算直接读 GLB（glTF JSON），不依赖 headless 渲染器是否保留网格数据。
extends "res://tests/test_case.gd"

const UnitModels := preload("res://view/three_d/unit_models.gd")
const ToonStyle := preload("res://view/three_d/toon_style.gd")

const TOWERS := ["king_tower", "arrow_tower", "tower_ruin"]
const TEAM_TOWERS := ["king_tower", "arrow_tower"]
const MAX_TRIS := 5000
const MAX_TRIS_BIG := 8000
const MAX_TRIS_TOWER := 6000
const MAX_BONES := 20
## 大型单位（D3 预算口径）：允许 8k 三角面。
const BIG := ["royal_giant", "golem", "lava_hound", "balloon", "giant", "baby_dragon"]


func test_every_unit_model_has_clips_loops_skin_and_budget() -> void:
	assert_eq(UnitModels.assets().size(), 25, "可玩池 21 + 热门锁定 4 = 25 个单位模型")
	for asset in UnitModels.assets():
		var path: String = UnitModels.glb_path(asset)
		var info := _glb_info(path)
		var limit := MAX_TRIS_BIG if BIG.has(asset) else MAX_TRIS
		assert_true(info.tris > 0 and info.tris <= limit, "%s 三角面 %d ≤ %d" % [asset, info.tris, limit])
		assert_true(info.bones > 0 and info.bones <= MAX_BONES, "%s 骨骼 %d ≤ %d" % [asset, info.bones, MAX_BONES])
		assert_true(info.has_color, "%s 带顶点色 COLOR_0（toon 底色）" % asset)
		var model: Node = (load(path) as PackedScene).instantiate()
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_not_null(player, "%s 有 AnimationPlayer" % asset)
		if player != null:
			var expected := {"Idle": true, "Walk": true, "Attack": false, "Death": false}
			for clip in expected:
				assert_true(player.has_animation(clip), "%s 有 %s" % [asset, clip])
				if player.has_animation(clip):
					var loops: bool = player.get_animation(clip).loop_mode != Animation.LOOP_NONE
					assert_eq(loops, expected[clip], "%s/%s 循环设置" % [asset, clip])
			if player.has_animation("Death"):
				assert_true(player.get_animation("Death").length <= 0.65, "%s 死亡片段 ≤ 0.65 秒（presenter 0.6 秒内播完）" % asset)
		assert_not_null(model.find_child("Skeleton3D", true, false), "%s 有骨架" % asset)
		model.free()


func test_towers_have_budget_and_team_surface() -> void:
	for asset in TOWERS:
		var path := "res://assets/models/%s/%s.glb" % [asset, asset]
		var info := _glb_info(path)
		assert_true(info.tris > 0 and info.tris <= MAX_TRIS_TOWER, "%s 三角面 %d ≤ %d" % [asset, info.tris, MAX_TRIS_TOWER])
		assert_eq(info.materials.has("M_Team"), TEAM_TOWERS.has(asset), "%s 阵营色材质槽" % asset)
		var model: Node = (load(path) as PackedScene).instantiate()
		var replaced := ToonStyle.apply(model, Color.RED)
		assert_true(replaced >= 1, "%s 全部换成 toon 材质" % asset)
		model.free()


func test_registry_resolves_borrowed_and_derived_units() -> void:
	assert_true(UnitModels.has_model("princess_body"))
	assert_true(UnitModels.has_model("phoenix_reborn_body"), "派生形态复用父模型")
	for unit_id in UnitModels.BORROW:
		assert_true(UnitModels.has_model(unit_id), "借用单位 %s 能解析到池内模型" % unit_id)
	assert_false(UnitModels.has_model("no_such_body"), "未登记单位走代理")
	assert_almost_eq(UnitModels.target_height(50.0, 0.5), 2.0, 0.0001, "身高 = vis_height_px / 25")


## 解析 GLB：三角面（索引数/3）、首个蒙皮骨骼数、是否带 COLOR_0、材质名。
func _glb_info(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	var json_len := bytes.decode_u32(12)
	var doc: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_len).get_string_from_utf8())
	var tris := 0
	var has_color := false
	for mesh in doc.get("meshes", []):
		for prim in mesh.get("primitives", []):
			if prim.has("indices"):
				tris += int(doc.accessors[int(prim.indices)].count) / 3
			has_color = has_color or (prim.get("attributes", {}) as Dictionary).has("COLOR_0")
	var bones := 0
	if not doc.get("skins", []).is_empty():
		bones = (doc.skins[0].joints as Array).size()
	var materials: Array = []
	for mat in doc.get("materials", []):
		materials.append(str(mat.get("name", "")))
	return {"tris": tris, "bones": bones, "has_color": has_color, "materials": materials}


## D3 验收口径：units.json 里的每一个单位都要解析到 3D 模型（正式/派生/借用），不再出现几何代理。
func test_every_configured_unit_has_a_model() -> void:
	var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/units.json"))
	var missing: Array = []
	for unit_id in units:
		if not UnitModels.has_model(unit_id):
			missing.append(unit_id)
	assert_eq(missing, [], "所有配置单位都有 3D 模型")
	for unit_id in UnitModels.BORROW:
		var model: Dictionary = UnitModels.model_for(unit_id)
		assert_ne(model["tint"], Color.WHITE, "借用单位 %s 带色偏，与被借角色区分" % unit_id)


func test_terrain_assets_exist_and_are_static() -> void:
	for asset in ["bridge", "prop_tree", "prop_bush", "prop_rock", "prop_fence"]:
		var info := _glb_info("res://assets/models/%s/%s.glb" % [asset, asset])
		assert_true(info.tris > 0 and info.tris <= MAX_TRIS_TOWER, "%s 三角面 %d" % [asset, info.tris])
		assert_eq(info.bones, 0, "%s 静态无骨架" % asset)
		assert_true(info.has_color, "%s 带顶点色" % asset)


## 满场性能预算（移动端口径）：30 个最重单位 + 6 塔 + 地形与点缀（实例数取自真实构建的场地）≤ 26 万三角面。
func test_full_field_triangle_budget() -> void:
	var ArenaPresenter := load("res://view/three_d/arena_presenter.gd")
	var Loader := load("res://logic/config_loader.gd")
	var loader = Loader.new()
	loader.load_all()
	var field: Node3D = ArenaPresenter.new()
	field.build(loader.get_arena("default"), false)
	var heaviest := 0
	for asset in UnitModels.assets():
		heaviest = maxi(heaviest, _glb_info(UnitModels.glb_path(asset)).tris)
	var total := heaviest * 30
	total += _glb_info("res://assets/models/king_tower/king_tower.glb").tris * 2
	total += _glb_info("res://assets/models/arrow_tower/arrow_tower.glb").tris * 4
	total += _glb_info("res://assets/models/bridge/bridge.glb").tris * field.bridge_count
	var decor := {"Fence": "prop_fence", "Decor_tree": "prop_tree", "Decor_bush": "prop_bush", "Decor_rock": "prop_rock"}
	for node in field.find_children("*", "MultiMeshInstance3D", true, false):
		var asset: String = decor[node.name]
		total += _glb_info("res://assets/models/%s/%s.glb" % [asset, asset]).tris * (node as MultiMeshInstance3D).multimesh.instance_count
	print("  [3D 预算] 满场最坏 %d 三角面（最重单位 %d × 30）" % [total, heaviest])
	assert_true(total <= 260000, "满场最坏三角面 %d ≤ 260000" % total)
	field.free()
