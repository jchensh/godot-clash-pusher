## D1：3D 战斗 presenter 的状态→表现映射与节点生命周期；并证明挂上 presenter 不改变 sim/hash。
extends "res://tests/test_case.gd"

const Loader := preload("res://logic/config_loader.gd")
const BattleScript := preload("res://logic/battle.gd")
const UnitScript := preload("res://logic/unit.gd")
const MatchScript := preload("res://logic/match.gd")
const SimClockScript := preload("res://logic/sim_clock.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")
const Presenter := preload("res://view/three_d/battle_presenter.gd")
const UnitActor := preload("res://view/three_d/battle_unit_actor.gd")
const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")

const DT := 1.0 / 60.0

var _loader = null


func _config():
	if _loader == null:
		_loader = Loader.new()
		_loader.load_all()
	return _loader


func _battle():
	var battle = BattleScript.new()
	battle.build_arena(_config().get_level("ladder_01"), _config().get_arena("default"))
	return battle


## 无 3D 资产的单位（D3 起全部配置单位都有模型）：借兔射手数值、换一个未登记的 unit_id 测代理回退路径。
const PROXY_ID := "test_proxy_body"


func _unit(battle, unit_id: String, owner_id: int, pos: Vector2):
	var cfg_id := "archer_body" if unit_id == PROXY_ID else unit_id
	var unit = UnitScript.new(unit_id, owner_id, _config().get_unit(cfg_id), pos)
	battle.arena.add_unit(unit)
	return unit


func _presenter(battle, options: Dictionary = {}) -> Node3D:
	var presenter := Presenter.new()
	presenter.auto_advance = false
	(Engine.get_main_loop() as SceneTree).root.add_child(presenter)
	presenter.setup(battle, _config().get_arena("default"), options)
	return presenter


func _dispose(presenter: Node3D) -> void:
	presenter.get_parent().remove_child(presenter)
	presenter.free()


func _frames(presenter: Node3D, count: int) -> void:
	for i in count:
		presenter.advance(DT)


func test_one_actor_per_unit_and_proxy_marked() -> void:
	var battle = _battle()
	var knight = _unit(battle, "knight_body", UnitScript.OWNER_PLAYER, Vector2(6.5, 24.5))
	var archer = _unit(battle, PROXY_ID, UnitScript.OWNER_OPPONENT, Vector2(19.5, 5.5))
	var presenter := _presenter(battle)
	var children := presenter.get_child_count()
	_frames(presenter, 30)
	assert_eq(presenter.unit_actor_count(), 2, "两个单位各一个节点")
	assert_eq(presenter.get_child_count(), children, "反复同步不重复建节点")
	assert_eq(presenter.actor_for(knight).mode, UnitActor.MODE_MODEL, "小小用正式 GLB")
	assert_eq(presenter.actor_for(archer).mode, UnitActor.MODE_PROXY, "无资产单位用代理")
	assert_not_null(presenter.actor_for(archer).find_child("ProxyLabel", true, false), "代理带明确标注")
	assert_eq(presenter.proxy_unit_ids(), [PROXY_ID], "代理清单只列代理单位")
	assert_eq(presenter.actor_for(knight).clip, "Idle", "静止时播 Idle")
	_dispose(presenter)


func test_death_plays_out_then_frees_node() -> void:
	var battle = _battle()
	var knight = _unit(battle, "knight_body", UnitScript.OWNER_PLAYER, Vector2(6.5, 24.5))
	var proxy = _unit(battle, PROXY_ID, UnitScript.OWNER_PLAYER, Vector2(19.5, 24.5))
	var presenter := _presenter(battle)
	var baseline := presenter.get_child_count()
	knight.take_damage(knight.max_hp)
	proxy.take_damage(proxy.max_hp)
	battle.step(SimClockScript.TICK_DELTA)   # 逻辑层清死
	presenter.advance(DT)
	assert_eq(presenter.unit_actor_count(), 0, "消失单位移出存活表")
	assert_eq(presenter.dying_count(), 2, "转入死亡表现")
	var modes: Dictionary = {}
	for dying in presenter._dying:
		assert_eq(dying.state, UnitActor.STATE_DYING)
		modes[dying.mode] = dying.death_mode
	assert_eq(modes[UnitActor.MODE_MODEL], "clip", "小小（D3 补了 Death）播死亡片段")
	assert_eq(modes[UnitActor.MODE_PROXY], "fallback", "代理无片段 → 明确回退")
	_frames(presenter, 60)
	assert_eq(presenter.dying_count(), 0, "死亡表现播完")
	assert_eq(presenter.get_child_count(), baseline - 2, "节点已释放，不泄漏")
	_dispose(presenter)


func test_resetup_replaces_nodes_without_leak() -> void:
	var battle = _battle()
	_unit(battle, "knight_body", UnitScript.OWNER_PLAYER, Vector2(6.5, 24.5))
	var presenter := _presenter(battle)
	_frames(presenter, 5)
	var count := presenter.get_child_count()
	presenter.setup(battle, _config().get_arena("default"))
	_frames(presenter, 5)
	assert_eq(presenter.get_child_count(), count, "同一局重建（重放恢复）节点数不变")
	var fresh = _battle()   # 重连换新 Battle：旧单位/塔节点全部替换
	_unit(fresh, "giant_body", UnitScript.OWNER_OPPONENT, Vector2(19.5, 5.5))
	presenter.setup(fresh, _config().get_arena("default"))
	assert_eq(presenter.unit_actor_count(), 1)
	assert_eq(presenter.get_child_count(), count, "换局后无旧节点残留")
	_dispose(presenter)


func test_movement_interpolates_walks_and_faces_motion() -> void:
	var battle = _battle()
	var knight = _unit(battle, "knight_body", UnitScript.OWNER_PLAYER, Vector2(6.5, 24.5))
	var presenter := _presenter(battle)
	var actor = presenter.actor_for(knight)
	var start: Vector2 = knight.pos
	for tick in 8:
		battle.step(SimClockScript.TICK_DELTA)
		_frames(presenter, 6)
	var logic_moved: Vector2 = knight.pos - start
	assert_true(logic_moved.length() > 0.5, "逻辑层确实在推进")
	assert_true(actor.display_tile.distance_to(knight.pos) < 0.3, "显示位紧跟逻辑位")
	assert_eq(actor.state, UnitActor.STATE_WALK, "移动中为行走态")
	assert_eq(actor.clip, "Walk")
	var facing := Vector3(sin(actor.rotation.y), 0, cos(actor.rotation.y))
	var world_dir := Vector3(logic_moved.x, 0, logic_moved.y).normalized()
	assert_true(facing.dot(world_dir) > 0.7, "朝向跟随移动方向")
	var before: Vector2 = actor.display_tile
	battle.step(SimClockScript.TICK_DELTA)
	presenter.advance(DT)
	assert_true(actor.display_tile.distance_to(before) < knight.pos.distance_to(before), "单帧只走一部分（插值而非跳格）")
	_dispose(presenter)


func test_attack_edge_drives_clip_and_hit_updates_bar() -> void:
	var battle = _battle()
	var knight = _unit(battle, "knight_body", UnitScript.OWNER_PLAYER, Vector2(13.5, 20.5))
	var archer = _unit(battle, PROXY_ID, UnitScript.OWNER_OPPONENT, Vector2(13.5, 19.6))
	var presenter := _presenter(battle)
	battle.step(SimClockScript.TICK_DELTA)
	presenter.advance(DT)
	var k = presenter.actor_for(knight)
	var a = presenter.actor_for(archer)
	assert_eq(k.attack_count, 1, "冷却上升沿识别为一次攻击")
	assert_eq(k.state, UnitActor.STATE_ATTACK)
	assert_eq(k.clip, "Attack", "小小播 Attack 片段")
	assert_eq(a.clip, "proxy_attack", "代理走程序化攻击回退")
	assert_almost_eq(a.hp_ratio, archer.hp / archer.max_hp, 0.0001, "血条比例读逻辑血量")
	assert_true(a.hp_ratio < 1.0 and a.find_child("HpBar", true, false).visible, "受伤后显示血条")
	_frames(presenter, 120)
	assert_eq(k.attack_count, 1, "逻辑未再出手 → 不重复计攻击")
	assert_ne(k.state, UnitActor.STATE_ATTACK, "攻击动作播完回到常态")
	_dispose(presenter)


func test_tower_hit_and_destroy_show_ruin() -> void:
	var battle = _battle()
	var presenter := _presenter(battle)
	var tower = battle.opponent_towers[0]
	var actor = presenter.tower_actor_for(tower)
	assert_not_null(actor, "六塔各有节点")
	assert_eq(presenter.get_children().filter(func(n): return n.name.begins_with("Tower_")).size(), 6)
	tower.take_damage(tower.max_hp * 0.5)
	presenter.advance(DT)
	assert_almost_eq(actor.hp_ratio, 0.5, 0.0001)
	assert_false(actor.destroyed)
	tower.take_damage(tower.max_hp)
	presenter.advance(DT)
	assert_true(actor.destroyed, "摧毁态")
	assert_true(actor.find_child("Ruin", false, false).visible, "显示废墟")
	assert_false(actor.find_child("Intact", false, false).visible, "隐藏完整塔身")
	_dispose(presenter)


func test_flipped_view_mirrors_positions_and_swaps_team_color() -> void:
	var battle = _battle()
	var knight = _unit(battle, "knight_body", UnitScript.OWNER_PLAYER, Vector2(6.5, 24.5))
	var normal := _presenter(battle)
	var flipped := _presenter(battle, {"local_owner": UnitScript.OWNER_OPPONENT, "flipped": true})
	var a: Vector3 = normal.actor_for(knight).position
	var b: Vector3 = flipped.actor_for(knight).position
	assert_true(a.is_equal_approx(Vector3(-b.x, b.y, -b.z)), "side2 视角整场 180° 翻转")
	var tower = battle.player_towers[0]
	assert_eq(normal.tower_actor_for(tower).team_color, ArenaPresenter.COLOR_BLUE, "本方视角：我塔蓝")
	assert_eq(flipped.tower_actor_for(tower).team_color, ArenaPresenter.COLOR_RED, "对方视角：同一座塔为红")
	assert_true(_has_tinted_surface(normal.tower_actor_for(tower), ArenaPresenter.COLOR_BLUE), "塔模型阵营部件确实染蓝")
	assert_true(_has_tinted_surface(flipped.tower_actor_for(tower), ArenaPresenter.COLOR_RED), "塔模型阵营部件确实染红")
	_dispose(normal)
	_dispose(flipped)


func test_presenter_does_not_change_sim_or_hash() -> void:
	var plain = _ai_match()
	var shown = _ai_match()
	var presenter := _presenter(shown["match"].battle)
	var mismatches := 0
	var max_units := 0
	for tick in 600:
		_ai_tick(plain)
		_ai_tick(shown)
		for f in 6:
			presenter.advance(DT)
		max_units = maxi(max_units, presenter.unit_actor_count())
		if tick % 25 == 0 and plain["match"].state_hash() != shown["match"].state_hash():
			mismatches += 1
	assert_true(max_units > 0, "对局中确有单位被表现")
	assert_eq(mismatches, 0, "挂 presenter 的一局与不挂的一局逐段 hash 一致")
	assert_eq(plain["match"].state_hash(), shown["match"].state_hash(), "终局 hash 一致")
	assert_eq(presenter.unit_actor_count(), shown["match"].battle.arena.get_units().size(), "节点数 = 存活单位数")
	_dispose(presenter)


func _ai_match() -> Dictionary:
	var m = MatchScript.new(_config())
	m.setup("ladder_01")
	return {
		"match": m,
		"player_ai": AIControllerScript.new(m, _config(), "hard", AIControllerScript.OWNER_PLAYER),
		"enemy_ai": AIControllerScript.new(m, _config(), "hard", AIControllerScript.OWNER_OPPONENT),
	}


## 与 tools/balance_probe.gd 同序：双方回涨 → 我方 AI → 敌方 AI → battle.step。
func _ai_tick(ctx: Dictionary) -> void:
	var m = ctx["match"]
	if m.is_over():
		return
	var dt: float = SimClockScript.TICK_DELTA
	m.player.regen(dt)
	m.opponent.regen(dt)
	ctx["player_ai"].tick(dt)
	ctx["enemy_ai"].tick(dt)
	m.battle.step(dt)


func _has_tinted_surface(root: Node, color: Color) -> bool:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s) as ShaderMaterial
			if mat != null and mat.get_shader_parameter("tint") == color:
				return true
	return false
