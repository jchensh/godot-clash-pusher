## D8：3D 战斗特效层——法术/远程单位目录全覆盖、法术经出牌钩子放（链上原观察者照常）、投射物/放电/光束按单位出、
## 直伤劈在实际目标、状态挂件随状态出没、塔毁爆破、伤害数字头顶锚点跟随；特效只读：挂与不挂逐帧 hash 全等。
extends "res://tests/test_case.gd"

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const UnitScript := preload("res://logic/unit.gd")
const PveRecorderScript := preload("res://net/pve_recorder.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")
const BattleField3D := preload("res://view/three_d/battle_field_3d.gd")
const Catalog := preload("res://view/three_d/fx_catalog.gd")
const FxMesh := preload("res://view/three_d/fx_mesh.gd")

const DECK := ["fireball", "arrows", "zap", "knight", "archers", "giant", "goblins", "minions"]
const STAGE := "stage_1_1"
const SCREEN := Vector2(750, 1334)
const RANGED_MIN := 2.0      # 射程 ≥ 此值的单位必须登记攻击表现

var _loader = null


func _config():
	if _loader == null:
		_loader = Loader.new()
		_loader.load_all()
	return _loader


func _new_match(ai := true):
	var m = MatchScript.new(_config())
	m.setup_stage(STAGE, DECK, null, {})
	if ai:
		m.set_opponent_controller(AIControllerScript.new(m, _config(), m.ai_difficulty))
	return m


func _field(m, hook := true):
	var field = BattleField3D.new()
	var opts := {"lighting": false}
	if hook:
		opts["players"] = [m.player, m.opponent]
	field.setup(m.battle, _config(), SCREEN, 54.0, 176.0, opts)
	return field


func _dispose(field) -> void:
	field.presenter.clear()
	field.free()


func _unit(m, unit_id: String, owner: int, pos: Vector2):
	var u = UnitScript.new(unit_id, owner, _config().get_unit(unit_id), pos)
	m.battle.arena.add_unit(u)
	return u


func _step(m, field, seconds: float, dt := 0.1) -> void:
	for i in int(round(seconds / dt)):
		m.battle.step(dt)
		field.advance(dt)


func test_catalog_covers_every_spell_and_ranged_unit() -> void:
	var cfg = _config()
	for cid in cfg.cards:
		var damaging := false
		var spawns := false
		for sk in cfg.get_card(cid).get("skills", []):
			var t := str(sk.get("type", ""))
			damaging = damaging or t in ["aoe_damage", "direct_damage", "aoe_heal"]
			spawns = spawns or t == "spawn_unit"
		if damaging:
			assert_true(Catalog.SPELLS.has(cid), "法术/带伤害的卡 %s 必须有专属特效" % cid)
		elif spawns:
			assert_eq(Catalog.spell_kind(cfg, cid), "spawn", "兵牌 %s 落地尘土" % cid)
	for uid in cfg.units:
		if float(cfg.get_unit(uid).get("attack_range", 0.0)) >= RANGED_MIN:
			assert_true(Catalog.ATTACKS.has(uid), "射程 ≥2 的单位 %s 必须登记攻击表现" % uid)
	for uid in Catalog.ATTACKS:
		assert_false(cfg.get_unit(uid).is_empty(), "攻击表登记的 %s 应是真实单位" % uid)
		var spec: Dictionary = Catalog.ATTACKS[uid]
		assert_true(str(spec["type"]) in ["proj", "bolt", "beam", "melee"], "%s 攻击类型合法" % uid)
		if spec["type"] == "proj":
			assert_true(FxMesh.NAMES.has(spec["mesh"]), "%s 投射物网格已登记" % uid)
	for mesh_name in FxMesh.NAMES:
		var mesh: ArrayMesh = FxMesh.get_mesh(mesh_name)
		assert_eq(mesh.get_surface_count(), 1, "%s 单 surface（单材质）" % mesh_name)
		var arrays := mesh.surface_get_arrays(0)
		assert_true((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0, "%s 带顶点色（走 toon 着色）" % mesh_name)
		assert_true((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 <= 400, "%s 面数 ≤400" % mesh_name)


func test_every_spell_builds_effect_and_cleans_up() -> void:
	var m = _new_match(false)
	var field = _field(m)
	_unit(m, "knight_body", 1, Vector2(13.0, 22.0))
	field.advance(0.0)
	for cid in Catalog.SPELLS:
		var before: int = field.fx.active_parts()
		field.fx.cast(cid, 0, Vector2(13.0, 21.5))
		assert_true(field.fx.active_parts() > before, "%s 应放出特效件" % cid)
		assert_eq(int(field.fx.stats["casts"].get(Catalog.SPELLS[cid], 0)), 1, "%s 计入对应特效" % cid)
	field.fx.cast("knight", 0, Vector2(13.0, 26.0))
	assert_eq(int(field.fx.stats["casts"].get("spawn", 0)), 1, "兵牌落地尘土")
	for i in 40:
		field.advance(0.1)
	assert_eq(field.fx.active_parts(), 0, "4 秒后全部特效播完释放")
	assert_eq(field.fx.get_child_count(), 0, "特效节点不残留")
	_dispose(field)


func test_direct_damage_strikes_the_real_target() -> void:
	var m = _new_match(false)
	var field = _field(m)
	var near = _unit(m, "knight_body", 1, Vector2(10.0, 20.0))
	_unit(m, "knight_body", 1, Vector2(16.0, 20.0))
	_unit(m, "knight_body", 0, Vector2(10.5, 20.0))   # 己方单位不算目标
	field.advance(0.0)
	var sp: Array = field.fx.strike_point(Vector2(11.0, 19.0), 0)
	var actor = field.presenter.actor_for(near)
	assert_true((sp[0] as Vector3).distance_to(actor.position) < 0.01, "电击/落雷劈在离落点最近的敌人身上")
	assert_almost_eq(float(sp[1]), actor.body_height, 0.001, "按目标身高定命中点")
	var empty = _new_match(false)
	var f2 = _field(empty)
	var sp2: Array = f2.fx.strike_point(Vector2(11.0, 19.0), 0)
	assert_true((sp2[0] as Vector3).distance_to(f2.fx.world(Vector2(11.0, 19.0))) < 0.01, "无敌人 = 空放在落点")
	_dispose(field)
	_dispose(f2)


func test_spells_fire_through_play_hook_and_keep_recorder() -> void:
	var m = _new_match(false)
	var rec = PveRecorderScript.new()
	rec.attach(m)
	var field = _field(m)
	m.player.elixir.current = 10.0
	var played := 0
	for i in 4:
		var hand: Array = m.player.deck.get_hand()
		for k in hand.size():
			if m.player.try_play_card(k, Vector2(13.0, 24.5)):
				played += 1
				break
		m.player.elixir.current = 10.0
	assert_true(played >= 2, "应打出多张牌（实得 %d）" % played)
	var casts := 0
	for k in field.fx.stats["casts"]:
		casts += int(field.fx.stats["casts"][k])
	assert_eq(casts, played, "每次出牌都经钩子触发一次特效")
	assert_eq(rec.cmds.size(), played, "原观察者（PVE 录制器）照常记录，不被钩子顶掉")
	field.setup(m.battle, _config(), SCREEN, 54.0, 176.0, {"lighting": false, "players": [m.player, m.opponent]})
	assert_true(m.player.play_observer is BattleField3D.Fx.CastHook, "重复 setup 复用钩子")
	assert_true(m.player.play_observer.prev == rec, "钩子不重复嵌套")
	_dispose(field)


func test_ranged_units_launch_matching_projectiles() -> void:
	var m = _new_match(false)
	var field = _field(m)
	for uid in Catalog.ATTACKS:
		var spec: Dictionary = Catalog.ATTACKS[uid]
		for u in m.battle.arena.units.duplicate():
			m.battle.arena.units.erase(u)
		var cfg: Dictionary = _config().get_unit(uid)
		var gap: float = clampf(float(cfg.get("attack_range", 1.0)) - 0.3, 0.6, 2.5)
		if str(cfg.get("target_priority", "")) == "buildings":   # 只打建筑的放到敌方箭塔射程边
			var tower = m.battle.opponent_towers[0] if not m.battle.opponent_towers[0].is_king() else m.battle.opponent_towers[1]
			_unit(m, uid, 0, tower.pos + Vector2(0.0, float(tower.fh) * 0.5 + gap))
		else:
			_unit(m, uid, 0, Vector2(13.0, 23.0))
			_unit(m, "golem_body", 1, Vector2(13.0, 23.0 - gap))
		var s: Dictionary = field.fx.stats
		var before := {"proj": int(s["projectiles"].get(spec.get("mesh", ""), 0)), "bolt": int(s["bolts"]),
			"beam": int(s["beams"]), "melee": int(s["melee"])}
		var fired := false
		for i in 40:
			_step(m, field, 0.1)
			var now := {"proj": int(s["projectiles"].get(spec.get("mesh", ""), 0)), "bolt": int(s["bolts"]),
				"beam": int(s["beams"]), "melee": int(s["melee"])}
			if now[spec["type"]] > before[spec["type"]]:
				fired = true
				break
		assert_true(fired, "%s 出手应放 %s 表现" % [uid, spec["type"]])
	_step(m, field, 3.0)
	assert_true(int(field.fx.stats["impacts"]) > 0, "投射物到点放落点特效")
	_dispose(field)


func test_towers_shoot_and_blow_up() -> void:
	var m = _new_match(false)
	var field = _field(m)
	var tower = m.battle.opponent_towers[0]
	for t in m.battle.opponent_towers:
		if not t.is_king():
			tower = t
	_unit(m, "golem_body", 0, tower.pos + Vector2(0.0, 3.0))
	_step(m, field, 2.0)
	assert_true(int(field.fx.stats["tower_shots"]) > 0, "塔反击射出 3D 箭")
	tower.take_damage(tower.hp + 1.0)
	_step(m, field, 0.1)
	assert_eq(int(field.fx.stats["towers"]), 1, "塔毁放一次爆破")
	_step(m, field, 0.5)
	assert_eq(int(field.fx.stats["towers"]), 1, "爆破只放一次")
	_dispose(field)


func test_status_badges_follow_status() -> void:
	var m = _new_match(false)
	var field = _field(m)
	var u = _unit(m, "knight_body", 1, Vector2(13.0, 20.0))
	field.advance(0.0)
	var actor = field.presenter.actor_for(u)
	for kind in ["freeze", "stun", "slow"]:
		u.apply_status(kind, 0.5, 0.4)
		field.advance(0.05)
		assert_not_null(actor.get_node_or_null("Status_" + kind), "%s 状态挂件出现" % kind)
		_step(m, field, 0.8)
		assert_null(actor.get_node_or_null("Status_" + kind), "%s 状态结束挂件撤掉" % kind)
	_dispose(field)


func test_damage_anchor_follows_head_then_expires() -> void:
	var m = _new_match(false)
	var field = _field(m)
	var u = _unit(m, "knight_body", 1, Vector2(13.0, 18.0))
	var air = _unit(m, "minion_body", 1, Vector2(10.0, 18.0))
	field.advance(0.0)
	var id: int = u.get_instance_id()
	var actor = field.presenter.actor_for(u)
	var head: Vector3 = field.fx.head_world(id)
	assert_true(head.distance_to(actor.position + Vector3(0, actor.body_height, 0)) < 0.001, "锚点 = 地面单位头顶")
	var air_actor = field.presenter.actor_for(air)
	var air_head: Vector3 = field.fx.head_world(air.get_instance_id())
	assert_true(air_head.y > actor.body_height + 1.0 and absf(air_head.y - air_actor.air_y() - air_actor.body_height) < 0.001,
		"空军锚点含飞行高度")
	var s0: Vector2 = field.head_screen(id)
	assert_true(s0.y < field.tile_to_screen(u.pos).y - 10.0, "头顶在脚的屏幕上方")
	_step(m, field, 2.0)
	var s1: Vector2 = field.head_screen(id)
	assert_true(s1.distance_to(s0) > 5.0, "单位走动后锚点跟着走")
	u.take_damage(u.hp + 1.0)
	_step(m, field, 0.2)
	assert_not_null(field.head_screen(id), "阵亡后锚点暂留（伤害数字收尾）")
	for i in 25:
		field.advance(0.1)
	assert_null(field.head_screen(id), "2 秒后锚点释放")
	var tower = m.battle.player_towers[0]
	assert_true(field.head_screen(tower.get_instance_id()) != null, "塔也有头顶锚点")
	_dispose(field)


func test_effects_are_read_only_hash_neutral() -> void:
	var m = _new_match()
	var field = _field(m)
	var m2 = _new_match()
	var targets := [Vector2(13.0, 8.0), Vector2(7.0, 24.0), Vector2(19.0, 25.0), Vector2(12.0, 10.0)]
	var k := 0
	for f in 300:
		for match_obj in [m, m2]:
			var hand: Array = match_obj.player.deck.get_hand()
			for i in hand.size():
				if match_obj.player.can_play(i) and match_obj.player.try_play_card(i, targets[k % targets.size()]):
					break
		k += 1
		m.update(0.2)
		field.advance(0.2)
		m2.update(0.2)
		if m.state_hash().hex_encode() != m2.state_hash().hex_encode():
			assert_true(false, "挂特效层与否 hash 在第 %d 帧分叉" % f)
			break
		if m.is_over():
			break
	var casts := 0
	for kind in field.fx.stats["casts"]:
		casts += int(field.fx.stats["casts"][kind])
	assert_true(casts >= 5, "整局放过多次法术/出兵特效（实得 %d）" % casts)
	assert_true(int(field.fx.stats["hits"]) > 0 and int(field.fx.stats["deaths"]) > 0, "受击星与阵亡烟团都出现")
	_dispose(field)


func test_reconnect_catchup_does_not_replay_spells() -> void:
	var m = _new_match(false)
	var field = _field(m)
	field.advance(0.0)
	for i in 10:
		m.battle.step(0.1)   # 模拟重连追帧：逻辑时间一帧内推进 1 秒
	field.fx.cast("fireball", 1, Vector2(13.0, 24.0))
	assert_eq(int(field.fx.stats["skipped_casts"]), 1, "追帧期间的法术不补放")
	field.advance(0.016)
	field.fx.cast("fireball", 1, Vector2(13.0, 24.0))
	assert_eq(int(field.fx.stats["casts"].get("fireball", 0)), 1, "追上后正常放")
	_dispose(field)
