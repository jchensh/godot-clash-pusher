extends "res://tests/test_case.gd"

const FieldProjection := preload("res://view/three_d/field_projection.gd")
const Presenter := preload("res://view/three_d/arena_presenter.gd")
const Loader := preload("res://logic/config_loader.gd")


func test_projection_roundtrip_both_sides() -> void:
	var grid := Vector2(26, 30)
	for flipped in [false, true]:
		for tile in [Vector2.ZERO, Vector2(4.5, 22), grid, grid * 0.5]:
			var world := FieldProjection.tile_to_world(tile, grid, flipped, 5.0)
			assert_true(FieldProjection.world_to_tile(world, grid, flipped).is_equal_approx(tile), "双向坐标无损")
	assert_eq(FieldProjection.tile_to_world(grid * 0.5, grid), Vector3.ZERO, "场地中心为世界原点")


func test_ray_hits_ground_or_returns_null() -> void:
	var grid := Vector2(26, 30)
	assert_eq(FieldProjection.ray_to_tile(Vector3(0, 10, 0), Vector3.DOWN, grid), grid * 0.5)
	assert_null(FieldProjection.ray_to_tile(Vector3(0, 10, 0), Vector3.RIGHT, grid), "平行射线无落点")
	assert_null(FieldProjection.ray_to_tile(Vector3(0, 10, 0), Vector3.UP, grid), "背向射线无落点")


func test_presenter_reads_config_and_rebuilds_without_duplicates() -> void:
	var loader := Loader.new()
	loader.load_all()
	var config: Dictionary = loader.get_arena("default")
	var field := Presenter.new()
	field.build(config)
	assert_eq(field.grid_size, Vector2(config.grid.w, config.grid.h))
	assert_eq(field.bridge_count, config.river.bridges.size())
	var expected := 0
	for side in config.towers:
		expected += config.towers[side].size()
	assert_eq(field.tower_count, expected)
	var count := field.get_child_count()
	field.build(config)
	assert_eq(field.get_child_count(), count, "重建不重复叠加旧场景")
	field.free()
