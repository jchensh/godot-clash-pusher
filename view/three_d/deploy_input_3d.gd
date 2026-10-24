## D2 3D 出牌输入：屏幕点 → 相机射线 → 地平面 → tile；拖拽中画部署 ghost 与己方半场高亮。
## 只判定与提示：合法性复用 Arena.can_deploy（兵牌）/场内（法术），与 2D 路径同口径；
## 松手合法 → 发 deploy_requested(hand_index, tile)，由调用方走既有入口（PvE try_play_card / PvP DeployCmd）。
extends Node3D

signal deploy_requested(hand_index: int, tile: Vector2)

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const BattleCamera := preload("res://view/three_d/battle_camera.gd")

const DROP_LIFT_TILES := 1.6     # 落点抬到手指上方（与 2D battle_scene 同值，拇指不遮挡）
const COL_OK := Color(0.45, 1.0, 0.55)
const COL_BAD := Color(1.0, 0.42, 0.38)
const GHOST_Y := 0.06

var owner_id := 0
var flipped := false
var grid := Vector2.ZERO
var viewport_size := Vector2.ZERO  # 屏幕像素尺寸（视口变化时由调用方更新，同时更新 blocked_rects）
var blocked_rects: Array = []    # 屏幕上的 HUD/顶栏矩形：松手在其中 = 取消
var dragging := false
var hand_index := -1
var card_id := ""
var info: Dictionary = {}
var drop_tile: Variant = null    # 当前落点（tile）；null = 不在场地上
var legal := false

var _camera: Camera3D
var _arena = null
var _loader = null
var _time := 0.0
var _ghost: Node3D
var _zone: MeshInstance3D


func configure(camera: Camera3D, arena, loader, owner: int, is_flipped: bool, viewport: Vector2) -> void:
	_camera = camera
	viewport_size = viewport
	_arena = arena
	_loader = loader
	owner_id = owner
	flipped = is_flipped
	grid = Vector2(arena.grid_w, arena.grid_h)
	cancel_drag()


func begin_drag(index: int, cid: String) -> void:
	cancel_drag()   # 换牌重拖：先释放上一张的 ghost/高亮
	hand_index = index
	card_id = cid
	info = card_info(_loader, cid)
	dragging = true
	drop_tile = null
	legal = false
	_build_ghost()


## 拖拽中每帧（或每次指针移动）调用：刷新落点、合法性与 ghost。
func update_drag(screen: Vector2) -> void:
	if not dragging:
		return
	drop_tile = pick_tile(screen)
	legal = drop_tile != null and not _blocked(screen) and is_legal(drop_tile)
	_update_ghost()


## 松手：合法 → 发信号并返回 true；HUD 上/场外/非法 → 取消返回 false。
func end_drag(screen: Vector2) -> bool:
	if not dragging:
		return false
	update_drag(screen)
	var ok := legal
	var index := hand_index
	var tile: Variant = drop_tile
	cancel_drag()
	if ok:
		deploy_requested.emit(index, tile)
	return ok


func cancel_drag() -> void:
	dragging = false
	hand_index = -1
	card_id = ""
	info = {}
	drop_tile = null
	legal = false
	if _ghost != null:
		_ghost.free()
		_ghost = null
	if _zone != null:
		_zone.free()
		_zone = null


## 屏幕点 → 抬手后的落点 tile；射线没打到地面或落在场外返回 null。
func pick_tile(screen: Vector2) -> Variant:
	var lifted := screen + Vector2(0.0, -lift_pixels())
	var ray := BattleCamera.screen_ray(_camera_xform(), _camera.size, viewport_size, lifted)
	var tile: Variant = FieldProjection.ray_to_tile(ray[0], ray[1], grid, flipped)
	if tile == null or not in_field(tile):
		return null
	return tile


## 兵牌：Arena.can_deploy（己方半场 + 可走地面，2D/服务端同一权威）；法术：场内任意点。
func is_legal(tile: Vector2) -> bool:
	if not in_field(tile):
		return false
	if info.get("spawn", false):
		return _arena.can_deploy(owner_id, tile)
	return true


func in_field(tile: Vector2) -> bool:
	return tile.x >= 0.0 and tile.y >= 0.0 and tile.x < grid.x and tile.y < grid.y


## 抬手距离（像素）= 地面上「屏幕向上」1.6 格在当前镜头下的投影长度（与 2D 的 1.6 格同义）。
func lift_pixels() -> float:
	var xform := _camera_xform()
	var ground := Vector3(xform.basis.y.x, 0.0, xform.basis.y.z)
	if ground.length() < 0.0001:
		return 0.0
	var a := tile_screen_world(Vector3.ZERO)
	var b := tile_screen_world(ground.normalized())
	return a.distance_to(b) * DROP_LIFT_TILES


## tile 在屏幕上的像素位置（未抬手）；供 HUD 锚点/测试使用。
func tile_to_screen(tile: Vector2) -> Vector2:
	return tile_screen_world(FieldProjection.tile_to_world(tile, grid, flipped))


func tile_screen_world(world: Vector3) -> Vector2:
	return BattleCamera.world_to_screen(_camera_xform(), _camera.size, viewport_size, world)


func _camera_xform() -> Transform3D:
	return _camera.global_transform if _camera.is_inside_tree() else _camera.transform


func _process(delta: float) -> void:
	_time += delta
	if _zone != null:
		(_zone.material_override as StandardMaterial3D).albedo_color.a = 0.14 + 0.06 * (0.5 + 0.5 * sin(_time * 6.0))


func _blocked(screen: Vector2) -> bool:
	for rect in blocked_rects:
		if (rect as Rect2).has_point(screen):
			return true
	return false


## 卡牌出什么：spawn=生成兵（unit_id/count/body_radius）；否则法术（radius>0=AOE 圈、=0=直伤准星）。与 2D _card_info 同口径。
static func card_info(loader, cid: String) -> Dictionary:
	for sk in loader.get_card(cid).get("skills", []):
		if typeof(sk) != TYPE_DICTIONARY:
			continue
		var t = sk.get("type")
		if t == "spawn_unit":
			var unit_id := str(sk.get("unit_id"))
			return {"spawn": true, "unit_id": unit_id, "count": int(sk.get("count", 1)), "radius": 0.0,
				"body_radius": float(loader.get_unit(unit_id).get("body_radius", 0.5))}
		elif t == "aoe_damage" or t == "aoe_heal":
			return {"spawn": false, "unit_id": "", "count": 0, "radius": float(sk.get("radius", 1.0))}
		elif t == "direct_damage":
			return {"spawn": false, "unit_id": "", "count": 0, "radius": 0.0}
	return {"spawn": false, "unit_id": "", "count": 0, "radius": 0.0}


func _build_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "DeployGhost"
	_ghost.visible = false
	add_child(_ghost)
	_ghost.add_child(_part("Ring", _torus(0.55, 0.7), Vector3.ZERO, true))
	if info.get("spawn", false):
		var n := maxi(1, int(info.count))
		var r := clampf(float(info.body_radius), 0.25, 0.9)
		for i in n:
			var off := Vector3.ZERO
			if n > 1:
				var ang := float(i) / n * TAU
				off = Vector3(cos(ang), 0, sin(ang)) * r * 0.9
			var disc := CylinderMesh.new()
			disc.top_radius = r
			disc.bottom_radius = r
			disc.height = 0.04
			_ghost.add_child(_part("Unit%d" % i, disc, off, false))
		_build_zone()
	elif float(info.radius) > 0.0:
		var area := CylinderMesh.new()
		area.top_radius = float(info.radius)
		area.bottom_radius = float(info.radius)
		area.height = 0.03
		_ghost.add_child(_part("Area", area, Vector3.ZERO, false))
		_ghost.add_child(_part("AreaEdge", _torus(float(info.radius) - 0.08, float(info.radius)), Vector3.ZERO, true))
	else:
		for axis in [Vector3(1.2, 0.04, 0.12), Vector3(0.12, 0.04, 1.2)]:
			var bar := BoxMesh.new()
			bar.size = axis
			_ghost.add_child(_part("Cross", bar, Vector3.ZERO, true))


## 己方半场高亮（仅兵牌，同 2D _draw_deploy_hint）：玩家 y∈[deploy_player_y_min, h]，对手 y∈[0, deploy_enemy_y_max]。
func _build_zone() -> void:
	var y0: float = _arena.deploy_player_y_min if owner_id == 0 else 0.0
	var y1: float = grid.y if owner_id == 0 else _arena.deploy_enemy_y_max
	var a := FieldProjection.tile_to_world(Vector2(0.0, y0), grid, flipped, GHOST_Y * 0.5)
	var b := FieldProjection.tile_to_world(Vector2(grid.x, y1), grid, flipped, GHOST_Y * 0.5)
	var plane := BoxMesh.new()
	plane.size = Vector3(absf(b.x - a.x), 0.02, absf(b.z - a.z))
	_zone = _part("DeployZone", plane, (a + b) * 0.5, false)
	(_zone.material_override as StandardMaterial3D).albedo_color = Color(COL_OK.r, COL_OK.g, COL_OK.b, 0.16)
	add_child(_zone)


func _update_ghost() -> void:
	if _ghost == null:
		return
	_ghost.visible = drop_tile != null
	if drop_tile == null:
		return
	_ghost.position = FieldProjection.tile_to_world(drop_tile, grid, flipped, GHOST_Y)
	var col := COL_OK if legal else COL_BAD
	for child in _ghost.get_children():
		var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
		mat.albedo_color = Color(col.r, col.g, col.b, mat.albedo_color.a)


func _part(label: String, mesh: Mesh, pos: Vector3, solid: bool) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = solid
	mat.albedo_color = Color(COL_OK.r, COL_OK.g, COL_OK.b, 0.95 if solid else 0.35)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _torus(inner: float, outer: float) -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	return ring
