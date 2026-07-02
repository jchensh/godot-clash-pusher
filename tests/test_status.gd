# T3 状态效果（status: slow/stun/freeze）测试。
# 覆盖：施加+衰减过期 / slow 行动乘区 / stun·freeze 停动停攻 / 硬控不被 slow 覆盖 /
#       slow 减慢冷却恢复 / on_hit_status 命中施加 / 眩晕不造成伤害 / 法术 freeze /
#       slow 减少推进距离 / 无状态零回归。
extends "res://tests/test_case.gd"

const ArenaScript = preload("res://logic/arena.gd")
const BattleScript = preload("res://logic/battle.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const SkillSystemScript = preload("res://logic/skill_system.gd")
const UnitScript = preload("res://logic/unit.gd")

func _mk(dmg: float = 10.0, move: float = 2.0) -> Unit:
	return UnitScript.new("u", UnitScript.OWNER_PLAYER, {
		"hp": 100.0, "damage": dmg, "attack_speed": 1.0, "move_speed": move,
		"attack_range": 1.5, "aggro_radius": 5.0, "target_type": "ground", "attack_targets": "ground",
	}, Vector2.ZERO)

func _terrain_arena():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var a = ArenaScript.new()
	a.setup(loader.get_arena("default"))
	return a

func _battle_arena():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	var arena = battle.build_arena(loader.get_level("level_01"), loader.get_arena("default"))
	return [battle, arena]

func _add(arena, owner: int, pos: Vector2, cfg: Dictionary):
	var u = UnitScript.new("u", owner, cfg, pos)
	arena.add_unit(u)
	return u

func _still(arena, pos: Vector2, hp: float = 300.0):
	return _add(arena, UnitScript.OWNER_OPPONENT, pos, {
		"hp": hp, "damage": 0.0, "attack_speed": 1.0, "move_speed": 0.0,
		"attack_range": 1.0, "aggro_radius": 0.0, "target_type": "ground",
	})

# —— 单位层：状态基本行为 ——

func test_slow_apply_and_expire() -> void:
	var u = _mk()
	u.apply_status("slow", 1.0, 0.5)
	assert_true(u.has_status(), "施加后有状态")
	assert_almost_eq(u.action_speed_mult(), 0.5, 0.0001, "slow 0.5 → 行动 0.5×")
	u.tick_status(0.6)
	assert_true(u.has_status(), "0.6s 后仍在")
	u.tick_status(0.6)
	assert_false(u.has_status(), "累计 1.2s>1.0 → 过期")
	assert_almost_eq(u.action_speed_mult(), 1.0, 0.0001, "过期后恢复 1.0")

func test_stun_zeroes_action_and_blocks_attack() -> void:
	var u = _mk(50.0)
	assert_true(u.can_attack(), "初始可攻击（首击免费）")
	u.apply_status("stun", 0.5, 0.0)
	assert_true(u.is_stunned(), "眩晕中")
	assert_almost_eq(u.action_speed_mult(), 0.0, 0.0001, "stun → 行动 0")
	assert_false(u.can_attack(), "眩晕期间不能攻击")
	u.tick_status(0.6)
	assert_false(u.is_stunned(), "过期")
	assert_true(u.can_attack(), "恢复可攻击")

func test_freeze_is_hard_cc() -> void:
	var u = _mk()
	u.apply_status("freeze", 1.0, 0.0)
	assert_true(u.is_stunned(), "freeze 也是硬控")
	assert_almost_eq(u.action_speed_mult(), 0.0, 0.0001, "冻结 → 行动 0")

func test_hard_cc_not_downgraded_by_slow() -> void:
	var u = _mk()
	u.apply_status("stun", 1.0, 0.0)
	u.apply_status("slow", 1.0, 0.5)   # 不应顶掉 stun
	assert_true(u.is_stunned(), "硬控期间 slow 不覆盖")
	assert_almost_eq(u.action_speed_mult(), 0.0, 0.0001, "仍为 stun(0)")

func test_slow_slows_cooldown_recovery() -> void:
	var a = _mk(10.0)
	a.mark_attacked()
	a.tick_cooldown(1.0)
	assert_true(a.can_attack(), "正常单位 1.0s 冷却恢复完")
	var b = _mk(10.0)
	b.mark_attacked()
	b.apply_status("slow", 10.0, 0.5)   # 0.5× 恢复
	b.tick_cooldown(1.0)
	assert_false(b.can_attack(), "减速单位同 dt 冷却未恢复完(0.5×)")

func test_fresh_unit_zero_regression() -> void:
	var u = _mk()
	assert_almost_eq(u.action_speed_mult(), 1.0, 0.0001, "无状态 → 行动 1.0（零回归）")
	assert_false(u.is_stunned(), "无状态不眩晕")
	assert_true(u.can_attack(), "无状态可攻击")

# —— 集成：on_hit / 法术 / 移动 ——

func test_on_hit_status_slows_target() -> void:
	var arena = _terrain_arena()
	_add(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20), {
		"hp": 100.0, "damage": 10.0, "attack_speed": 1.0, "move_speed": 0.0,
		"attack_range": 1.5, "aggro_radius": 5.0, "target_type": "ground", "attack_targets": "ground",
		"on_hit_status": {"kind": "slow", "dur": 2.0, "mag": 0.35},
	})
	var foe = _still(arena, Vector2(9, 20.8))
	arena.tick(0.1)
	assert_true(foe.has_status(), "被命中后目标带状态")
	assert_almost_eq(foe.action_speed_mult(), 0.65, 0.0001, "on-hit slow 0.35 → 0.65×")

func test_stunned_attacker_deals_no_damage() -> void:
	var arena = _terrain_arena()
	var atk = _add(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20), {
		"hp": 100.0, "damage": 50.0, "attack_speed": 1.0, "move_speed": 0.0,
		"attack_range": 1.5, "aggro_radius": 5.0, "target_type": "ground", "attack_targets": "ground",
	})
	var foe = _still(arena, Vector2(9, 20.8))
	atk.apply_status("stun", 1.0, 0.0)
	arena.tick(0.1)
	assert_almost_eq(foe.hp, 300.0, 0.0001, "被眩晕的攻击者本 tick 不造成伤害")
	for i in 12:
		arena.tick(0.1)   # 累计 >1.0s 眩晕过期
	assert_true(foe.hp < 300.0, "眩晕结束后恢复攻击、造成伤害")

func test_spell_status_freezes_enemy() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var skill = SkillSystemScript.new(loader, battle)
	var foe = _still(arena, Vector2(9, 10))
	# freeze 术 = aoe_damage 带 status（damage 0 + freeze）。
	skill._aoe_damage({"radius": 3.0, "damage": 0.0, "status": {"kind": "freeze", "dur": 2.0}},
		UnitScript.OWNER_PLAYER, Vector2(9, 10))
	assert_true(foe.is_stunned(), "冻结法术使范围内敌兵进入硬控")
	assert_almost_eq(foe.action_speed_mult(), 0.0, 0.0001, "冻结 → 行动 0")

func test_slow_reduces_movement_distance() -> void:
	var ctx = _battle_arena()
	var battle = ctx[0]
	var arena = ctx[1]
	# 用飞兵直线越河（避免地面兵绕桥导致 y 进度非单调的干扰），纯测 slow 减少推进距离。
	var base_cfg := {
		"hp": 100000.0, "damage": 0.0, "attack_speed": 1.0, "move_speed": 3.0,
		"attack_range": 1.0, "aggro_radius": 0.0, "target_type": "air", "attack_targets": "both",
	}
	var fast = _add(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20), base_cfg)
	var slow = _add(arena, UnitScript.OWNER_PLAYER, Vector2(9, 20), base_cfg)
	slow.apply_status("slow", 100.0, 0.5)   # 半速、持续够长
	for i in 20:
		battle.step(0.1)
	assert_true(fast.pos.y < slow.pos.y - 1.0,
		"减速飞兵朝敌塔推进更少(y 更大); fast.y=%.1f slow.y=%.1f" % [fast.pos.y, slow.pos.y])
