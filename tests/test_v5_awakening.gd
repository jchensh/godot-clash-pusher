# KAN-86：epic+legendary signature 觉醒（rank_unlocks 的 unit_field/set_field/num_add ops）
# → effective_skills 正确 + 运行时真生效（余烬火颅溅射变大+减速、雷暴命中眩晕）。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const CardProgressionScript = preload("res://logic/card_progression.gd")
const BattleScript = preload("res://logic/battle.gd")
const SkillSystemScript = preload("res://logic/skill_system.gd")
const UnitScript = preload("res://logic/unit.gd")

var _cfg
func _config():
	if _cfg == null:
		_cfg = ConfigLoaderScript.new()
		_cfg.load_all()
	return _cfg

func _eff(cid: String, rank: int) -> Array:
	var c = _config()
	return CardProgressionScript.effective_skills(
		c.get_card(cid).get("skills"), c.get_card_progression(cid).get("rank_unlocks"), rank)

# —— effective_skills：觉醒 ops 正确叠加 ——

func test_baby_dragon_awaken_splash_and_slow() -> void:
	var ov: Dictionary = _eff("baby_dragon", 3)[0].get("_unit_override", {})
	assert_almost_eq(float(ov.get("splash_radius", 0.0)), 2.5, 0.001, "烈焰吐息：splash→2.5")
	assert_eq(str((ov.get("on_hit_status", {}) as Dictionary).get("kind")), "slow", "命中附带减速")

func test_lightning_awaken_set_field_stun() -> void:
	var blk: Dictionary = _eff("lightning", 3)[0]
	assert_almost_eq(float(blk.get("damage")), 340.0, 0.001, "rank2 伤害 280+60=340")
	assert_eq(str((blk.get("status", {}) as Dictionary).get("kind")), "stun", "雷暴：set_field 加眩晕")

func test_freeze_awaken_num_add_damage() -> void:
	var blk: Dictionary = _eff("freeze", 3)[0]
	assert_almost_eq(float(blk.get("damage")), 200.0, 0.001, "绝对零度：冻结附伤 0+200")
	assert_almost_eq(float(blk.get("radius")), 3.5, 0.001, "rank2 半径 3.0+0.5")

func test_golem_awaken_golemite() -> void:
	var ov: Dictionary = _eff("golem", 3)[0].get("_unit_override", {})
	assert_eq(str(ov.get("death_spawn_unit")), "golemite_body", "崩解：死裂变石心魔像")
	assert_eq(int(ov.get("death_spawn_count", 0)), 3, "rank2 死裂数 3 仍在")

func test_musketeer_awaken_on_hit_slow() -> void:
	var ov: Dictionary = _eff("musketeer", 3)[0].get("_unit_override", {})
	assert_eq(str((ov.get("on_hit_status", {}) as Dictionary).get("kind")), "slow", "破法弹：命中减速")

func test_deferred_awaken_is_noop() -> void:
	# 留 KAN-88 的（balloon/electro_wizard/inferno_dragon）rank3 无 ops → effective 同 base。
	for cid in ["balloon", "electro_wizard", "inferno_dragon"]:
		assert_eq(_eff(cid, 3).size(), (_config().get_card(cid).get("skills") as Array).size(),
			"%s rank3 占位不改积木" % cid)

# —— 运行时：觉醒真生效 ——

func _fresh():
	var c = _config()
	var b = BattleScript.new()
	var a = b.build_arena(c.get_level("level_01"), c.get_arena("default"))
	return [a, SkillSystemScript.new(c, b)]

func test_runtime_baby_dragon_splashes_wider_and_slows() -> void:
	var ctx = _fresh()
	ctx[1].play_card("baby_dragon", UnitScript.OWNER_PLAYER, Vector2(9, 20), 1.0, _eff("baby_dragon", 3))
	var bd = null
	for u in (ctx[0].get_units() as Array):
		if u.unit_id == "baby_dragon_body": bd = u
	assert_not_null(bd, "余烬火颅入场")
	assert_almost_eq(bd.splash_radius, 2.5, 0.001, "觉醒 splash 2.5(基础 1.5)")
	assert_true(not (bd.on_hit_status as Dictionary).is_empty(), "觉醒带命中减速")

func test_runtime_lightning_stuns_enemy() -> void:
	var ctx = _fresh()
	var foe = UnitScript.new("foe", UnitScript.OWNER_OPPONENT, {"hp": 500.0, "damage": 0.0,
		"attack_speed": 1.0, "move_speed": 0.0, "attack_range": 1.0, "aggro_radius": 0.0,
		"target_type": "ground"}, Vector2(9, 20))
	ctx[0].add_unit(foe)
	ctx[1].play_card("lightning", UnitScript.OWNER_PLAYER, Vector2(9, 20), 1.0, _eff("lightning", 3))
	assert_true(foe.hp < 500.0, "雷暴命中掉血")
	assert_true(foe.is_stunned(), "雷暴觉醒：命中敌方眩晕")
