# V3-1b 测试：Unit 2D 运行时状态（血量、2D 位置、攻击冷却）。
extends "res://tests/test_case.gd"

const UnitScript = preload("res://logic/unit.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _unit_config(
		hp: float = 100.0,
		damage: float = 10.0,
		attack_speed: float = 1.0,
		move_speed: float = 1.8,
		attack_range: float = 1.0,
		target_type: String = "ground"
) -> Dictionary:
	return {
		"hp": hp,
		"damage": damage,
		"attack_speed": attack_speed,
		"move_speed": move_speed,
		"attack_range": attack_range,
		"target_type": target_type,
	}

func test_setup_from_config() -> void:
	var u = UnitScript.new("soldier", UnitScript.OWNER_PLAYER, _unit_config(), Vector2(4, 20))
	assert_eq(u.unit_id, "soldier", "记录 unit id")
	assert_eq(u.owner_id, UnitScript.OWNER_PLAYER, "记录 owner")
	assert_almost_eq(u.pos.x, 4.0, 0.0001, "记录 2D 位置 x")
	assert_almost_eq(u.pos.y, 20.0, 0.0001, "记录 2D 位置 y")
	assert_almost_eq(u.hp, 100.0, 0.0001, "初始血量来自 max hp")
	assert_almost_eq(u.attack_range, 1.0, 0.0001, "攻击范围为 tile 距离")
	assert_almost_eq(u.move_speed, 1.8, 0.0001, "移动速度为 tile/秒")

func test_is_enemy() -> void:
	var p = UnitScript.new("p", UnitScript.OWNER_PLAYER, _unit_config(), Vector2(4, 20))
	var o = UnitScript.new("o", UnitScript.OWNER_OPPONENT, _unit_config(), Vector2(4, 10))
	assert_true(p.is_enemy(o), "异主为敌")
	assert_false(p.is_enemy(p), "同主非敌")

func test_take_damage_and_death() -> void:
	var u = UnitScript.new("soldier", UnitScript.OWNER_PLAYER, _unit_config(30.0), Vector2(4, 20))
	u.take_damage(12.0)
	assert_almost_eq(u.hp, 18.0, 0.0001, "扣血")
	assert_true(u.is_alive(), "未死亡")
	u.take_damage(100.0)
	assert_almost_eq(u.hp, 0.0, 0.0001, "血量不小于 0")
	assert_false(u.is_alive(), "死亡")

func test_attack_cooldown_uses_attack_speed_as_interval() -> void:
	var u = UnitScript.new("soldier", UnitScript.OWNER_PLAYER, _unit_config(100.0, 10.0, 1.2), Vector2(4, 20))
	assert_true(u.can_attack(), "初始可攻击")
	u.mark_attacked()
	assert_false(u.can_attack(), "攻击后进入冷却")
	u.tick_cooldown(0.6)
	assert_false(u.can_attack(), "冷却未满不能攻击")
	u.tick_cooldown(0.6)
	assert_true(u.can_attack(), "attack_speed 秒后可再次攻击")

func test_with_real_config_unit() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var cfg = loader.get_unit("minion_body")
	var u = UnitScript.new("minion_body", UnitScript.OWNER_PLAYER, cfg, Vector2(9, 20))
	assert_eq(u.target_type, "air", "target_type 表示单位自身类型")
	assert_true(u.attack_range >= 0.0, "真实配置 attack_range ≥ 0（tile 距离，无上限）")
