# V3-1a 测试：Arena 2D 场地 —— 地形（地面/水/桥）、塔占位、落点合法性。
# 坐标 = tile 空间；arena.json default：18×32、河 y[15,17)、桥 x{3,4}&{13,14}、
# 落点 玩家 y>=17 / 对手 y<=15、塔位见 config/arena.json。
extends "res://tests/test_case.gd"

const ArenaScript = preload("res://logic/arena.gd")
const BattleScript = preload("res://logic/battle.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

func _loader():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return loader

# 仅地形（不含塔占位）：直接 setup arena 配置。
func _terrain():
	var a = ArenaScript.new()
	a.setup(_loader().get_arena("default"))
	return a

# 含塔占位：经 Battle.build_arena 注册 6 塔占位。
func _battle_arena():
	var loader = _loader()
	var battle = BattleScript.new()
	var arena = battle.build_arena(loader.get_level("level_01"), loader.get_arena("default"))
	return [battle, arena]

# —— 地形 ——

func test_grid_dims() -> void:
	var a = _terrain()
	assert_eq(a.grid_w, 18, "网格宽=18")
	assert_eq(a.grid_h, 32, "网格高=32")

func test_river_water_blocks_ground() -> void:
	var a = _terrain()
	# 河行(y=15)、非桥列(x=9) 应为水、地面不可走。
	assert_eq(a.tile_type(9, 15), ArenaScript.TILE_WATER, "河中非桥处为水")
	assert_false(a.is_ground_walkable(9, 15), "水不可走（地面）")

func test_bridges_are_walkable() -> void:
	var a = _terrain()
	# 左桥 x∈{3,4}、右桥 x∈{13,14}，在河行内应为地面可走。
	assert_eq(a.tile_type(3, 15), ArenaScript.TILE_GROUND, "左桥为地面")
	assert_true(a.is_ground_walkable(4, 16), "左桥可走")
	assert_eq(a.tile_type(13, 15), ArenaScript.TILE_GROUND, "右桥为地面")
	assert_true(a.is_ground_walkable(14, 16), "右桥可走")

func test_plain_ground_walkable() -> void:
	var a = _terrain()
	assert_eq(a.tile_type(9, 20), ArenaScript.TILE_GROUND, "河外空地为地面")
	assert_true(a.is_ground_walkable(9, 20), "空地可走")

func test_out_of_bounds() -> void:
	var a = _terrain()
	assert_eq(a.tile_type(-1, 0), ArenaScript.TILE_OOB, "左越界")
	assert_eq(a.tile_type(18, 0), ArenaScript.TILE_OOB, "右越界")
	assert_eq(a.tile_type(0, 32), ArenaScript.TILE_OOB, "下越界")
	assert_false(a.in_bounds(18, 0), "in_bounds 越界为假")

# —— 塔占位（经 Battle.build_arena 注册）——

func test_tower_footprints_block() -> void:
	var arena = _battle_arena()[1]
	assert_eq(arena.tile_type(9, 29), ArenaScript.TILE_TOWER, "玩家王塔中心为塔占位")
	assert_eq(arena.tile_type(9, 3), ArenaScript.TILE_TOWER, "敌方王塔中心为塔占位")
	assert_eq(arena.tile_type(4, 24), ArenaScript.TILE_TOWER, "玩家左公主塔占位")
	assert_false(arena.is_ground_walkable(9, 29), "塔占位不可走")

func test_build_arena_six_towers() -> void:
	var battle = _battle_arena()[0]
	assert_eq(battle.player_towers.size(), 3, "玩家 3 塔")
	assert_eq(battle.opponent_towers.size(), 3, "对手 3 塔")
	assert_true(battle.player_king != null and battle.player_king.is_king(), "玩家王塔已识别")
	assert_true(battle.opponent_king != null and battle.opponent_king.is_king(), "对手王塔已识别")

# —— 落点合法性（固定己方半场 + 地面）——

func test_deploy_player_own_half() -> void:
	var arena = _battle_arena()[1]
	assert_true(arena.can_deploy(UnitScript.OWNER_PLAYER, Vector2(9, 20)), "玩家可在己方半场空地部署")
	assert_false(arena.can_deploy(UnitScript.OWNER_PLAYER, Vector2(9, 8)), "玩家不可越界到敌方半场")
	assert_false(arena.can_deploy(UnitScript.OWNER_PLAYER, Vector2(9, 15)), "玩家不可在河区部署")

func test_deploy_rejects_tower_tile() -> void:
	var arena = _battle_arena()[1]
	assert_false(arena.can_deploy(UnitScript.OWNER_PLAYER, Vector2(9, 29)), "不可在自家塔占位部署")

func test_deploy_enemy_symmetric() -> void:
	var arena = _battle_arena()[1]
	assert_true(arena.can_deploy(UnitScript.OWNER_OPPONENT, Vector2(9, 8)), "对手可在其半场部署")
	assert_false(arena.can_deploy(UnitScript.OWNER_OPPONENT, Vector2(9, 20)), "对手不可越界到玩家半场")
	assert_false(arena.can_deploy(UnitScript.OWNER_OPPONENT, Vector2(9, 3)), "对手不可在自家塔占位部署")
