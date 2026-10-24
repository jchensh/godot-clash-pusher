## D6：王国 3D——镜头纯数学（平移跟手/以指点为中心缩放/焦点钳在城内）、建筑模型资产（静态/顶点色/面数预算）、
## 场景布局（建筑正面底边贴槽位、占地互不重叠）、点选（每栋都点得中、前排优先、空地/角楼副本）、形态切换。
extends "res://tests/test_case.gd"

const KingdomCamera := preload("res://view/three_d/kingdom_camera.gd")
const KingdomPresenter := preload("res://view/three_d/kingdom_presenter.gd")
const KingdomPage := preload("res://view/kingdom.gd")

const SCREEN := Vector2(750, 1334)
const BOUNDS := Rect2(-15.0, -17.0, 30.0, 34.0)
const TRI_BUDGET := 6000


func _layout() -> Dictionary:
	return {
		"slots": KingdomPage.SLOTS, "deco": KingdomPage.DECO_ITEMS, "roads": KingdomPage.build_roads(),
		"watchtower_extras": KingdomPage.WT_EXTRAS,
		"walls": {"top": KingdomPage.WALL_TOP_Y, "bottom": KingdomPage.WALL_BOT_Y, "left": KingdomPage.WALL_LEFT_X,
			"right": KingdomPage.WALL_RIGHT_X, "gate_x": float(KingdomPage.SLOTS["wall"]["pos"].x),
			"gate_gap": KingdomPage.GATE_GAP},
		"walkers": [], "unit_heights": {},
	}


func _world():
	var w = KingdomPresenter.new()
	w.setup(_layout(), SCREEN, false)
	return w


func test_camera_pan_follows_finger_and_clamps() -> void:
	var t := Vector3(1.0, 0.0, 2.0)
	var size := KingdomCamera.SIZE_DEFAULT
	var finger := Vector2(300, 700)
	var ground := KingdomCamera.screen_to_ground(t, size, SCREEN, finger)
	assert_true(absf(ground.y) < 0.001, "拾取点在地面")
	var back := KingdomCamera.world_to_screen(t, size, SCREEN, ground)
	assert_true(back.distance_to(finger) < 0.01, "屏幕↔地面往返")
	var moved := KingdomCamera.pan(t, size, SCREEN, Vector2(40, -25), Rect2(-100, -100, 200, 200))
	var under := KingdomCamera.world_to_screen(moved, size, SCREEN, ground)
	assert_true(under.distance_to(finger + Vector2(40, -25)) < 0.01, "拖动后原地面点跟着手指走")
	var far := KingdomCamera.pan(t, size, SCREEN, Vector2(-100000, 100000), BOUNDS)
	assert_true(BOUNDS.grow(0.001).has_point(Vector2(far.x, far.z)), "焦点钳在城内")
	# 放到最大后拖到极限：画面四角最多露出墙外 EDGE_MARGIN 米（视野小于整城的方向才可拖）。
	var near := KingdomCamera.SIZE_MIN
	var corner_t := KingdomCamera.pan(t, near, SCREEN, Vector2(-100000, 100000), BOUNDS)
	var limit := BOUNDS.grow(KingdomCamera.EDGE_MARGIN + 0.01)
	for corner in [Vector2.ZERO, Vector2(SCREEN.x, 0), Vector2(0, SCREEN.y), SCREEN]:
		var g := KingdomCamera.screen_to_ground(corner_t, near, SCREEN, corner)
		assert_true(limit.has_point(Vector2(g.x, g.z)), "拖到边角时画面不露出大片城外（%s）" % corner)
	# 屏幕上方 = 城北（-Z）。
	var north := KingdomCamera.screen_to_ground(t, size, SCREEN, Vector2(375, 100))
	var south := KingdomCamera.screen_to_ground(t, size, SCREEN, Vector2(375, 1200))
	assert_true(north.z < south.z, "屏幕上方是城北")


func test_camera_zoom_keeps_anchor_and_limits() -> void:
	var t := Vector3.ZERO
	var at := Vector2(520, 400)
	var ground := KingdomCamera.screen_to_ground(t, KingdomCamera.SIZE_DEFAULT, SCREEN, at)
	var r: Array = KingdomCamera.zoom_at(t, KingdomCamera.SIZE_DEFAULT, SCREEN, at, 0.7, Rect2(-100, -100, 200, 200))
	assert_true(float(r[1]) < KingdomCamera.SIZE_DEFAULT, "放大视野变小")
	assert_true(KingdomCamera.world_to_screen(r[0], r[1], SCREEN, ground).distance_to(at) < 0.01, "缩放以指点为中心")
	assert_eq(float(KingdomCamera.zoom_at(t, 30.0, SCREEN, at, 0.01, BOUNDS)[1]), KingdomCamera.SIZE_MIN, "放大有下限")
	assert_eq(float(KingdomCamera.zoom_at(t, 30.0, SCREEN, at, 100.0, BOUNDS)[1]), KingdomCamera.SIZE_MAX, "缩小有上限")


## 建筑/空地/城墙/点缀模型：存在、静态（无骨架无动画）、单材质顶点色、三角面不超预算。
func test_kingdom_model_assets() -> void:
	var assets: Array = KingdomPresenter.BUILDING_ASSETS.values()
	for spec in KingdomPresenter.DECO_ASSETS.values():
		assets.append(spec[0])
	assets.append_array([KingdomPresenter.PLOT_ASSET, KingdomPresenter.WALL_ASSET, KingdomPresenter.WALL_POST_ASSET])
	for asset in assets:
		if asset == "arrow_tower" or str(asset).begins_with("prop_"):
			continue   # 战斗资产复用，D3 测试已覆盖
		var path := "res://assets/models/%s/%s.glb" % [asset, asset]
		var scene: PackedScene = load(path)
		assert_true(scene != null, "%s 可加载" % path)
		if scene == null:
			continue
		var inst: Node = scene.instantiate()
		assert_true(inst.find_children("*", "Skeleton3D", true, false).is_empty(), "%s 静态无骨架" % asset)
		assert_true(inst.find_children("*", "AnimationPlayer", true, false).is_empty(), "%s 无动画" % asset)
		var tris := 0
		var colored := true
		for node in inst.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(s)
				colored = colored and arrays[Mesh.ARRAY_COLOR] != null
				var idx = arrays[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		assert_true(colored, "%s 带顶点色" % asset)
		assert_true(tris > 0 and tris <= TRI_BUDGET, "%s 三角面 %d ≤ %d" % [asset, tris, TRI_BUDGET])
		inst.free()


func test_layout_fronts_on_slots_and_no_overlap() -> void:
	var w = _world()
	var boxes := {}
	for b in KingdomPage.SLOTS:
		w.set_slot_state(b, 1, false)
		var box: AABB = w._slots[b]["model_box"]
		var front: Vector3 = KingdomPresenter.to_world(KingdomPage.SLOTS[b]["pos"])
		assert_true(absf(box.end.z - front.z) < 0.01, "%s 正面贴槽位底边" % b)
		assert_true(absf(box.get_center().x - front.x) < 0.01, "%s 左右居中于槽位" % b)
		var width := float(KingdomPage.SLOTS[b]["w"]) / KingdomPresenter.PX_PER_M
		assert_true(absf(box.size.x - width) < 0.01, "%s 宽度按槽位" % b)
		boxes[b] = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	var keys := boxes.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = boxes[keys[i]]
			var c: Rect2 = boxes[keys[j]]
			assert_false(a.grow(-0.15).intersects(c.grow(-0.15)), "%s 与 %s 占地重叠" % [keys[i], keys[j]])
	w.free()


func test_pick_every_building_front_first_and_states() -> void:
	var w = _world()
	for b in KingdomPage.SLOTS:
		w.set_slot_state(b, 1, false)
	for b in KingdomPage.SLOTS:
		w.look_at_px(KingdomPage.SLOTS[b]["pos"])   # 镜头对准该栋（拖到哪点哪）
		var plates := {}
		for o in KingdomPage.SLOTS:   # 与页面同口径的名牌框（字宽按 6 个字估）
			plates[o] = KingdomPage.plate_rect(w.base_screen(o) + Vector2(0, 4), 96.0, 16)
		var p: Vector2 = w.base_screen(b) + Vector2(0, -6)
		assert_eq(w.pick(p, plates), b, "点 %s 正面（门口）应选中它" % b)
		assert_eq(w.pick(w.base_screen(b) + Vector2(0, 16), plates), b, "点 %s 名牌应选中它" % b)
	# 空地：未建也点得中（点空地 = 建造入口）；切换后包围框变成空地大小。
	w.set_slot_state("workshop", 0, false)
	w.look_at_px(KingdomPage.SLOTS["workshop"]["pos"])
	assert_eq(w.pick(w.base_screen("workshop") + Vector2(0, -6)), "workshop", "空地可点")
	assert_true(w._slots["workshop"]["plot"].visible and not w._slots["workshop"]["model"].visible, "未建 = 空地")
	# 施工中 = 建筑 + 脚手架；角楼副本仅建成后现身且可点 = 箭塔。
	w.set_slot_state("watchtower", 1, true)
	assert_true(w._slots["watchtower"]["scaffold"].visible, "施工中显示脚手架")
	var extra: Vector2 = KingdomPage.WT_EXTRAS[0]
	w.look_at_px(extra)
	var ep := w.world_to_screen(KingdomPresenter.to_world(extra)) + Vector2(0, -6)
	assert_eq(w.pick(ep), "watchtower", "右下角楼副本可点 = 箭塔")
	w.set_slot_state("watchtower", 0, false)
	assert_false(w._slots["watchtower"]["extras"][0].visible, "箭塔未建时角楼副本隐藏")
	assert_true(w.pick(ep) != "watchtower", "未建时副本不可点")
	# 空白地面不选中任何建筑。
	w.look_at_px(Vector2(705, 1100))
	assert_eq(w.pick(w.world_to_screen(KingdomPresenter.to_world(Vector2(705, 1110)))), "", "主路上空白处不选中")
	w.free()


## 居民寻路：16 个门口都可达、互通；路径与巡游全程不进入任何建筑/点缀占地；长路线以走路面为主。
func test_walkers_path_around_buildings() -> void:
	var layout := _layout()
	layout["walkers"] = ["goblin_body", "archer_body", "barbarian_body"]
	var w = KingdomPresenter.new()
	w.setup(layout, SCREEN, false)
	var nav = w.nav
	assert_eq(nav.doors.size(), KingdomPage.SLOTS.size(), "每栋建筑门口都有可走的落脚点")
	var feet: Array = w.footprints()
	for i in nav.doors.size():
		var p: PackedVector2Array = nav.path(nav.doors[0], nav.doors[i])
		assert_true(p.size() >= 1, "门口 0 → %d 可达" % i)
		for k in range(1, p.size()):
			for t in 10:
				var q: Vector2 = p[k - 1].lerp(p[k], t / 10.0)
				assert_false(_inside(q, feet), "路径 0→%d 穿过建筑占地 %s" % [i, q])
	# 长路线（左上采石场 → 右下药剂坊）大部分走在路面上。
	var a: Vector2 = nav.doors[KingdomPage.SLOTS.keys().find("quarry")]
	var b: Vector2 = nav.doors[KingdomPage.SLOTS.keys().find("mint")]
	var route: PackedVector2Array = nav.path(a, b)
	var on_road := 0.0
	var total := 0.0
	for k in range(1, route.size()):
		var seg: float = route[k - 1].distance_to(route[k])
		total += seg
		if _inside(route[k - 1].lerp(route[k], 0.5), w._road_rects):
			on_road += seg
	assert_true(total > 10.0 and on_road / total > 0.6, "长路线以路面为主（%.0f%% / %.1f 米）" % [on_road / maxf(total, 0.01) * 100.0, total])
	# 巡游 90 秒：居民始终不在任何占地里。
	for f in 900:
		w.advance(0.1)
		for pos in w.walker_positions():
			if _inside(pos, feet):
				assert_true(false, "第 %d 帧居民走进了建筑 %s" % [f, pos])
				w.free()
				return
	w.free()


static func _inside(p: Vector2, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false
