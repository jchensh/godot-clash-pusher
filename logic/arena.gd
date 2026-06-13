# Arena —— V3 2D 战斗场地（取代 1D Lane）。
#
# 坐标 = 抽象 tile 空间（非屏幕像素），view 负责 tile→屏幕映射；逻辑层不关心渲染。
# 约定方向：y=0 敌方底线（上），y=grid_h 玩家底线（下），河在中部、左右双桥为地面缺口。
#
# 本文件为 V3-1a 范围：**地形网格 + 塔占位 + 落点合法性（纯查询）**。
# 单位移动 / 流场寻路 / 仇恨 / 软分离 / tick 见后续 V3-1b+。
# 确定性、可 headless 单测、不用物理引擎。
extends RefCounted
class_name Arena

const TILE_OOB := -1      # 出界
const TILE_GROUND := 0    # 地面（可走、可部署）
const TILE_WATER := 1     # 水（地面不可走、不可部署；空军 V3-2 可越）
const TILE_TOWER := 2     # 塔占位（阻挡、不可部署）

const OWNER_PLAYER := 0
const OWNER_OPPONENT := 1
const _EPSILON := 0.000001
const _NEIGHBORS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

var grid_w: int = 0
var grid_h: int = 0
var river_y_min: int = 0
var river_y_max: int = 0          # 河占 [y_min, y_max) 行
var bridges: Array = []           # [{x_min,x_max}]：x∈[x_min,x_max) 为桥（地面）
var deploy_player_y_min: float = 0.0   # 玩家可部署 y >= 此值
var deploy_enemy_y_max: float = 0.0    # 对手可部署 y <= 此值
var _tower_rects: Array = []      # [{x0,y0,w,h}]：塔占位（tile 矩形）

var towers: Array = []            # Tower 引用（流场目标 + 攻击目标）
var units: Array = []             # 场上单位
var _flow: Dictionary = {}        # tower -> PackedInt32Array：到该塔的 BFS 距离场（-1=不可达）

func setup(cfg: Dictionary) -> void:
	var grid: Dictionary = cfg.get("grid", {})
	grid_w = int(grid.get("w", 0))
	grid_h = int(grid.get("h", 0))
	var river: Dictionary = cfg.get("river", {})
	river_y_min = int(river.get("y_min", 0))
	river_y_max = int(river.get("y_max", 0))
	bridges = []
	for b in river.get("bridges", []):
		bridges.append({"x_min": int(b.get("x_min", 0)), "x_max": int(b.get("x_max", 0))})
	var dep: Dictionary = cfg.get("deploy", {})
	deploy_player_y_min = float(dep.get("player_y_min", 0.0))
	deploy_enemy_y_max = float(dep.get("enemy_y_max", float(grid_h)))
	_tower_rects = []

# 注册一座塔的占位（中心 cx,cy + 宽高 fw,fh，tile 单位）。由 Battle.build_arena 调用。
func add_tower_footprint(cx: float, cy: float, fw: int, fh: int) -> void:
	var x0 := int(floor(cx - fw / 2.0))
	var y0 := int(floor(cy - fh / 2.0))
	_tower_rects.append({"x0": x0, "y0": y0, "w": fw, "h": fh})

func in_bounds(tx: int, ty: int) -> bool:
	return tx >= 0 and tx < grid_w and ty >= 0 and ty < grid_h

func _in_tower(tx: int, ty: int) -> bool:
	for r in _tower_rects:
		if tx >= r["x0"] and tx < r["x0"] + r["w"] and ty >= r["y0"] and ty < r["y0"] + r["h"]:
			return true
	return false

func _on_bridge(tx: int) -> bool:
	for b in bridges:
		if tx >= b["x_min"] and tx < b["x_max"]:
			return true
	return false

# tile 类型（整数 tile 坐标）。
func tile_type(tx: int, ty: int) -> int:
	if not in_bounds(tx, ty):
		return TILE_OOB
	if _in_tower(tx, ty):
		return TILE_TOWER
	if ty >= river_y_min and ty < river_y_max:
		return TILE_GROUND if _on_bridge(tx) else TILE_WATER
	return TILE_GROUND

# tile 类型（连续位置，向下取整到 tile）。
func tile_type_at(pos: Vector2) -> int:
	return tile_type(int(floor(pos.x)), int(floor(pos.y)))

func is_ground_walkable(tx: int, ty: int) -> bool:
	return tile_type(tx, ty) == TILE_GROUND

func is_ground_walkable_at(pos: Vector2) -> bool:
	return tile_type_at(pos) == TILE_GROUND

# 落点合法性（V3-1a，决策 36：固定己方半场）：
# 在场内、地面可走（非水/塔）、且落在出牌方己方半场。纯法术不受限属上层 Player 职责。
func can_deploy(owner_id: int, pos: Vector2) -> bool:
	if not is_ground_walkable_at(pos):
		return false
	if owner_id == OWNER_PLAYER:
		return pos.y >= deploy_player_y_min
	return pos.y <= deploy_enemy_y_max

# —— 塔 / 单位登记 ——

# 登记一座塔：存引用 + 注册占位。由 Battle.build_arena 调用。
func add_tower(tower) -> void:
	towers.append(tower)
	add_tower_footprint(tower.pos.x, tower.pos.y, tower.fw, tower.fh)

func add_unit(unit) -> void:
	if unit != null:
		units.append(unit)

func get_units() -> Array:
	return units.duplicate()

# —— 流场寻路（V3-1b）：每座塔预算一张 BFS 距离场（地形静态，塔毁才需重算）——

func build_flow_fields() -> void:
	_flow.clear()
	for t in towers:
		_flow[t] = _bfs_to_tower(t)

# 塔毁后占位释放、路径改变 → 重算（V3-1e 接通塔被摧毁时调用）。
func rebuild_flow_fields() -> void:
	build_flow_fields()

func _bfs_to_tower(tower) -> PackedInt32Array:
	var n := grid_w * grid_h
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var q: Array[Vector2i] = []
	# 种子 = 塔占位 tile（dist 0）；只向地面可走邻居扩散。
	var x0 := int(floor(tower.pos.x - tower.fw / 2.0))
	var y0 := int(floor(tower.pos.y - tower.fh / 2.0))
	for ty in range(y0, y0 + tower.fh):
		for tx in range(x0, x0 + tower.fw):
			if tx >= 0 and tx < grid_w and ty >= 0 and ty < grid_h:
				var idx := ty * grid_w + tx
				if dist[idx] == -1:
					dist[idx] = 0
					q.append(Vector2i(tx, ty))
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var cd := dist[c.y * grid_w + c.x]
		for off: Vector2i in _NEIGHBORS:
			var nx := c.x + off.x
			var ny := c.y + off.y
			if nx < 0 or nx >= grid_w or ny < 0 or ny >= grid_h:
				continue
			var nidx := ny * grid_w + nx
			if dist[nidx] != -1:
				continue
			if not is_ground_walkable(nx, ny):
				continue
			dist[nidx] = cd + 1
			q.append(Vector2i(nx, ny))
	return dist

# —— 逐 tick 推进（V3-1b：移动 + 寻路；攻击/分离见 V3-1d+）——

func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	for u in units:
		if not u.is_alive():
			continue
		var target = nearest_enemy_tower(u)
		if target == null:
			continue
		if _reached_tower(u, target):
			continue   # 到达攻击距离 → 停下（攻击在 V3-1d/e 接）
		_step_toward(u, target, dt)
	_remove_dead()

# 该单位当前应推进的目标敌塔：流场距离最近的存活敌塔（不可达则欧氏兜底）。
func nearest_enemy_tower(unit):
	var best = null
	var best_d := INF
	var ut := Vector2i(int(floor(unit.pos.x)), int(floor(unit.pos.y)))
	var inside := _in_grid(ut)
	for t in towers:
		if t.owner_id == unit.owner_id or not t.is_alive():
			continue
		if inside and _flow.has(t):
			var d: int = (_flow[t] as PackedInt32Array)[ut.y * grid_w + ut.x]
			if d >= 0 and float(d) < best_d:
				best_d = float(d)
				best = t
	if best != null:
		return best
	# 兜底：流场不可达（如出界）→ 取欧氏最近存活敌塔。
	for t in towers:
		if t.owner_id == unit.owner_id or not t.is_alive():
			continue
		var d: float = unit.pos.distance_to(t.pos)
		if d < best_d:
			best_d = d
			best = t
	return best

func _tower_radius(tower) -> float:
	return maxf(float(tower.fw), float(tower.fh)) / 2.0

func _reached_tower(unit, tower) -> bool:
	return unit.pos.distance_to(tower.pos) <= float(unit.attack_range) + _tower_radius(tower) + _EPSILON

func _step_toward(unit, tower, dt: float) -> void:
	var dir := Vector2.ZERO
	var ut := Vector2i(int(floor(unit.pos.x)), int(floor(unit.pos.y)))
	var field = _flow.get(tower)
	if field != null and _in_grid(ut):
		var cur_d: int = (field as PackedInt32Array)[ut.y * grid_w + ut.x]
		var best_n := ut
		var best_d := cur_d
		for off: Vector2i in _NEIGHBORS:
			var nt := ut + off
			if not _in_grid(nt) or not is_ground_walkable(nt.x, nt.y):
				continue
			var nd: int = (field as PackedInt32Array)[nt.y * grid_w + nt.x]
			if nd < 0:
				continue
			if best_d < 0 or nd < best_d:
				best_d = nd
				best_n = nt
		if best_n != ut:
			dir = Vector2(best_n.x + 0.5, best_n.y + 0.5) - unit.pos
	if dir == Vector2.ZERO:
		dir = tower.pos - unit.pos   # 兜底：直奔目标
	if dir.length() <= _EPSILON:
		return
	var np: Vector2 = unit.pos + dir.normalized() * float(unit.move_speed) * dt
	var tt := tile_type_at(np)
	if tt == TILE_WATER or tt == TILE_OOB:
		return   # 安全网：不踏入水/出界（流场本应已绕开）
	unit.pos = np

func _in_grid(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < grid_w and t.y >= 0 and t.y < grid_h

func _remove_dead() -> void:
	for i in range(units.size() - 1, -1, -1):
		if not units[i].is_alive():
			units.remove_at(i)
