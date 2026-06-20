# V3-1a 测试：Arena 2D 场地 —— 地形（地面/水/桥）、塔占位、落点合法性。
# 坐标 = tile 空间；arena.json default：18×32、河 y[15,17)、桥 x{3,4}&{13,14}、
# 落点 玩家 y>=17 / 对手 y<=15、塔位见 config/arena.json。
extends "res://tests/test_case.gd"

const ArenaScript = preload("res://logic/arena.gd")
const BattleScript = preload("res://logic/battle.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")
const SkillSystemScript = preload("res://logic/skill_system.gd")

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

# —— 移动 + 流场寻路绕桥（V3-1b 核心）——

func _move_cfg(move_speed: float = 3.0, attack_range: float = 1.0) -> Dictionary:
	# 高血量：移动/寻路测试关注走位，单位需扛住塔火（V3-1e）走完全程。
	return {
		"hp": 100000.0, "damage": 0.0, "attack_speed": 1.0,
		"move_speed": move_speed, "attack_range": attack_range, "target_type": "ground",
	}

func test_ground_unit_routes_over_bridge_without_touching_water() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	var u = UnitScript.new("runner", UnitScript.OWNER_PLAYER, _move_cfg(), Vector2(4, 20))
	arena.add_unit(u)
	var min_y: float = u.pos.y
	var touched_water := false
	for i in 300:
		battle.step(0.1)
		min_y = minf(min_y, u.pos.y)
		if arena.tile_type_at(u.pos) == ArenaScript.TILE_WATER:
			touched_water = true
	assert_false(touched_water, "地面兵全程不踏水（只经桥过河）")
	assert_true(min_y < 14.0, "越过河到达敌方半场(y<14); 实际 min_y=%.1f" % min_y)

func test_ground_unit_reaches_enemy_tower_and_stops() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	var u = UnitScript.new("runner", UnitScript.OWNER_PLAYER, _move_cfg(), Vector2(4, 20))
	arena.add_unit(u)
	for i in 300:
		battle.step(0.1)
	var princess := Vector2(4.5, 8.0)   # 敌方左公主塔
	assert_true(u.pos.distance_to(princess) <= 3.0,
		"停在敌方左公主塔攻击距离内; dist=%.2f pos=(%.1f,%.1f)" % [u.pos.distance_to(princess), u.pos.x, u.pos.y])
	var before: Vector2 = u.pos
	for i in 10:
		battle.step(0.1)
	assert_true(u.pos.distance_to(before) < 0.5, "到达后停下（位置稳定）")

func test_opponent_unit_routes_downward_over_bridge() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	var u = UnitScript.new("o", UnitScript.OWNER_OPPONENT, _move_cfg(), Vector2(4, 12))
	arena.add_unit(u)
	var max_y: float = u.pos.y
	var touched_water := false
	for i in 300:
		battle.step(0.1)
		max_y = maxf(max_y, u.pos.y)
		if arena.tile_type_at(u.pos) == ArenaScript.TILE_WATER:
			touched_water = true
	assert_false(touched_water, "对手兵也只经桥过河")
	assert_true(max_y > 18.0, "对手兵越河到达玩家半场(y>18); 实际 max_y=%.1f" % max_y)

# —— 目标获取 + 完整 CR 仇恨/分心（V3-1c）——

func _aggro_cfg(aggro: float = 5.0, move: float = 2.0, rng: float = 1.0) -> Dictionary:
	return {
		"hp": 100.0, "damage": 0.0, "attack_speed": 1.0,
		"move_speed": move, "attack_range": rng, "aggro_radius": aggro, "target_type": "ground",
	}

# 静止假敌（不动、不分心）：move_speed=0 + aggro=0，纯做被索敌目标。
func _still_enemy(arena, pos: Vector2, hp: float = 300.0):
	var cfg := {
		"hp": hp, "damage": 0.0, "attack_speed": 1.0,
		"move_speed": 0.0, "attack_range": 1.0, "aggro_radius": 0.0, "target_type": "ground",
	}
	var u = UnitScript.new("dummy", UnitScript.OWNER_OPPONENT, cfg, pos)
	arena.add_unit(u)
	return u

func test_default_targets_enemy_tower() -> void:
	var arena = _battle_arena()[1]
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _aggro_cfg(), Vector2(9, 20))
	arena.add_unit(p)
	arena.tick(0.1)
	assert_true(arena.towers.has(p.current_target), "无敌兵时默认锁敌塔")
	assert_eq(p.current_target.owner_id, UnitScript.OWNER_OPPONENT, "锁的是敌方塔")

func test_distracted_by_enemy_unit_in_aggro() -> void:
	var arena = _battle_arena()[1]
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _aggro_cfg(), Vector2(9, 20))
	arena.add_unit(p)
	var e = _still_enemy(arena, Vector2(9, 18))   # dist 2 < aggro 5
	arena.tick(0.1)
	assert_eq(p.current_target, e, "敌兵进仇恨半径 → 转火打它（分心）")

func test_enemy_outside_aggro_is_ignored() -> void:
	var arena = _battle_arena()[1]
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _aggro_cfg(), Vector2(9, 20))
	arena.add_unit(p)
	_still_enemy(arena, Vector2(9, 14))           # dist 6 > aggro 5
	arena.tick(0.1)
	assert_true(arena.towers.has(p.current_target), "敌兵在仇恨半径外 → 仍默认锁塔")

func test_retarget_back_to_tower_when_distraction_dies() -> void:
	var arena = _battle_arena()[1]
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _aggro_cfg(), Vector2(9, 20))
	arena.add_unit(p)
	var e = _still_enemy(arena, Vector2(9, 18))
	arena.tick(0.1)
	assert_eq(p.current_target, e, "先锁住敌兵")
	e.take_damage(e.max_hp)                        # 杀死分心目标
	arena.tick(0.1)                                # 移除死者 + 回锁
	assert_true(arena.towers.has(p.current_target), "目标死亡 → 回锁敌塔")

func test_pull_unit_pursues_side_distraction() -> void:
	var arena = _battle_arena()[1]
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _aggro_cfg(), Vector2(9, 20))
	arena.add_unit(p)
	var e = _still_enemy(arena, Vector2(5, 20))    # 左侧 dist 4 < aggro 5
	var d0: float = p.pos.distance_to(e.pos)
	for i in 5:
		arena.tick(0.1)
	assert_eq(p.current_target, e, "被拉扯：锁住侧边敌兵")
	assert_true(p.pos.distance_to(e.pos) < d0, "向被拉扯的敌兵移动（距离缩小）")

func test_distraction_picks_nearest_enemy_unit() -> void:
	var arena = _battle_arena()[1]
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _aggro_cfg(), Vector2(9, 20))
	arena.add_unit(p)
	var near = _still_enemy(arena, Vector2(9, 18.5))   # dist 1.5
	_still_enemy(arena, Vector2(9, 17.0))              # dist 3.0（也在 aggro 内）
	arena.tick(0.1)
	assert_eq(p.current_target, near, "分心选最近的敌兵")

# —— 隔河不分心：地面兵走流场绕桥，不卡岸被风筝（A5-1 回归）——

func test_no_distraction_across_river() -> void:
	var arena = _battle_arena()[1]
	# 玩家近战兵在己方半场近河(9,18)，敌兵在河对岸(9,14)：dist 4 < aggro 5，但隔河不可直线到达。
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _aggro_cfg(), Vector2(9, 18))
	arena.add_unit(p)
	_still_enemy(arena, Vector2(9, 14))
	arena.tick(0.1)
	assert_true(arena.towers.has(p.current_target), "隔河敌兵不分心 → 仍锁敌塔（走流场绕桥），不直奔对岸")

func test_ground_unit_crosses_bridge_despite_across_river_enemy() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	# 回归 A5-1：对岸有敌兵持续诱惑时，近战地面兵不应被勾引直奔对岸卡在水边，而应绕桥过河。
	var cfg := {
		"hp": 100000.0, "damage": 0.0, "attack_speed": 1.0,
		"move_speed": 3.0, "attack_range": 1.0, "aggro_radius": 5.0, "target_type": "ground",
	}
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, cfg, Vector2(9, 18))
	arena.add_unit(p)
	_still_enemy(arena, Vector2(9, 14), 100000.0)   # 河对岸静止永生敌兵（持续诱惑）
	var min_y: float = p.pos.y
	var touched_water := false
	for i in 400:
		battle.step(0.1)
		min_y = minf(min_y, p.pos.y)
		if arena.tile_type_at(p.pos) == ArenaScript.TILE_WATER:
			touched_water = true
	assert_false(touched_water, "全程不踏水（绕桥，不卡岸冲水）")
	assert_true(min_y < 15.0, "越过河到达敌方半场(y<15)，未卡在岸边; 实际 min_y=%.1f" % min_y)

# —— 软推挤碰撞 + 接敌攻击（V3-1d）——

func _fighter(arena, owner: int, pos: Vector2, dmg: float = 50.0, hp: float = 100.0,
		rng: float = 1.0, aggro: float = 5.0, body: float = 0.0, move: float = 0.0):
	var cfg := {
		"hp": hp, "damage": dmg, "attack_speed": 1.0, "move_speed": move,
		"attack_range": rng, "aggro_radius": aggro, "body_radius": body, "target_type": "ground",
	}
	var u = UnitScript.new("f", owner, cfg, pos)
	arena.add_unit(u)
	return u

func test_units_separate_when_overlapping() -> void:
	var arena = _battle_arena()[1]
	# 两个同阵营单位（不互打）、有体积、静止 → 仅软分离生效。
	var a = _fighter(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20.0), 0.0, 100.0, 1.0, 0.0, 0.5, 0.0)
	var b = _fighter(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20.3), 0.0, 100.0, 1.0, 0.0, 0.5, 0.0)
	arena.tick(0.1)
	var d: float = a.pos.distance_to(b.pos)
	assert_true(d >= 0.95, "重叠单位被推开到≈体积半径和(1.0); dist=%.2f" % d)

func test_unit_attacks_enemy_unit() -> void:
	var arena = _battle_arena()[1]
	# 放在中场无塔火区(y17 两侧塔都够不到)，纯测单位互攻。
	var atk = _fighter(arena, UnitScript.OWNER_PLAYER, Vector2(9, 17.0), 50.0, 100.0, 1.0, 5.0, 0.0, 0.0)
	var foe = _fighter(arena, UnitScript.OWNER_OPPONENT, Vector2(9, 17.5), 0.0, 300.0, 1.0, 0.0, 0.0, 0.0)  # 不还手
	arena.tick(0.1)
	assert_eq(atk.current_target, foe, "锁定该敌兵")
	assert_almost_eq(foe.hp, 250.0, 0.0001, "接敌首击免费，敌兵 -50")

func test_unit_attacks_enemy_tower() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	# 站在敌方左公主塔(4.5,8)前、射程内、无敌兵 → 锁塔攻击。
	var atk = _fighter(arena, UnitScript.OWNER_PLAYER, Vector2(4.5, 10.0), 50.0, 100.0, 1.0, 5.0, 0.0, 0.0)
	var before: float = battle.total_tower_hp(battle.opponent_towers)
	arena.tick(0.1)
	assert_true(arena.towers.has(atk.current_target), "无敌兵 → 锁敌塔")
	assert_true(battle.total_tower_hp(battle.opponent_towers) < before, "单位攻击敌塔，敌方总塔血下降")

func test_mutual_attack_resolves_simultaneously() -> void:
	var arena = _battle_arena()[1]
	var p = _fighter(arena, UnitScript.OWNER_PLAYER, Vector2(9, 17.0), 50.0, 100.0, 1.0, 5.0, 0.0, 0.0)
	var o = _fighter(arena, UnitScript.OWNER_OPPONENT, Vector2(9, 17.5), 40.0, 300.0, 1.0, 5.0, 0.0, 0.0)
	arena.tick(0.1)
	assert_almost_eq(p.hp, 60.0, 0.0001, "玩家兵被敌兵 -40（同 tick 同步结算）")
	assert_almost_eq(o.hp, 250.0, 0.0001, "敌兵被玩家兵 -50")

# —— 塔会反击 + 塔毁流场重算（V3-1e）——

func test_tower_attacks_enemy_unit_in_range() -> void:
	var arena = _battle_arena()[1]
	# 玩家左公主塔(4.5,24)旁放一个静止不还手的敌兵，进塔射程(7.5)。
	var e = _fighter(arena, UnitScript.OWNER_OPPONENT, Vector2(4.5, 27.0), 0.0, 300.0, 1.0, 0.0, 0.0, 0.0)
	arena.tick(0.1)
	assert_true(e.hp < 300.0, "塔反击射程内敌兵（掉血）; hp=%.0f" % e.hp)

func test_tower_ignores_own_and_out_of_range() -> void:
	var arena = _battle_arena()[1]
	var own = _fighter(arena, UnitScript.OWNER_PLAYER, Vector2(4.5, 27.0), 0.0, 300.0, 1.0, 0.0, 0.0, 0.0)
	var far = _fighter(arena, UnitScript.OWNER_OPPONENT, Vector2(9.0, 17.0), 0.0, 300.0, 1.0, 0.0, 0.0, 0.0)
	arena.tick(0.1)
	assert_almost_eq(own.hp, 300.0, 0.0001, "塔不打己方单位")
	assert_almost_eq(far.hp, 300.0, 0.0001, "塔不打射程外敌兵（中场）")

func test_tower_death_frees_footprint_and_rebuilds_flow() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	var prin = null
	for t in battle.player_towers:
		if not t.is_king() and (t.pos as Vector2).distance_to(Vector2(4.5, 24.0)) < 0.6:
			prin = t
	assert_true(prin != null, "找到玩家左公主塔")
	assert_eq(arena.tile_type(4, 24), ArenaScript.TILE_TOWER, "死前占位为塔")
	prin.take_damage(prin.max_hp)
	arena.tick(0.1)
	assert_eq(arena.tile_type(4, 24), ArenaScript.TILE_GROUND, "塔毁后占位释放为地面（流场重算）")

# —— 空军：飞兵越河 + 对空克制（V3-2）——

func _fly_cfg(move: float = 2.0, atk: String = "both", dmg: float = 0.0, hp: float = 100000.0) -> Dictionary:
	return {
		"hp": hp, "damage": dmg, "attack_speed": 1.0, "move_speed": move, "attack_range": 1.0,
		"aggro_radius": 5.0, "body_radius": 0.4, "target_type": "air", "attack_targets": atk,
	}

func test_flying_unit_crosses_water_directly() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	var f = UnitScript.new("fly", UnitScript.OWNER_PLAYER, _fly_cfg(3.0), Vector2(9, 20))
	arena.add_unit(f)
	var min_y: float = f.pos.y
	var over_water := false
	for i in 300:
		battle.step(0.1)
		min_y = minf(min_y, f.pos.y)
		if arena.tile_type_at(f.pos) == ArenaScript.TILE_WATER:
			over_water = true
	assert_true(over_water, "飞兵直线越河（曾飞在水面上，而非走桥）")
	assert_true(min_y < 14.0, "飞兵越河到敌方半场(y<14); min_y=%.1f" % min_y)

func test_ground_only_cannot_target_air() -> void:
	var arena = _battle_arena()[1]
	# g：attack_targets 默认 ground（_fighter 不设 → ground）。
	var g = _fighter(arena, UnitScript.OWNER_PLAYER, Vector2(9, 17), 50.0, 100.0, 1.0, 5.0, 0.0, 0.0)
	var air = UnitScript.new("air", UnitScript.OWNER_OPPONENT, _fly_cfg(0.0, "both", 0.0, 300.0), Vector2(9, 17.5))
	arena.add_unit(air)
	arena.tick(0.1)
	assert_true(g.current_target != air, "纯地面兵不锁空军（打不到）")
	assert_almost_eq(air.hp, 300.0, 0.0001, "纯地面兵打不到空军")

func test_anti_air_unit_hits_air() -> void:
	var arena = _battle_arena()[1]
	var cfg := {
		"hp": 100.0, "damage": 50.0, "attack_speed": 1.0, "move_speed": 0.0, "attack_range": 2.0,
		"aggro_radius": 5.0, "body_radius": 0.0, "target_type": "ground", "attack_targets": "both",
	}
	var aa = UnitScript.new("aa", UnitScript.OWNER_PLAYER, cfg, Vector2(9, 17.0))
	arena.add_unit(aa)
	# air 放 (9,17.5)：在 aa 射程(2.0)内，但在双方塔火射程外（避免塔火干扰）。
	var air = UnitScript.new("air", UnitScript.OWNER_OPPONENT, _fly_cfg(0.0, "ground", 0.0, 300.0), Vector2(9, 17.5))
	arena.add_unit(air)
	arena.tick(0.1)
	assert_eq(aa.current_target, air, "对空兵(both)锁定空军")
	assert_almost_eq(air.hp, 250.0, 0.0001, "对空兵命中空军 -50")

func test_tower_hits_air_unit() -> void:
	var arena = _battle_arena()[1]
	var air = UnitScript.new("air", UnitScript.OWNER_OPPONENT, _fly_cfg(0.0, "both", 0.0, 300.0), Vector2(4.5, 27.0))
	arena.add_unit(air)
	arena.tick(0.1)
	assert_true(air.hp < 300.0, "塔对空：towers 命中射程内飞兵; hp=%.0f" % air.hp)

func test_air_and_ground_do_not_separate() -> void:
	var arena = _battle_arena()[1]
	var gcfg := {
		"hp": 100.0, "damage": 0.0, "attack_speed": 1.0, "move_speed": 0.0, "attack_range": 1.0,
		"aggro_radius": 0.0, "body_radius": 0.5, "target_type": "ground", "attack_targets": "ground",
	}
	var g = UnitScript.new("g", UnitScript.OWNER_PLAYER, gcfg, Vector2(9, 20.0))
	arena.add_unit(g)
	var air = UnitScript.new("a", UnitScript.OWNER_PLAYER, _fly_cfg(0.0, "both", 0.0, 100.0), Vector2(9, 20.1))
	arena.add_unit(air)
	arena.tick(0.1)
	assert_true(g.pos.distance_to(air.pos) < 0.5, "空/地不同层，不互相推挤")

# —— 亡语召唤（V3-3，on_death_spawn）——

func test_on_death_spawn_summons_units() -> void:
	var loader = _loader()
	var battle = BattleScript.new()
	var arena = battle.build_arena(loader.get_level("level_01"), loader.get_arena("default"))
	var skill = SkillSystemScript.new(loader, battle)
	skill.play_card("golem", UnitScript.OWNER_PLAYER, Vector2(9, 20))   # 石头人：亡语裂 2 哥布林
	assert_eq(arena.get_units().size(), 1, "石头人入场")
	var golem = arena.get_units()[0]
	golem.take_damage(golem.max_hp)            # 击杀
	arena.tick(0.1)                            # _remove_dead → 亡语生成
	var goblins := 0
	for u in arena.get_units():
		if u.unit_id == "goblin_body":
			goblins += 1
	assert_eq(goblins, 2, "石头人亡语：死后裂出 2 哥布林")

func test_death_spawn_never_lands_in_water() -> void:
	var loader = _loader()
	var battle = BattleScript.new()
	var arena = battle.build_arena(loader.get_level("level_01"), loader.get_arena("default"))
	var skill = SkillSystemScript.new(loader, battle)
	skill.play_card("golem", UnitScript.OWNER_PLAYER, Vector2(9, 20))
	var golem = arena.get_units()[0]
	golem.pos = Vector2(14.7, 15.5)            # 右桥边缘/水边：裂兵 off 会溢出到水
	golem.take_damage(golem.max_hp)
	arena.tick(0.1)                            # _remove_dead → 亡语生成（应钳到地面）
	var checked := 0
	for u in arena.get_units():
		if u.unit_id == "goblin_body":
			checked += 1
			assert_true(arena.is_ground_walkable_at(u.pos),
				"亡语裂兵钳到可走地面、不落水; pos=(%.2f,%.2f)" % [u.pos.x, u.pos.y])
	assert_eq(checked, 2, "两只裂兵都已校验落点")
