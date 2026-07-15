# T1 溅射（splash）测试：单位攻击命中后对目标周围 splash_radius 内敌方【单位】同施伤。
# 覆盖：多敌溅射 / 半径外不中 / 地面溅射不误伤空军 / splash=0 与现状逐位一致（零回归）。
# 用纯地形 arena（无塔）+ 己方半场干燥地(y≈20-24)静止单位，隔绝塔火/河流干扰，纯测溅射结算。
extends "res://tests/test_case.gd"

const ArenaScript = preload("res://logic/arena.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

# 纯地形 arena（不注册塔占位 → 无塔火干扰）。
func _arena():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var a = ArenaScript.new()
	a.setup(loader.get_arena("default"))
	return a

# 溅射攻击者（静止、首击免费，dmg 50）。atk_targets 决定能打谁；splash=溅射半径。
func _splasher(arena, pos: Vector2, splash: float, atk_targets: String = "both"):
	var cfg := {
		"hp": 100.0, "damage": 50.0, "attack_speed": 1.0, "move_speed": 0.0,
		"attack_range": 2.0, "aggro_radius": 5.0, "body_radius": 0.0,
		"target_type": "ground", "attack_targets": atk_targets, "splash_radius": splash,
	}
	var u = UnitScript.new("splasher", UnitScript.OWNER_PLAYER, cfg, pos)
	arena.add_unit(u)
	return u

# 静止不还手敌方（dmg 0），self_type 决定自身 ground/air。
func _dummy(arena, pos: Vector2, self_type: String = "ground", hp: float = 300.0):
	var cfg := {
		"hp": hp, "damage": 0.0, "attack_speed": 1.0, "move_speed": 0.0,
		"attack_range": 1.0, "aggro_radius": 0.0, "body_radius": 0.0,
		"target_type": self_type, "attack_targets": "ground",
	}
	var u = UnitScript.new("dummy", UnitScript.OWNER_OPPONENT, cfg, pos)
	arena.add_unit(u)
	return u

func test_splash_hits_clustered_enemies() -> void:
	var arena = _arena()
	var atk = _splasher(arena, Vector2(9, 20.0), 1.5)
	var primary = _dummy(arena, Vector2(9, 21.3))      # 主目标（最近，dist 1.3<range 2）
	var near_a = _dummy(arena, Vector2(9.6, 21.3))     # 距主 0.6 < 1.5 → 溅射命中
	var near_b = _dummy(arena, Vector2(8.4, 21.3))     # 距主 0.6 < 1.5 → 溅射命中
	arena.tick(0.1)
	assert_eq(atk.current_target, primary, "锁定最近敌兵为主目标")
	assert_almost_eq(primary.hp, 250.0, 0.0001, "主目标 -50")
	assert_almost_eq(near_a.hp, 250.0, 0.0001, "溅射命中右邻 -50")
	assert_almost_eq(near_b.hp, 250.0, 0.0001, "溅射命中左邻 -50")

func test_splash_spares_out_of_radius() -> void:
	var arena = _arena()
	var atk = _splasher(arena, Vector2(9, 20.0), 1.5)
	var primary = _dummy(arena, Vector2(9, 21.3))
	var far = _dummy(arena, Vector2(9, 24.0))          # 距主 2.7 > 1.5 → 不受溅射
	arena.tick(0.1)
	assert_eq(atk.current_target, primary, "主目标为最近者")
	assert_almost_eq(primary.hp, 250.0, 0.0001, "主目标 -50")
	assert_almost_eq(far.hp, 300.0, 0.0001, "半径外敌兵不受溅射")

func test_ground_splash_does_not_hit_air() -> void:
	var arena = _arena()
	var atk = _splasher(arena, Vector2(9, 20.0), 1.5, "ground")  # 只打地面
	var primary = _dummy(arena, Vector2(9, 21.3), "ground")
	var air = _dummy(arena, Vector2(9.5, 21.3), "air")           # 在溅射半径内但为空军
	arena.tick(0.1)
	assert_almost_eq(primary.hp, 250.0, 0.0001, "地面主目标 -50")
	assert_almost_eq(air.hp, 300.0, 0.0001, "地面溅射不误伤空军（can_hit_type 过滤）")

func test_no_splash_single_target_regression() -> void:
	var arena = _arena()
	var atk = _splasher(arena, Vector2(9, 20.0), 0.0)   # splash=0 → 单体（现状行为）
	var primary = _dummy(arena, Vector2(9, 21.3))
	var neighbor = _dummy(arena, Vector2(9.6, 21.3))
	arena.tick(0.1)
	assert_almost_eq(primary.hp, 250.0, 0.0001, "单体命中主目标 -50")
	assert_almost_eq(neighbor.hp, 300.0, 0.0001, "splash=0 不溅射邻兵（零回归）")
