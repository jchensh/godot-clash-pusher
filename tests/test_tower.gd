# Step 5 测试：Tower 血量与摧毁判定（纯逻辑）。
extends "res://tests/test_case.gd"

const TowerScript = preload("res://logic/tower.gd")
const UnitScript = preload("res://logic/unit.gd")

func test_setup_kind_owner_hp() -> void:
	var king = TowerScript.new(TowerScript.KIND_KING, UnitScript.OWNER_PLAYER, 2400.0)
	assert_true(king.is_king(), "king 类型")
	assert_eq(king.owner_id, UnitScript.OWNER_PLAYER, "owner")
	assert_almost_eq(king.hp, 2400.0, 0.0001, "初始满血")
	assert_almost_eq(king.max_hp, 2400.0, 0.0001, "max_hp")
	assert_true(king.is_alive(), "存活")
	assert_false(king.is_destroyed(), "未摧毁")

func test_princess_is_not_king() -> void:
	var p = TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_OPPONENT, 1400.0)
	assert_false(p.is_king(), "公主塔非王塔")
	assert_eq(p.owner_id, UnitScript.OWNER_OPPONENT, "owner")

func test_take_damage_reduces_hp() -> void:
	var t = TowerScript.new(TowerScript.KIND_KING, UnitScript.OWNER_PLAYER, 1000.0)
	t.take_damage(300.0)
	assert_almost_eq(t.hp, 700.0, 0.0001, "扣血")
	assert_true(t.is_alive(), "仍存活")

func test_hp_clamped_and_destroyed() -> void:
	var t = TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_OPPONENT, 100.0)
	t.take_damage(250.0)
	assert_almost_eq(t.hp, 0.0, 0.0001, "血量不为负")
	assert_false(t.is_alive(), "已死")
	assert_true(t.is_destroyed(), "已摧毁")

func test_nonpositive_damage_noop() -> void:
	var t = TowerScript.new(TowerScript.KIND_KING, UnitScript.OWNER_PLAYER, 500.0)
	t.take_damage(0.0)
	t.take_damage(-50.0)
	assert_almost_eq(t.hp, 500.0, 0.0001, "零/负伤害不改血量")

func test_damage_after_destroyed_noop() -> void:
	var t = TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_PLAYER, 50.0)
	t.take_damage(50.0)
	t.take_damage(100.0)
	assert_almost_eq(t.hp, 0.0, 0.0001, "摧毁后再受击仍为 0")
