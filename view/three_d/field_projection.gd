## 表现层坐标契约：tile 平面映射到 XZ；世界高度只用于表现。
extends RefCounted


static func tile_to_world(tile: Vector2, grid: Vector2, flipped := false, height := 0.0) -> Vector3:
	var point := grid - tile if flipped else tile
	return Vector3(point.x - grid.x * 0.5, height, point.y - grid.y * 0.5)


static func world_to_tile(world: Vector3, grid: Vector2, flipped := false) -> Vector2:
	var point := Vector2(world.x, world.z) + grid * 0.5
	return grid - point if flipped else point


static func ray_to_tile(origin: Vector3, direction: Vector3, grid: Vector2, flipped := false) -> Variant:
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return null
	return world_to_tile(hit as Vector3, grid, flipped)
