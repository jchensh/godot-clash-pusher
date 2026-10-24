## D6 王国 3D 场景：地面 / 路网 / 城墙 / 点缀 / 16 个建筑槽 / 巡游居民 + 正交斜视镜头与点选。
## 布局沿用王国页槽位表（BG 像素系，PX_PER_M 像素 = 1 米；槽位 pos = 建筑正面底边中心）。
## 只做表现：等级 / 施工 / 待收由页面按服务器缓存喂进来（set_slot_state），本节点不读写经济与养成数据；
## 居民巡游是纯表现随机量。
extends Node3D

const KingdomCamera := preload("res://view/three_d/kingdom_camera.gd")
const ToonStyle := preload("res://view/three_d/toon_style.gd")
const UnitModels := preload("res://view/three_d/unit_models.gd")
const BattleLighting := preload("res://view/three_d/battle_lighting.gd")
const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")
const KingdomNav := preload("res://view/three_d/kingdom_nav.gd")
const GROUND_SHADER := preload("res://view/three_d/ground.gdshader")
const TOON_SHADER := preload("res://view/three_d/toon.gdshader")

const PX_PER_M := 40.0
const BG_SIZE := Vector2(1440.0, 1830.0)

## 建筑槽 → 模型资产（assets/models/<id>/<id>.glb）。箭塔复用战斗箭塔（屋顶按本方蓝染色）。
const BUILDING_ASSETS := {
	"keep": "k_keep", "farm": "k_farm", "workshop": "k_magic_lab", "watchtower": "arrow_tower",
	"granary": "k_granary", "mint": "k_mint", "wall": "k_gate", "quarry": "k_quarry",
	"stoneworks": "k_observatory", "ironworks": "k_ironworks", "ranch": "k_ranch", "shop": "k_shop",
	"camp_infantry": "k_camp_mage", "camp_spear": "k_camp_spear", "camp_crossbow": "k_camp_crossbow",
	"camp_cavalry": "k_camp_cavalry",
}
## 点缀种类 → [资产, 目标宽度（米）]。
const DECO_ASSETS := {
	"tree1": ["prop_tree", 2.0], "tree2": ["prop_tree", 1.7], "tree3": ["prop_tree", 1.5],
	"flower1": ["k_flower", 0.5], "flower2": ["k_flower", 0.45], "bamboo": ["k_bamboo", 0.8],
	"barrel": ["k_barrel", 0.75], "pumpkin": ["k_pumpkin_house", 3.6],
}
const PLOT_ASSET := "k_plot"
const WALL_ASSET := "k_wall"
const WALL_POST_ASSET := "k_wall_post"
const WALL_SEG_M := 4.0          # k_wall 一段的原生长度
const PLOT_WIDTH_M := 3.5
const ROAD_COLOR := Color("cdb07a")
# 王国调色（2026-10-25 用户反馈「太艳太亮、饱和度爆炸」）：材质级降饱和/亮度（toon/ground shader 的 grade 参数；
# Compatibility 渲染器不支持环境后期调色）+ 柔和草地。只作用于王国页，战斗场景沿用已验收的颜色不动。
const GRADE := Vector2(0.72, 0.8)   # (饱和度, 亮度)
const LIGHT_SCALE := 0.8             # 王国自己那份太阳/环境光整体压暗（共用光照脚本不改，战斗不受影响）
const GRASS_A := Color("8db473")
const GRASS_B := Color("87ae6d")
const WOOD := Color("b27b45")
const WOOD_D := Color("7d5230")
const WALKER_SCALE := 0.9        # 居民身高 = 战斗身高 × 此值（与建筑比例相称，缩到最远仍看得见）
const PICK_PAD_M := 0.08         # 点选轮廓外扩（米），手指稍偏也算点中

var camera: Camera3D
var target := Vector3.ZERO
var size := KingdomCamera.SIZE_DEFAULT
var viewport_size := Vector2(750.0, 1334.0)
var bounds := Rect2()

var _slots: Dictionary = {}      # building → {root, model, plot, scaffold, pos, model_box, plot_box, level, extras}
var _walkers: Array = []         # [{node, player, pos(地面 x,z), path, idx, speed(米/秒)}]
var nav = KingdomNav.new()       # 居民寻路网格（绕开建筑、优先走路）
var _road_rects: Array = []      # 路面（地面 x,z）
var _deco_boxes: Array = []      # 点缀占地（地面 AABB）
var _dims: Dictionary = {}       # 资产 → 原生包围盒 AABB
var _hulls: Dictionary = {}      # 资产 → 原生「视平面」凸包轮廓（点选用，见 _view_point）
var _scenes: Dictionary = {}


## layout：{slots:{b:{pos,w}}, deco:[[kind,pos]], roads:[Rect2], walls:{top,bottom,left,right,gate_x,gate_gap},
##          watchtower_extras:[Vector2], walkers:[unit_id], unit_heights:{unit_id: vis_height_px}}（全部 BG 像素）。
func setup(layout: Dictionary, viewport: Vector2, lighting := true) -> void:
	viewport_size = viewport
	if lighting:
		BattleLighting.setup(self)
		(get_node("Sun") as DirectionalLight3D).light_energy *= LIGHT_SCALE
		(get_node("BattleEnvironment") as WorldEnvironment).environment.ambient_light_energy *= LIGHT_SCALE
	camera = Camera3D.new()
	camera.name = "KingdomCamera"
	add_child(camera)
	if camera.is_inside_tree():
		camera.make_current()
	var walls: Dictionary = layout.get("walls", {})
	var lo := to_world(Vector2(float(walls.get("left", 0.0)), float(walls.get("top", 0.0))))
	var hi := to_world(Vector2(float(walls.get("right", BG_SIZE.x)), float(walls.get("bottom", BG_SIZE.y))))
	bounds = Rect2(Vector2(lo.x, lo.z), Vector2(hi.x - lo.x, hi.z - lo.z))
	_build_ground()
	for r in layout.get("roads", []):
		_build_road(r as Rect2)
	_build_walls(walls)
	for item in layout.get("deco", []):
		_build_deco(str(item[0]), item[1] as Vector2)
	var slots: Dictionary = layout.get("slots", {})
	for b in slots:
		_build_slot(str(b), slots[b] as Dictionary, layout.get("watchtower_extras", []) if b == "watchtower" else [])
	_build_nav()
	_spawn_walkers(layout.get("walkers", []), layout.get("unit_heights", {}))
	look_at_px(slots.get("keep", {}).get("pos", BG_SIZE * 0.5) as Vector2)


# ---------- 坐标 / 镜头 ----------
static func to_world(px: Vector2) -> Vector3:
	return Vector3((px.x - BG_SIZE.x * 0.5) / PX_PER_M, 0.0, (px.y - BG_SIZE.y * 0.5) / PX_PER_M)


func look_at_px(px: Vector2) -> void:
	target = KingdomCamera.clamp_target(to_world(px), bounds, size, viewport_size)
	_apply_camera()


func pan_by(delta: Vector2) -> void:
	target = KingdomCamera.pan(target, size, viewport_size, delta, bounds)
	_apply_camera()


func zoom_at(at: Vector2, factor: float) -> void:
	var r: Array = KingdomCamera.zoom_at(target, size, viewport_size, at, factor, bounds)
	target = r[0]
	size = r[1]
	_apply_camera()


func world_to_screen(world: Vector3) -> Vector2:
	return KingdomCamera.world_to_screen(target, size, viewport_size, world)


func _apply_camera() -> void:
	KingdomCamera.apply(camera, target, size)


# ---------- 建筑槽状态 / 锚点 / 点选 ----------
## level<=0 = 空地；building_now = 施工中（建筑外罩脚手架）。
func set_slot_state(building: String, level: int, building_now: bool) -> void:
	var s: Dictionary = _slots.get(building, {})
	if s.is_empty():
		return
	s["level"] = level
	(s["model"] as Node3D).visible = level > 0
	(s["plot"] as Node3D).visible = level <= 0
	(s["scaffold"] as Node3D).visible = level > 0 and building_now
	for extra in s["extras"]:
		(extra as Node3D).visible = level > 0


func slot_level(building: String) -> int:
	return int(_slots.get(building, {}).get("level", 0))


func slot_ids() -> Array:
	return _slots.keys()


## 正面底边中心（名牌锚点）。
func base_screen(building: String) -> Vector2:
	return world_to_screen(to_world(_slots[building]["pos"] as Vector2))


## 当前可见形态（建筑或空地）的屏幕包围框。
func screen_rect(building: String) -> Rect2:
	var s: Dictionary = _slots[building]
	return _project_box(s["model_box"] if int(s["level"]) > 0 else s["plot_box"])


## 点选：①先看名牌（plates：building → 名牌屏幕矩形，由页面按实际绘制传入；名牌恒画在最上层，点它就是选它）；
## ②再看建筑轮廓：视平面凸包（尖顶两侧的空角不算），重叠取最靠前（离镜头近）的一栋。箭塔角楼副本也算箭塔。
func pick(screen: Vector2, plates: Dictionary = {}) -> String:
	var best := ""
	var best_z := -INF
	for b in plates:
		var front: float = _front_z(b)
		if (plates[b] as Rect2).has_point(screen) and front > best_z:
			best = b
			best_z = front
	if best != "":
		return best
	var v := _view_point(screen)
	for b in _slots:
		var s: Dictionary = _slots[b]
		var hulls: Array = [s["model_hull"] if int(s["level"]) > 0 else s["plot_hull"]]
		if int(s["level"]) > 0:
			hulls.append_array(s["extra_hulls"])
		var front: float = _front_z(b)
		for hull in hulls:
			if Geometry2D.is_point_in_polygon(v, hull) and front > best_z:
				best = b
				best_z = front
	return best


## 视平面坐标：正交斜视下同一视线上的点 (x, z·sinθ − y·cosθ) 恒等（θ=俯角），故模型轮廓可预算成 2D 凸包，
## 屏幕点经地面交点换算后直接做点在多边形内判断。
func _view_point(screen: Vector2) -> Vector2:
	var g := KingdomCamera.screen_to_ground(target, size, viewport_size, screen)
	return Vector2(g.x, g.z * sin(deg_to_rad(KingdomCamera.PITCH_DEG)))


func _view_hull(node: Node3D) -> PackedVector2Array:
	var local: PackedVector2Array = _hull_local(str(node.get_meta("asset")))
	var k := node.scale.x
	var off := Vector2(node.position.x, node.position.z * sin(deg_to_rad(KingdomCamera.PITCH_DEG)))
	var out := PackedVector2Array()
	for pt in local:
		out.append(pt * k + off)
	return out


func _hull_local(asset: String) -> PackedVector2Array:
	if _hulls.has(asset):
		return _hulls[asset]
	var sp := sin(deg_to_rad(KingdomCamera.PITCH_DEG))
	var cp := cos(deg_to_rad(KingdomCamera.PITCH_DEG))
	var pts := PackedVector2Array()
	var inst: Node3D = _scene(asset).instantiate()
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var w := mi.transform * (v as Vector3)
				pts.append(Vector2(w.x, w.z * sp - w.y * cp))
	inst.free()
	var hull := Geometry2D.convex_hull(pts)
	var grown: Array = Geometry2D.offset_polygon(hull, PICK_PAD_M)
	_hulls[asset] = grown[0] if not grown.is_empty() else hull
	return _hulls[asset]


func _front_z(building: String) -> float:
	return to_world(_slots[building]["pos"] as Vector2).z


func _project_box(box: AABB) -> Rect2:
	var rect := Rect2(world_to_screen(box.position), Vector2.ZERO)
	for i in 8:
		rect = rect.expand(world_to_screen(box.get_endpoint(i)))
	return rect


# ---------- 每帧：居民巡游（纯表现；沿寻路网格的路径走，到站换下一个门口）----------
func advance(delta: float) -> void:
	for w in _walkers:
		var path: PackedVector2Array = w["path"]
		var i: int = w["idx"]
		if i >= path.size():
			_new_route(w)
			continue
		var pos: Vector2 = w["pos"]
		var d: Vector2 = path[i] - pos
		var stride := float(w["speed"]) * delta
		if d.length() <= stride:
			w["pos"] = path[i]
			w["idx"] = i + 1
		else:
			w["pos"] = pos + d.normalized() * stride
		var node: Node3D = w["node"]
		var p: Vector2 = w["pos"]
		node.position = Vector3(p.x, 0.0, p.y)
		if d.length() > 0.001:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(d.x, d.y), minf(1.0, delta * 10.0))


func walker_count() -> int:
	return _walkers.size()


func walker_positions() -> Array:
	var out: Array = []
	for w in _walkers:
		out.append(w["pos"])
	return out


## 所有建筑/空地/角楼/点缀的占地（地面 x,z），寻路障碍与测试共用。
func footprints() -> Array:
	var out: Array = []
	for b in _slots:
		var s: Dictionary = _slots[b]
		var box: AABB = (s["model_box"] as AABB).merge(s["plot_box"])
		out.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		for e in s["extras"]:
			var eb := _world_box(e)
			out.append(Rect2(eb.position.x, eb.position.z, eb.size.x, eb.size.z))
	for db in _deco_boxes:
		var a := db as AABB
		out.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
	return out


func _build_nav() -> void:
	var fronts: Array = []
	for b in _slots:
		var front := to_world(_slots[b]["pos"] as Vector2)
		fronts.append(Vector2(front.x, front.z))
	# 可走范围 = 城墙内侧（墙半厚 0.5 米 + 余量）。
	nav.build(bounds.grow(-0.9), footprints(), _road_rects, fronts)


func _new_route(w: Dictionary) -> void:
	if nav.doors.is_empty():
		return
	var goal: Vector2 = nav.doors[randi() % nav.doors.size()]
	w["path"] = nav.path(w["pos"], goal)
	w["idx"] = 0


# ---------- 构建 ----------
func _build_slot(building: String, cfg: Dictionary, extras: Array) -> void:
	var root := Node3D.new()
	root.name = "Slot_" + building
	add_child(root)
	var pos: Vector2 = cfg["pos"]
	var team := ArenaPresenter.COLOR_BLUE if building == "watchtower" else Color.WHITE
	var model := _place(BUILDING_ASSETS[building], float(cfg.get("w", 140.0)) / PX_PER_M, pos, root, team)
	var plot := _place(PLOT_ASSET, PLOT_WIDTH_M, pos, root)
	var model_box := _world_box(model)
	var scaffold := _scaffold(model_box)
	root.add_child(scaffold)
	var extra_nodes: Array = []
	var extra_hulls: Array = []
	for ep in extras:
		var e := _place(BUILDING_ASSETS[building], float(cfg.get("w", 140.0)) / PX_PER_M, ep as Vector2, root, team)
		extra_nodes.append(e)
		extra_hulls.append(_view_hull(e))
	_slots[building] = {"root": root, "model": model, "plot": plot, "scaffold": scaffold, "pos": pos,
		"model_box": model_box, "plot_box": _world_box(plot), "model_hull": _view_hull(model),
		"plot_hull": _view_hull(plot), "level": 0, "extras": extra_nodes, "extra_hulls": extra_hulls}
	set_slot_state(building, 0, false)


## 摆一个静态模型：按目标宽度等比缩放，正面底边贴槽位 pos（模型原点在占地中心 → 向北退半个进深）。
func _place(asset: String, width_m: float, pos_px: Vector2, parent: Node, team := Color.WHITE) -> Node3D:
	var inst: Node3D = _scene(asset).instantiate()
	inst.set_meta("asset", asset)
	ToonStyle.apply(inst, team, Color.WHITE, GRADE)
	var box := _native_box(asset)
	var k := width_m / maxf(box.size.x, 0.01)
	inst.scale = Vector3.ONE * k
	var front := to_world(pos_px)
	var center_x := (box.position.x + box.size.x * 0.5) * k
	inst.position = Vector3(front.x - center_x, 0.0, front.z - box.end.z * k)
	parent.add_child(inst)
	return inst


func _world_box(node: Node3D) -> AABB:
	var box := _native_box(str(node.get_meta("asset")))
	return AABB(node.position + box.position * node.scale, box.size * node.scale)


func _scene(asset: String) -> PackedScene:
	if not _scenes.has(asset):
		_scenes[asset] = load("res://assets/models/%s/%s.glb" % [asset, asset])
	return _scenes[asset]


func _native_box(asset: String) -> AABB:
	if _dims.has(asset):
		return _dims[asset]
	var inst: Node3D = _scene(asset).instantiate()
	var box := AABB()
	var first := true
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var b := mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	inst.free()
	_dims[asset] = box
	return box


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(BG_SIZE.x / PX_PER_M + 60.0, BG_SIZE.y / PX_PER_M + 60.0)
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("cell", 2.0)
	mat.set_shader_parameter("color_a", GRASS_A)
	mat.set_shader_parameter("color_b", GRASS_B)
	mat.set_shader_parameter("saturation", GRADE.x)
	mat.set_shader_parameter("brightness", GRADE.y)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _flat_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("saturation", GRADE.x)
	mat.set_shader_parameter("brightness", GRADE.y)
	return mat


func _build_road(r: Rect2) -> void:
	var a := to_world(r.position)
	var b := to_world(r.end)
	var box := BoxMesh.new()
	box.size = Vector3(b.x - a.x, 0.04, b.z - a.z)
	_road_rects.append(Rect2(a.x, a.z, b.x - a.x, b.z - a.z))
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _flat_material(ROAD_COLOR)
	mi.position = Vector3((a.x + b.x) * 0.5, 0.02, (a.z + b.z) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## 城墙：四边按段铺 k_wall（每边均分、等长拉伸），南墙在城门处留口；四角放角楼。
func _build_walls(w: Dictionary) -> void:
	if w.is_empty():
		return
	var top := float(w["top"])
	var bottom := float(w["bottom"])
	var left := float(w["left"])
	var right := float(w["right"])
	var gl := float(w["gate_x"]) - float(w["gate_gap"]) * 0.5
	var gr := float(w["gate_x"]) + float(w["gate_gap"]) * 0.5
	_wall_run(Vector2(left, top), Vector2(right, top))
	_wall_run(Vector2(left, bottom), Vector2(gl, bottom))
	_wall_run(Vector2(gr, bottom), Vector2(right, bottom))
	_wall_run(Vector2(left, top), Vector2(left, bottom))
	_wall_run(Vector2(right, top), Vector2(right, bottom))
	for c in [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]:
		var post: Node3D = _scene(WALL_POST_ASSET).instantiate()
		ToonStyle.apply(post, Color.WHITE, Color.WHITE, GRADE)
		post.position = to_world(c as Vector2)
		add_child(post)


func _wall_run(a_px: Vector2, b_px: Vector2) -> void:
	var a := to_world(a_px)
	var b := to_world(b_px)
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var n := maxi(1, int(round(length / WALL_SEG_M)))
	var seg := length / n
	var dir := (b - a).normalized()
	for i in n:
		var inst: Node3D = _scene(WALL_ASSET).instantiate()
		ToonStyle.apply(inst, Color.WHITE, Color.WHITE, GRADE)
		inst.position = a + dir * (seg * (i + 0.5))
		inst.rotation.y = atan2(-dir.z, dir.x)
		inst.scale = Vector3(seg / WALL_SEG_M, 1.0, 1.0)
		add_child(inst)


func _build_deco(kind: String, pos: Vector2) -> void:
	var spec: Array = DECO_ASSETS.get(kind, [])
	if spec.is_empty():
		return
	_deco_boxes.append(_world_box(_place(str(spec[0]), float(spec[1]), pos, self)))


## 施工脚手架（程序化木架，按建筑包围盒套住）：四角立柱 + 两圈横梁 + 正面斜撑 + 一层踏板。
func _scaffold(box: AABB) -> Node3D:
	var root := Node3D.new()
	root.name = "Scaffold"
	var pad := 0.2
	var x0 := box.position.x - pad
	var x1 := box.end.x + pad
	var z0 := box.position.z - pad
	var z1 := box.end.z + pad
	var h := box.size.y * 0.9
	var wood := _flat_material(WOOD)
	var dark := _flat_material(WOOD_D)
	for x in [x0, x1]:
		for z in [z0, z1]:
			_beam(root, Vector3(x, h * 0.5, z), Vector3(0.14, h, 0.14), dark)
	for y in [h * 0.45, h * 0.9]:
		for z in [z0, z1]:
			_beam(root, Vector3((x0 + x1) * 0.5, y, z), Vector3(x1 - x0, 0.1, 0.1), wood)
		for x in [x0, x1]:
			_beam(root, Vector3(x, y, (z0 + z1) * 0.5), Vector3(0.1, 0.1, z1 - z0), wood)
	var diag := Vector2(x1 - x0, h * 0.45)
	var brace := _beam(root, Vector3((x0 + x1) * 0.5, h * 0.225, z1), Vector3(diag.length(), 0.08, 0.08), wood)
	brace.rotation.z = atan2(diag.y, diag.x)
	_beam(root, Vector3((x0 + x1) * 0.5, h * 0.45 + 0.06, z1 - 0.25), Vector3(x1 - x0, 0.06, 0.5), wood)
	return root


func _beam(parent: Node3D, pos: Vector3, beam_size: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = beam_size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _spawn_walkers(ids: Array, heights: Dictionary) -> void:
	if nav.doors.is_empty():
		return
	for uid in ids:
		var model: Dictionary = UnitModels.model_for(str(uid))
		if model.is_empty():
			continue
		var node: Node3D = (model["scene"] as PackedScene).instantiate()
		ToonStyle.apply(node, Color.WHITE, model.get("tint", Color.WHITE), GRADE)
		var h := UnitModels.target_height(float(heights.get(uid, 0.0)), 0.5) * WALKER_SCALE
		node.scale = Vector3.ONE * (h / maxf(float(model["native_h"]), 0.01))
		node.name = "Walker_" + str(uid)
		add_child(node)
		var player: AnimationPlayer = null
		var players := node.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			player = players[0]
			if player.has_animation("Walk"):
				player.play("Walk")
		var start: Vector2 = nav.doors[randi() % nav.doors.size()]
		node.position = Vector3(start.x, 0.0, start.y)
		var w := {"node": node, "player": player, "pos": start, "path": PackedVector2Array(), "idx": 0,
			"speed": randf_range(0.85, 1.45)}
		_new_route(w)
		_walkers.append(w)
