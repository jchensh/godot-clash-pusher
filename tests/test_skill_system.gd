# V3-1b 测试：SkillSystem 三积木 2D 版（spawn_unit / direct_damage / aoe_damage）。
extends "res://tests/test_case.gd"

const SkillSystemScript = preload("res://logic/skill_system.gd")
const BattleScript = preload("res://logic/battle.gd")
const UnitScript = preload("res://logic/unit.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

# 返回 [loader, battle, skill]，battle 已建 2D arena（含整套配置）。
func _setup_battle():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	battle.build_arena(loader.get_level("level_01"), loader.get_arena("default"))
	var skill = SkillSystemScript.new(loader, battle)
	return [loader, battle, skill]

func _unit_config(hp: float = 300.0) -> Dictionary:
	return {
		"hp": hp, "damage": 10.0, "attack_speed": 1.0,
		"move_speed": 1.8, "attack_range": 1.0, "target_type": "ground",
	}

func _add_unit(battle, owner: int, pos: Vector2, hp: float = 300.0):
	var u = UnitScript.new("dummy", owner, _unit_config(hp), pos)
	battle.arena.add_unit(u)
	return u

# —— spawn_unit ——

func test_spawn_unit_adds_count_units() -> void:
	var ctx = _setup_battle()
	var battle = ctx[1]
	var skill = ctx[2]
	var ok = skill.play_card("goblins", UnitScript.OWNER_PLAYER, Vector2(9, 20))   # goblins: count 3
	assert_true(ok, "卡存在并执行")
	assert_eq(battle.arena.get_units().size(), 3, "生成 3 个哥布林")

func test_spawn_unit_sets_owner_unit_and_pos() -> void:
	var ctx = _setup_battle()
	var battle = ctx[1]
	var skill = ctx[2]
	skill.play_card("knight", UnitScript.OWNER_PLAYER, Vector2(9, 20))   # knight: count 1
	var units = battle.arena.get_units()
	assert_eq(units.size(), 1, "生成 1 个骑士")
	assert_eq(units[0].unit_id, "knight_body", "unit_id 正确")
	assert_eq(units[0].owner_id, UnitScript.OWNER_PLAYER, "owner 为出牌方")
	assert_almost_eq(units[0].pos.x, 9.0, 0.0001, "在出牌点生成(x)")
	assert_almost_eq(units[0].pos.y, 20.0, 0.0001, "在出牌点生成(y)")

func test_spawn_unknown_unit_is_noop() -> void:
	var ctx = _setup_battle()
	var loader = ctx[0]
	var battle = ctx[1]
	var skill = ctx[2]
	loader.cards["bad_spawn"] = {"elixir_cost": 1, "skills": [{"type": "spawn_unit", "unit_id": "no_such_unit", "count": 2}]}
	var ok = skill.play_card("bad_spawn", UnitScript.OWNER_PLAYER, Vector2(9, 20))
	assert_true(ok, "卡存在")
	assert_eq(battle.arena.get_units().size(), 0, "未知单位不生成")

# —— direct_damage（命中最逼近出牌点的敌方单位）——

func test_direct_damage_hits_nearest_enemy_to_point() -> void:
	var ctx = _setup_battle()
	var battle = ctx[1]
	var skill = ctx[2]
	var near = _add_unit(battle, UnitScript.OWNER_OPPONENT, Vector2(9, 12))
	var far = _add_unit(battle, UnitScript.OWNER_OPPONENT, Vector2(9, 4))
	skill.play_card("lightning", UnitScript.OWNER_PLAYER, Vector2(9, 12.5))   # lightning: direct 280
	assert_almost_eq(near.hp, 20.0, 0.0001, "最近敌人中招(300-280)")
	assert_almost_eq(far.hp, 300.0, 0.0001, "较远敌人不中招")

func test_direct_damage_no_enemy_is_noop() -> void:
	var ctx = _setup_battle()
	var battle = ctx[1]
	var skill = ctx[2]
	var friendly = _add_unit(battle, UnitScript.OWNER_PLAYER, Vector2(9, 20))   # 只有己方
	var ok = skill.play_card("lightning", UnitScript.OWNER_PLAYER, Vector2(9, 20))
	assert_true(ok, "卡存在")
	assert_almost_eq(friendly.hp, 300.0, 0.0001, "无敌方 → 空放，不误伤己方")

# —— aoe_damage（2D 圆，半径 tile）——

func test_aoe_hits_enemies_within_radius() -> void:
	var ctx = _setup_battle()
	var loader = ctx[0]
	var battle = ctx[1]
	var skill = ctx[2]
	loader.cards["aoe_small"] = {"elixir_cost": 4, "skills": [{"type": "aoe_damage", "radius": 2.0, "damage": 100}]}
	var at_center = _add_unit(battle, UnitScript.OWNER_OPPONENT, Vector2(9, 12))
	var at_edge = _add_unit(battle, UnitScript.OWNER_OPPONENT, Vector2(9, 14))    # 距中心 2.0，边界含入
	var outside = _add_unit(battle, UnitScript.OWNER_OPPONENT, Vector2(9, 15))    # 距中心 3.0，不含
	skill.play_card("aoe_small", UnitScript.OWNER_PLAYER, Vector2(9, 12))
	assert_almost_eq(at_center.hp, 200.0, 0.0001, "圆心敌人中招")
	assert_almost_eq(at_edge.hp, 200.0, 0.0001, "范围边界敌人中招")
	assert_almost_eq(outside.hp, 300.0, 0.0001, "范围外敌人不中招")

func test_aoe_excludes_friendly() -> void:
	var ctx = _setup_battle()
	var battle = ctx[1]
	var skill = ctx[2]
	var enemy = _add_unit(battle, UnitScript.OWNER_OPPONENT, Vector2(9, 12), 600.0)
	var friendly = _add_unit(battle, UnitScript.OWNER_PLAYER, Vector2(9, 12), 600.0)
	skill.play_card("fireball", UnitScript.OWNER_PLAYER, Vector2(9, 12))     # fireball: aoe 300 / r3.0
	assert_almost_eq(enemy.hp, 300.0, 0.0001, "敌方中招")
	assert_almost_eq(friendly.hp, 600.0, 0.0001, "己方不被误伤")

# —— 多积木 ——

func test_multi_block_executes_all_blocks_in_order() -> void:
	var ctx = _setup_battle()
	var loader = ctx[0]
	var battle = ctx[1]
	var skill = ctx[2]
	# 自定义叠积木卡：先 AOE 炸中心，再生成一个骑士。
	loader.cards["combo"] = {"elixir_cost": 5, "skills": [
		{"type": "aoe_damage", "radius": 0.5, "damage": 1000},
		{"type": "spawn_unit", "unit_id": "knight_body", "count": 1},
	]}
	var enemy = _add_unit(battle, UnitScript.OWNER_OPPONENT, Vector2(9, 20))
	skill.play_card("combo", UnitScript.OWNER_PLAYER, Vector2(9, 20))
	assert_almost_eq(enemy.hp, 0.0, 0.0001, "第一个积木：AOE 命中敌人")
	var has_knight := false
	for u in battle.arena.get_units():
		if u.unit_id == "knight_body" and u.owner_id == UnitScript.OWNER_PLAYER:
			has_knight = true
	assert_true(has_knight, "第二个积木：生成了骑士")

# —— 未知卡 / 集成 ——

func test_unknown_card_returns_false() -> void:
	var ctx = _setup_battle()
	var skill = ctx[2]
	assert_false(skill.play_card("no_such_card", UnitScript.OWNER_PLAYER, Vector2(9, 20)), "未知卡返回 false")

func test_real_card_in_battle_then_steps() -> void:
	var ctx = _setup_battle()
	var battle = ctx[1]
	var skill = ctx[2]
	skill.play_card("knight", UnitScript.OWNER_PLAYER, Vector2(9, 20))
	assert_eq(battle.arena.get_units().size(), 1, "骑士已部署到 arena")
	var y0: float = battle.arena.get_units()[0].pos.y
	for i in 10:
		battle.step(0.1)
	assert_true(battle.arena.get_units()[0].pos.y < y0, "随对局推进，骑士向敌方塔(y 减小)移动")
