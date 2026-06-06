# Step 6 测试：SkillSystem 三积木（spawn_unit / direct_damage / aoe_damage）。
extends "res://tests/test_case.gd"

const SkillSystemScript = preload("res://logic/skill_system.gd")
const BattleScript = preload("res://logic/battle.gd")
const UnitScript = preload("res://logic/unit.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _setup_battle():
	# 返回 [loader, battle, lane, skill]，lane 已接双方王塔（含整套配置）。
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	var lane = battle.build_v1_single_lane(loader.get_level("level_01"))
	var skill = SkillSystemScript.new(loader, battle)
	return [loader, battle, lane, skill]

func _unit_config(hp: float = 300.0, progress_unused: float = 0.0) -> Dictionary:
	return {
		"hp": hp, "damage": 10.0, "attack_speed": 1.0,
		"move_speed": 0.0, "attack_range": 0.05, "target_type": "ground",
	}

func _add_unit(lane, owner: int, progress: float, hp: float = 300.0):
	var u = UnitScript.new("dummy", owner, 0, _unit_config(hp), progress)
	lane.add_unit(u)
	return u

# —— spawn_unit ——

func test_spawn_unit_adds_count_units() -> void:
	var ctx = _setup_battle()
	var lane = ctx[2]
	var skill = ctx[3]
	var ok = skill.play_card("goblins", UnitScript.OWNER_PLAYER, 0, 0.1)   # goblins: count 3
	assert_true(ok, "卡存在并执行")
	assert_eq(lane.get_units().size(), 3, "生成 3 个哥布林")

func test_spawn_unit_sets_owner_unit_and_progress() -> void:
	var ctx = _setup_battle()
	var lane = ctx[2]
	var skill = ctx[3]
	skill.play_card("knight", UnitScript.OWNER_PLAYER, 0, 0.15)   # knight: knight_body count 1
	var units = lane.get_units()
	assert_eq(units.size(), 1, "生成 1 个骑士")
	assert_eq(units[0].unit_id, "knight_body", "unit_id 正确")
	assert_eq(units[0].owner_id, UnitScript.OWNER_PLAYER, "owner 为出牌方")
	assert_almost_eq(units[0].progress, 0.15, 0.0001, "在出牌位置生成")

func test_spawn_unknown_unit_is_noop() -> void:
	var ctx = _setup_battle()
	var loader = ctx[0]
	var lane = ctx[2]
	var skill = ctx[3]
	loader.cards["bad_spawn"] = {"elixir_cost": 1, "skills": [{"type": "spawn_unit", "unit_id": "no_such_unit", "count": 2}]}
	var ok = skill.play_card("bad_spawn", UnitScript.OWNER_PLAYER, 0, 0.1)
	assert_true(ok, "卡存在")
	assert_eq(lane.get_units().size(), 0, "未知单位不生成")

# —— direct_damage ——

func test_direct_damage_player_hits_frontmost_enemy() -> void:
	var ctx = _setup_battle()
	var lane = ctx[2]
	var skill = ctx[3]
	var front = _add_unit(lane, UnitScript.OWNER_OPPONENT, 0.3)   # 离玩家塔(0)更近 → first
	var back = _add_unit(lane, UnitScript.OWNER_OPPONENT, 0.6)
	skill.play_card("arrows", UnitScript.OWNER_PLAYER, 0)         # arrows: direct_damage 150
	assert_almost_eq(front.hp, 150.0, 0.0001, "最逼近玩家塔的敌人中招")
	assert_almost_eq(back.hp, 300.0, 0.0001, "较后的敌人不中招")

func test_direct_damage_opponent_hits_frontmost_enemy() -> void:
	var ctx = _setup_battle()
	var lane = ctx[2]
	var skill = ctx[3]
	var back = _add_unit(lane, UnitScript.OWNER_PLAYER, 0.4)
	var front = _add_unit(lane, UnitScript.OWNER_PLAYER, 0.7)     # 离对手塔(1)更近 → first
	skill.play_card("arrows", UnitScript.OWNER_OPPONENT, 0)
	assert_almost_eq(front.hp, 150.0, 0.0001, "最逼近对手塔的敌人中招")
	assert_almost_eq(back.hp, 300.0, 0.0001, "较后的敌人不中招")

func test_direct_damage_no_enemy_is_noop() -> void:
	var ctx = _setup_battle()
	var lane = ctx[2]
	var skill = ctx[3]
	var friendly = _add_unit(lane, UnitScript.OWNER_PLAYER, 0.5)   # 只有己方
	var ok = skill.play_card("arrows", UnitScript.OWNER_PLAYER, 0)
	assert_true(ok, "卡存在")
	assert_almost_eq(friendly.hp, 300.0, 0.0001, "无敌方 → 空放，不误伤己方")

# —— aoe_damage ——

func test_aoe_hits_enemies_within_radius() -> void:
	var ctx = _setup_battle()
	var loader = ctx[0]
	var lane = ctx[2]
	var skill = ctx[3]
	loader.cards["aoe_small"] = {"elixir_cost": 4, "skills": [{"type": "aoe_damage", "radius": 0.2, "damage": 100}]}
	var at_center = _add_unit(lane, UnitScript.OWNER_OPPONENT, 0.5)
	var at_edge = _add_unit(lane, UnitScript.OWNER_OPPONENT, 0.7)    # 距中心 0.2，边界含入
	var outside = _add_unit(lane, UnitScript.OWNER_OPPONENT, 0.9)    # 距中心 0.4，不含
	skill.play_card("aoe_small", UnitScript.OWNER_PLAYER, 0, 0.5)
	assert_almost_eq(at_center.hp, 200.0, 0.0001, "圆心敌人中招")
	assert_almost_eq(at_edge.hp, 200.0, 0.0001, "范围边界敌人中招")
	assert_almost_eq(outside.hp, 300.0, 0.0001, "范围外敌人不中招")

func test_aoe_excludes_friendly() -> void:
	var ctx = _setup_battle()
	var lane = ctx[2]
	var skill = ctx[3]
	var enemy = _add_unit(lane, UnitScript.OWNER_OPPONENT, 0.5, 600.0)
	var friendly = _add_unit(lane, UnitScript.OWNER_PLAYER, 0.5, 600.0)
	skill.play_card("fireball", UnitScript.OWNER_PLAYER, 0, 0.5)     # fireball: aoe 300，radius 1.5
	assert_almost_eq(enemy.hp, 300.0, 0.0001, "敌方中招")
	assert_almost_eq(friendly.hp, 600.0, 0.0001, "己方不被误伤")

# —— 多积木 ——

func test_multi_block_executes_all_blocks_in_order() -> void:
	var ctx = _setup_battle()
	var loader = ctx[0]
	var lane = ctx[2]
	var skill = ctx[3]
	# 自定义叠积木卡：先 AOE 炸中心，再生成一个骑士。
	loader.cards["combo"] = {"elixir_cost": 5, "skills": [
		{"type": "aoe_damage", "radius": 0.05, "damage": 1000},
		{"type": "spawn_unit", "unit_id": "knight_body", "count": 1},
	]}
	var enemy = _add_unit(lane, UnitScript.OWNER_OPPONENT, 0.5)
	skill.play_card("combo", UnitScript.OWNER_PLAYER, 0, 0.5)
	assert_almost_eq(enemy.hp, 0.0, 0.0001, "第一个积木：AOE 命中敌人")
	var has_knight := false
	for u in lane.get_units():
		if u.unit_id == "knight_body" and u.owner_id == UnitScript.OWNER_PLAYER:
			has_knight = true
	assert_true(has_knight, "第二个积木：生成了骑士")

# —— 未知卡 / 集成 ——

func test_unknown_card_returns_false() -> void:
	var ctx = _setup_battle()
	var skill = ctx[3]
	assert_false(skill.play_card("no_such_card", UnitScript.OWNER_PLAYER, 0), "未知卡返回 false")

func test_real_card_in_battle_then_steps() -> void:
	var ctx = _setup_battle()
	var battle = ctx[1]
	var lane = ctx[2]
	var skill = ctx[3]
	skill.play_card("knight", UnitScript.OWNER_PLAYER, 0, 0.1)
	assert_eq(lane.get_units().size(), 1, "骑士已部署到对局 lane")
	for i in 10:
		battle.step(0.1)
	assert_true(lane.get_units()[0].progress > 0.1, "随对局推进，骑士向敌方塔移动")
