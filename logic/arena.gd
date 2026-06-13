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

var grid_w: int = 0
var grid_h: int = 0
var river_y_min: int = 0
var river_y_max: int = 0          # 河占 [y_min, y_max) 行
var bridges: Array = []           # [{x_min,x_max}]：x∈[x_min,x_max) 为桥（地面）
var deploy_player_y_min: float = 0.0   # 玩家可部署 y >= 此值
var deploy_enemy_y_max: float = 0.0    # 对手可部署 y <= 此值
var _tower_rects: Array = []      # [{x0,y0,w,h}]：塔占位（tile 矩形）

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
