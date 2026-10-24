## D6 王国居民寻路：把城内地面切成 CELL 米的格子，建筑/点缀占地（外扩 MARGIN）标为不可走，路面通行代价低于草地，
## 用 AStarGrid2D 求路径——居民绕开房子、优先走路。纯算法（不用物理引擎），坐标为地面 (x, z) 米。
extends RefCounted

const CELL := 0.5
const MARGIN := 0.35             # 障碍外扩：居民身体半宽，贴墙走也不穿模
const ROAD_COST := 1.0
const GRASS_COST := 4.0          # 草地代价：有路时绕一点也走路
const DOOR_OFFSET := 0.7         # 门口目标点在建筑正面外多少米

var _grid := AStarGrid2D.new()
var _origin := Vector2.ZERO      # 格子 (0,0) 左上角的地面坐标
var _obstacles: Array = []       # Rect2（地面 x,z，已外扩）
var doors: Array = []            # 可去的门口点（地面 x,z；已吸附到可走格中心）


## area：可走范围（城墙内侧）；obstacles：Rect2（x,z）占地；roads：Rect2（x,z）路面；fronts：[Vector2(门口中心 x, 正面 z)]。
func build(area: Rect2, obstacles: Array, roads: Array, fronts: Array) -> void:
	_origin = area.position
	_grid.region = Rect2i(0, 0, int(ceil(area.size.x / CELL)), int(ceil(area.size.y / CELL)))
	_grid.cell_size = Vector2.ONE * CELL
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	_obstacles.clear()
	for o in obstacles:
		_obstacles.append((o as Rect2).grow(MARGIN))
	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			var c := Vector2i(x, y)
			var p := cell_center(c)
			_grid.set_point_weight_scale(c, ROAD_COST if _in_any(p, roads) else GRASS_COST)
			if _in_any(p, _obstacles):
				_grid.set_point_solid(c, true)
	doors.clear()
	for f in fronts:
		var want := (f as Vector2) + Vector2(0.0, DOOR_OFFSET + MARGIN)
		var c := nearest_free(want)
		if c.x >= 0:
			doors.append(cell_center(c))


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - _origin.x) / CELL)), int(floor((p.y - _origin.y) / CELL)))


func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func is_walkable(p: Vector2) -> bool:
	var c := cell_of(p)
	return _grid.is_in_boundsv(c) and not _grid.is_point_solid(c)


## 离 p 最近的可走格（按圈向外找）；找不到返回 (-1,-1)。
func nearest_free(p: Vector2) -> Vector2i:
	var c0 := cell_of(p)
	for r in 12:
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := c0 + Vector2i(dx, dy)
				if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c):
					var d := cell_center(c).distance_squared_to(p)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## from → to 的路径（地面点序列，起点为 from 所在格；共线点已合并）；不可达返回空。
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_free(from)
	var b := nearest_free(to)
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var cells := _grid.get_id_path(a, b)
	var out := PackedVector2Array()
	for i in cells.size():
		var p := cell_center(cells[i])
		if out.size() >= 2:
			var d0 := (out[out.size() - 1] - out[out.size() - 2]).normalized()
			if d0.is_equal_approx((p - out[out.size() - 1]).normalized()):
				out[out.size() - 1] = p
				continue
		out.append(p)
	return out


func obstacles() -> Array:
	return _obstacles


static func _in_any(p: Vector2, rects: Array) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p):
			return true
	return false
