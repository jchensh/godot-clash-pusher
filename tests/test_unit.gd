# Step 4 测试：Unit 运行时状态（血量、位置、方向、攻击冷却）。
extends "res://tests/test_case.gd"

const UnitScript = preload("res://logic/unit.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

func _unit_config(
		hp: float = 100.0,
		damage: float = 10.0,
		attack_speed: float = 1.0,
		move_speed: float = 0.2,
		attack_range: float = 0.1,
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
	var u = UnitScript.new("soldier", UnitScript.OWNER_PLAYER, 2, _unit_config(), 0.25)
	assert_eq(u.unit_id, "soldier", "记录 unit id")
	assert_eq(u.owner_id, UnitScript.OWNER_PLAYER, "记录 owner")
	assert_eq(u.lane_index, 2, "记录 lane")
	assert_almost_eq(u.progress, 0.25, 0.0001, "记录 lane 进度")
	assert_almost_eq(u.hp, 100.0, 0.0001, "初始血量来自 max hp")
	assert_almost_eq(u.attack_range, 0.1, 0.0001, "攻击范围为 lane 比例")

func test_progress_clamped_to_lane_range() -> void:
	var left = UnitScript.new("left", UnitScript.OWNER_PLAYER, 0, _unit_config(), -1.0)
	var right = UnitScript.new("right", UnitScript.OWNER_PLAYER, 0, _unit_config(), 2.0)
	assert_almost_eq(left.progress, 0.0, 0.0001, "进度下限 0")
	assert_almost_eq(right.progress, 1.0, 0.0001, "进度上限 1")

func test_owner_direction() -> void:
	var player_unit = UnitScript.new("p", UnitScript.OWNER_PLAYER, 0, _unit_config(), 0.0)
	var opponent_unit = UnitScript.new("o", UnitScript.OWNER_OPPONENT, 0, _unit_config(), 1.0)
	assert_eq(player_unit.get_direction(), 1, "玩家侧从 0 向 1 推进")
	assert_eq(opponent_unit.get_direction(), -1, "对手侧从 1 向 0 推进")

func test_take_damage_and_death() -> void:
	var u = UnitScript.new("soldier", UnitScript.OWNER_PLAYER, 0, _unit_config(30.0), 0.0)
	u.take_damage(12.0)
	assert_almost_eq(u.hp, 18.0, 0.0001, "扣血")
	assert_true(u.is_alive(), "未死亡")
	u.take_damage(100.0)
	assert_almost_eq(u.hp, 0.0, 0.0001, "血量不小于 0")
	assert_false(u.is_alive(), "死亡")

func test_attack_cooldown_uses_attack_speed_as_interval() -> void:
	var u = UnitScript.new("soldier", UnitScript.OWNER_PLAYER, 0, _unit_config(100.0, 10.0, 1.2), 0.0)
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
	var u = UnitScript.new("minion_body", UnitScript.OWNER_PLAYER, 0, cfg, 0.0)
	assert_eq(u.target_type, "air", "target_type 表示单位自身类型")
	assert_true(u.attack_range >= 0.0 and u.attack_range <= 1.0, "真实配置 attack_range 在 lane 比例范围内")
