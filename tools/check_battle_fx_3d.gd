## D8 战斗特效冒烟（真实场景树，无需点界面）：正式战斗页里逐张法术卡施放、逐个远程单位开火、状态挂件、塔毁、
## 阵亡烟团都能放出并释放；伤害数字头顶锚点与引擎相机投影一致；整局 AI 对打期间特效节点不堆积。
## 可选 --shot <dir>：非 headless 运行时出拼图（法术逐卡 3 个时刻 / 投射物飞行中 / 杂项）供自检。
## 用法：godot --path . --resolution 750x1334 --script res://tools/check_battle_fx_3d.gd -- --shot <dir>
extends SceneTree

const GameStateScript := preload("res://view/game_state.gd")
const UnitScript := preload("res://logic/unit.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")
const Catalog := preload("res://view/three_d/fx_catalog.gd")

const DT := 1.0 / 60.0
const CROP := 300
const SPELL_TILE := Vector2(13.0, 9.0)

var _shot_dir := ""
var _failures: Array[String] = []
var _scene: Node
var _field
var _m
var _done := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i >= 0 and i + 1 < args.size():
		_shot_dir = args[i + 1]
	_check.call_deferred()


func _check() -> void:
	var online := root.get_node_or_null("Online")
	if online != null:
		root.remove_child(online)
		online.free()
	GameStateScript.campaign = null
	GameStateScript.run = null
	GameStateScript.tutorial = false
	GameStateScript.stage_id = ""
	GameStateScript.level_id = "ladder_01"
	GameStateScript.player_deck = []
	_scene = load("res://view/battle_scene.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await process_frame
	_scene.set_process(false)   # 手动驱动：每步固定 1/60 秒
	_field = _scene.get("_field3d")
	_m = _scene.get("match_obj")
	_m.set_opponent_controller(null)
	await _spells()
	await _projectiles()
	await _misc()
	await _full_battle()
	for failure in _failures:
		push_error(failure)
	var ok := _failures.is_empty() and _done == 4
	print("BATTLE_FX_3D: ", "PASS" if ok else "FAIL (done=%d)" % _done)
	quit(0 if ok else 1)


func _run(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_scene._process(DT)


func _reset_units() -> void:
	for u in _m.battle.arena.units.duplicate():
		_m.battle.arena.units.erase(u)
	_run(1.2)   # 让上一组的阵亡烟团/特效播完


func _unit(unit_id: String, owner: int, pos: Vector2):
	var u = UnitScript.new(unit_id, owner, GameStateScript.config().get_unit(unit_id), pos)
	_m.battle.arena.add_unit(u)
	return u


func _spells() -> void:
	var sheet := _sheet(3, Catalog.SPELLS.size())
	var row := 0
	for cid in Catalog.SPELLS:
		_reset_units()
		for off in [Vector2(-0.8, 0.3), Vector2(0.8, 0.0), Vector2(0.0, -0.9)]:
			var u = _unit("knight_body", 0 if cid == "heal" else 1, SPELL_TILE + off)
			if cid == "heal":
				u.take_damage(300.0)
		_run(0.05)
		var before: int = _field.fx.active_parts()
		_m.player.skill_system.play_card(cid, 0, SPELL_TILE)
		_m.player.play_observer.on_card_played(0, cid, SPELL_TILE)   # 与出牌成功同一钩子
		if _field.fx.active_parts() <= before:
			_failures.append("%s 未放出特效" % cid)
		var t := 0.0
		var col := 0
		for at in [0.08, 0.25, 0.55]:
			_run(at - t)
			t = at
			await _crop_into(sheet, col, row, _scene._t2s(SPELL_TILE) + Vector2(0, -60))
			col += 1
		row += 1
	_save(sheet, "d8_spells")
	_done += 1


func _projectiles() -> void:
	var specs: Array = []
	for uid in Catalog.ATTACKS:
		if str(Catalog.ATTACKS[uid]["type"]) != "melee":
			specs.append(uid)
	var cols := 5
	var sheet := _sheet(cols, ceili(float(specs.size()) / cols))
	var k := 0
	for uid in specs:
		_reset_units()
		var cfg: Dictionary = GameStateScript.config().get_unit(uid)
		var gap: float = clampf(float(cfg.get("attack_range", 2.0)) - 0.3, 1.5, 4.0)
		var from := Vector2(13.0, 22.0)
		var to := from - Vector2(0.0, gap)
		if str(cfg.get("target_priority", "")) == "buildings":
			var tower = _m.battle.opponent_towers[0] if not _m.battle.opponent_towers[0].is_king() else _m.battle.opponent_towers[1]
			to = tower.pos
			from = tower.pos + Vector2(0.0, float(tower.fh) * 0.5 + gap)
		else:
			_unit("golem_body", 1, to)
		_unit(uid, 0, from)
		var spec: Dictionary = Catalog.ATTACKS[uid]
		var stats: Dictionary = _field.fx.stats
		var key := "bolts" if spec["type"] == "bolt" else ("beams" if spec["type"] == "beam" else "")
		var mesh := str(spec.get("mesh", ""))
		var count := func() -> int: return int(stats[key]) if key != "" else int(stats["projectiles"].get(mesh, 0))
		var before: int = count.call()
		var fired := false
		for i in 300:
			_scene._process(DT)
			if count.call() > before:
				fired = true
				break
		if not fired:
			_failures.append("%s 5 秒内未出手" % uid)
		_run(0.06 if key == "" else 0.03)
		await _crop_into(sheet, k % cols, k / cols, (_scene._t2s(from) + _scene._t2s(to)) * 0.5 + Vector2(0, -40))
		k += 1
	_save(sheet, "d8_projectiles")
	_done += 1


func _misc() -> void:
	var sheet := _sheet(4, 2)
	_reset_units()
	var kinds := ["freeze", "stun", "slow"]
	var victims: Array = []
	for i in kinds.size():
		var u = _unit("knight_body", 1, Vector2(9.0 + 4.0 * i, 9.0))
		victims.append(u)
	_run(0.05)
	for i in kinds.size():
		victims[i].apply_status(kinds[i], 3.0, 0.4)
	_run(0.3)
	for i in kinds.size():
		var actor = _field.presenter.actor_for(victims[i])
		if actor == null or actor.get_node_or_null("Status_" + kinds[i]) == null:
			_failures.append("%s 状态挂件未出现" % kinds[i])
		await _crop_into(sheet, i, 0, _scene._t2s(victims[i].pos) + Vector2(0, -50))
	# 伤害数字锚点：头顶屏幕点 = 引擎相机投影（不含震屏）。
	var u0 = victims[0]
	u0.take_damage(50.0)
	_run(DT)
	var head: Vector2 = _field.head_screen(u0.get_instance_id())
	var world: Vector3 = _field.fx.head_world(u0.get_instance_id())
	var engine: Vector2 = _field.camera.unproject_position(world)
	if head.distance_to(engine) > 0.6:
		_failures.append("头顶锚点投影不一致 ours=%s engine=%s" % [head, engine])
	await _crop_into(sheet, 3, 0, head + Vector2(0, 40))
	# 阵亡烟团 + 塔毁爆破。
	_reset_units()
	var doomed = _unit("giant_body", 1, Vector2(13.0, 10.0))
	_run(0.1)
	doomed.take_damage(doomed.hp + 1.0)
	_run(0.12)
	await _crop_into(sheet, 0, 1, _scene._t2s(Vector2(13.0, 10.0)) + Vector2(0, -40))
	var tower = _m.battle.opponent_towers[0] if not _m.battle.opponent_towers[0].is_king() else _m.battle.opponent_towers[1]
	var deaths_before: int = int(_field.fx.stats["towers"])
	tower.take_damage(tower.hp + 1.0)
	var c: Vector2 = _scene._t2s(tower.pos) + Vector2(0, -70)
	var t := 0.0
	var col := 1
	for at in [0.1, 0.4, 0.9]:
		_run(at - t)
		t = at
		await _crop_into(sheet, col, 1, c)
		col += 1
	if int(_field.fx.stats["towers"]) != deaths_before + 1:
		_failures.append("塔毁爆破未放")
	_save(sheet, "d8_misc")
	_done += 1


## 整局双方 AI 对打 60 秒：特效件数有界、播完不残留；截一张全屏。
func _full_battle() -> void:
	_reset_units()
	_m.set_opponent_controller(AIControllerScript.new(_m, GameStateScript.config()))
	var peak := 0
	for i in 3600:
		if i % 30 == 0:
			_auto_play()
		_scene._process(DT)
		peak = maxi(peak, _field.fx.active_parts())
		if i == 1800:
			await _full_shot("d8_battle")
		if _m.is_over():
			break
	_run(3.0)
	print("BATTLE_FX_3D: 整局特效件峰值 %d，收尾残留 %d，统计 %s" % [peak, _field.fx.active_parts(), _field.fx.stats])
	if _field.fx.active_parts() > 40:
		_failures.append("对局结束 3 秒后特效件仍残留 %d" % _field.fx.active_parts())
	_done += 1


## 我方简易自动出牌：能出就往前线中路扔（法术扔敌方半场）。
func _auto_play() -> void:
	var hand: Array = _m.player.deck.get_hand()
	for i in hand.size():
		if hand[i] == null or not _m.player.can_play(i):
			continue
		var info: Dictionary = _field.deploy.card_info(GameStateScript.config(), str(hand[i]))
		var tile := Vector2(6.0 + randf() * 14.0, 19.5) if info["spawn"] else Vector2(6.0 + randf() * 14.0, 8.0)
		if _m.player.try_play_card(i, tile):
			return


func _sheet(cols: int, rows: int) -> Image:
	return Image.create(CROP * cols, CROP * rows, false, Image.FORMAT_RGBA8)


func _crop_into(sheet: Image, col: int, row: int, center: Vector2) -> void:
	if _shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var src := CROP / 2   # 取 150 像素见方放大 2 倍：手机像素下特效很小，放大看细节
	var x := clampi(int(center.x) - src / 2, 0, img.get_width() - src)
	var y := clampi(int(center.y) - src / 2, 0, img.get_height() - src)
	var part := img.get_region(Rect2i(x, y, src, src))
	part.resize(CROP, CROP, Image.INTERPOLATE_NEAREST)
	sheet.blit_rect(part, Rect2i(0, 0, CROP, CROP), Vector2i(col * CROP, row * CROP))


func _full_shot(label: String) -> void:
	if _shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shot_dir.path_join(label + ".png"))


func _save(sheet: Image, label: String) -> void:
	if _shot_dir != "":
		sheet.save_png(_shot_dir.path_join(label + ".png"))
