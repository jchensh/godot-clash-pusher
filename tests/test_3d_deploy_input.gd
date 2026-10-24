## D2：3D 出牌输入与镜头构图——落点与 2D 路径一致、河/桥/塔/半场边界正确、翻转视角、取消与 ghost。
extends "res://tests/test_case.gd"

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const SimClockScript := preload("res://logic/sim_clock.gd")
const DeployInput := preload("res://view/three_d/deploy_input_3d.gd")
const BattleCamera := preload("res://view/three_d/battle_camera.gd")

const TOP := 150.0
const HUD := 230.0
const SCREEN := Vector2(750, 1334)

var _loader = null


func _config():
	if _loader == null:
		_loader = Loader.new()
		_loader.load_all()
	return _loader


func _match():
	var m = MatchScript.new(_config())
	m.setup("ladder_01")
	m.player.elixir.current = m.player.elixir.maximum
	m.opponent.elixir.current = m.opponent.elixir.maximum
	return m


## 搭一套「相机 + 输入」（不入树：runner 在主循环前执行；屏幕↔世界用 BattleCamera 纯数学，
## 与 Camera3D 的一致性由 tools/check_battle_3d_preview.gd 实机比对）。屏幕取项目竖屏基准 750×1334。
func _rig(m, owner: int, flipped: bool) -> Dictionary:
	var size := SCREEN
	var camera := Camera3D.new()
	var zone := Rect2(0.0, TOP, size.x, size.y - TOP - HUD)
	var arena = m.battle.arena
	BattleCamera.fit(camera, Vector2(arena.grid_w, arena.grid_h), size, zone)
	var input := DeployInput.new()
	input.configure(camera, arena, _config(), owner, flipped, size)
	input.blocked_rects = [Rect2(0, 0, size.x, TOP), Rect2(0, size.y - HUD, size.x, HUD)]
	return {"camera": camera, "input": input, "zone": zone, "size": size}


func _dispose(rig: Dictionary) -> void:
	rig.input.cancel_drag()
	rig.input.free()
	rig.camera.free()


## 让 tile 落在手指正下方抬手后的位置：屏幕点 = tile 投影 + 抬手像素（pick 会先上抬再取地面点）。
func _screen_for(rig: Dictionary, tile: Vector2) -> Vector2:
	return rig.input.tile_to_screen(tile) + Vector2(0.0, rig.input.lift_pixels())


func _hand_index(player, card_id: String) -> int:
	var hand: Array = player.deck.get_hand()
	return hand.find(card_id)


func _boundary_tiles(arena) -> Array:
	var e := 0.01
	var mid_river := (float(arena.river_y_min) + float(arena.river_y_max)) * 0.5
	var tiles := [
		Vector2(e, e), Vector2(arena.grid_w - e, arena.grid_h - e),
		Vector2(5.5, arena.river_y_min - e), Vector2(5.5, arena.river_y_min + e),
		Vector2(5.5, arena.river_y_max - e), Vector2(5.5, arena.river_y_max + e),
		Vector2(5.5, arena.deploy_player_y_min - e), Vector2(5.5, arena.deploy_player_y_min + e),
		Vector2(5.5, arena.deploy_enemy_y_max - e), Vector2(5.5, arena.deploy_enemy_y_max + e),
	]
	for bridge in arena.bridges:
		for x in [float(bridge.x_min) - e, float(bridge.x_min) + e, float(bridge.x_max) - e, float(bridge.x_max) + e]:
			tiles.append(Vector2(x, mid_river))
	for tower in arena.towers:
		var x0: float = tower.pos.x - tower.fw * 0.5
		var y0: float = tower.pos.y - tower.fh * 0.5
		tiles.append(Vector2(x0 - e, tower.pos.y))
		tiles.append(Vector2(x0 + e, tower.pos.y))
		tiles.append(Vector2(tower.pos.x, y0 - e))
		tiles.append(Vector2(tower.pos.x, y0 + e))
	return tiles


func test_pick_roundtrip_on_river_bridge_tower_and_line_edges_both_views() -> void:
	var m = _match()
	var arena = m.battle.arena
	for view in [[0, false], [1, true]]:
		var rig := _rig(m, view[0], view[1])
		var input = rig.input
		input.begin_drag(0, "knight")
		var worst := 0.0
		var legality_mismatch := 0
		for tile in _boundary_tiles(arena):
			var picked: Variant = input.pick_tile(_screen_for(rig, tile))
			assert_not_null(picked, "边界点 %s 可拾取" % tile)
			if picked == null:
				continue
			worst = maxf(worst, (picked as Vector2).distance_to(tile))
			if input.is_legal(picked) != arena.can_deploy(view[0], tile):
				legality_mismatch += 1
		assert_true(worst < 0.002, "屏幕↔tile 往返误差 < 0.002（实际 %.5f）" % worst)
		assert_eq(legality_mismatch, 0, "河/桥/塔/半场线两侧合法性与 Arena 一致（owner=%d）" % view[0])
		_dispose(rig)


func test_legality_sweep_matches_arena_and_player_rules() -> void:
	var m = _match()
	var arena = m.battle.arena
	for owner in [0, 1]:
		var rig := _rig(m, owner, owner == 1)
		var input = rig.input
		var spawn_bad := 0
		var spell_bad := 0
		for x in range(0, arena.grid_w * 2):
			for y in range(0, arena.grid_h * 2):
				var tile := Vector2(x * 0.5 + 0.25, y * 0.5 + 0.25)
				input.begin_drag(0, "knight")
				if input.is_legal(tile) != arena.can_deploy(owner, tile):
					spawn_bad += 1
				input.begin_drag(0, "fireball")
				if not input.is_legal(tile):
					spell_bad += 1
		input.cancel_drag()
		assert_eq(spawn_bad, 0, "兵牌全场扫点与 Arena.can_deploy 一致（owner=%d）" % owner)
		assert_eq(spell_bad, 0, "法术全场可放")
		input.begin_drag(0, "fireball")
		assert_false(input.is_legal(Vector2(-0.5, 3)), "场外不可放")
		_dispose(rig)
	# 与 Player 真实入口逐点对照：3D 判合法 ⇔ try_play_card 成功（满圣水）。
	var rig := _rig(m, 0, false)
	var mismatch := 0
	for tile in [Vector2(6.5, 24.5), Vector2(6.5, 5.5), Vector2(6.5, 14.5), Vector2(13.0, 27.0), Vector2(20.5, 20.2)]:
		var twin = _match()
		var idx := _hand_index(twin.player, "knight")
		rig.input.begin_drag(idx, "knight")
		if rig.input.is_legal(tile) != twin.player.try_play_card(idx, tile):
			mismatch += 1
	rig.input.cancel_drag()
	assert_eq(mismatch, 0, "3D 合法判定与 Player.try_play_card 结果一致")
	_dispose(rig)


func test_drop_goes_through_same_entry_as_2d_and_keeps_hash() -> void:
	var via_3d = _match()
	var via_2d = _match()
	var rig := _rig(via_3d, 0, false)
	var received: Array = []
	rig.input.deploy_requested.connect(func(i, tile): received.append([i, tile]))
	# 双方卡组循环确定 → 两局手牌相同；每次出第 1 格（兵/法术都覆盖到），落点都在己方半场合法地面。
	for tile in [Vector2(6.5, 24.5), Vector2(19.5, 23.5), Vector2(4.5, 22.5), Vector2(21.5, 26.5)]:
		for m in [via_3d, via_2d]:
			m.player.elixir.current = m.player.elixir.maximum
		var cid := str(via_3d.player.deck.get_hand()[0])
		rig.input.begin_drag(0, cid)
		assert_true(rig.input.end_drag(_screen_for(rig, tile)), "%s 合法落点松手成功" % cid)
		var got: Array = received.back()
		assert_true((got[1] as Vector2).distance_to(tile) < 0.001, "发出的落点 = 目标 tile")
		assert_true(via_3d.player.try_play_card(got[0], got[1]), "3D 落点走 Player.try_play_card 成功")
		assert_true(via_2d.player.try_play_card(0, tile), "2D 同点同牌成功")
	assert_eq(received.size(), 4)
	for tick in 60:
		via_3d.advance_tick()
		via_2d.advance_tick()
	assert_eq(via_3d.state_hash(), via_2d.state_hash(), "同牌同点：3D 与 2D 两条输入路径推进 60 tick 后 hash 一致")
	_dispose(rig)


func test_lift_is_one_point_six_tiles_toward_screen_up() -> void:
	var m = _match()
	for view in [[0, false, -1.0], [1, true, 1.0]]:
		var rig := _rig(m, view[0], view[1])
		var tile := Vector2(10.0, 15.0)
		var finger: Vector2 = rig.input.tile_to_screen(tile)
		var picked: Vector2 = rig.input.pick_tile(finger)
		assert_almost_eq(picked.x - tile.x, view[2] * DeployInput.DROP_LIFT_TILES, 0.01, "落点在手指上方 1.6 格（屏幕向上）")
		assert_almost_eq(picked.y, tile.y, 0.01, "横向不偏")
		_dispose(rig)


func test_cancel_on_hud_offfield_and_illegal_half() -> void:
	var m = _match()
	var rig := _rig(m, 0, false)
	var input = rig.input
	var count := [0]
	input.deploy_requested.connect(func(_i, _t): count[0] += 1)
	var size: Vector2 = rig.size
	input.begin_drag(0, "knight")
	assert_false(input.end_drag(Vector2(size.x * 0.5, size.y - HUD * 0.5)), "松手在手牌栏 = 取消")
	input.begin_drag(0, "knight")
	assert_false(input.end_drag(Vector2(size.x * 0.5, TOP * 0.5)), "松手在顶栏 = 取消")
	input.begin_drag(0, "knight")
	input.update_drag(_screen_for(rig, Vector2(6.5, 5.5)))
	assert_false(input.legal, "兵牌拖到敌方半场为非法")
	assert_false(input.end_drag(_screen_for(rig, Vector2(6.5, 5.5))), "非法落点松手 = 取消")
	input.begin_drag(0, "fireball")
	assert_true(input.end_drag(_screen_for(rig, Vector2(6.5, 5.5))), "法术可放敌方半场")
	assert_eq(count[0], 1, "只有合法松手发出部署")
	assert_false(input.dragging, "松手后结束拖拽")
	_dispose(rig)


func test_ghost_shapes_and_cleanup() -> void:
	var m = _match()
	var rig := _rig(m, 0, false)
	var input = rig.input
	var baseline: int = input.get_child_count()
	var screen := _screen_for(rig, Vector2(4.5, 23.5))
	input.begin_drag(0, "goblins")
	input.update_drag(screen)
	var ghost: Node3D = input.find_child("DeployGhost", false, false)
	assert_true(ghost.visible, "落在场内显示 ghost")
	assert_eq(ghost.get_children().filter(func(n): return n.name.begins_with("Unit")).size(), 3, "蟑螂小队 3 个兵位")
	assert_not_null(input.find_child("DeployZone", false, false), "兵牌高亮己方半场")
	var ring := ghost.find_child("Ring", false, false) as MeshInstance3D
	assert_eq((ring.material_override as StandardMaterial3D).albedo_color.g, DeployInput.COL_OK.g, "合法为绿")
	input.update_drag(_screen_for(rig, Vector2(13.0, 5.0)))
	assert_eq((ring.material_override as StandardMaterial3D).albedo_color.r, DeployInput.COL_BAD.r, "非法为红")
	input.begin_drag(0, "fireball")
	input.update_drag(screen)
	var area := input.find_child("DeployGhost", false, false).find_child("Area", false, false) as MeshInstance3D
	assert_almost_eq((area.mesh as CylinderMesh).top_radius, 3.0, 0.0001, "火球范围圈 = 配置半径")
	assert_null(input.find_child("DeployZone", false, false), "法术不高亮半场")
	input.begin_drag(0, "zap")
	input.update_drag(screen)
	assert_not_null(input.find_child("DeployGhost", false, false).find_child("Cross", false, false), "直伤为准星")
	input.cancel_drag()
	assert_eq(input.get_child_count(), baseline, "取消后 ghost 全部释放")
	_dispose(rig)


func test_camera_fits_portrait_zone_and_own_half_is_on_left() -> void:
	var m = _match()
	var arena = m.battle.arena
	for view in [[0, false], [1, true]]:
		var rig := _rig(m, view[0], view[1])
		var zone: Rect2 = (rig.zone as Rect2).grow(1.0)
		var grid := Vector2(arena.grid_w, arena.grid_h)
		for corner in [Vector2.ZERO, Vector2(grid.x, 0), Vector2(0, grid.y), grid]:
			var p: Vector2 = rig.input.tile_to_screen(corner)
			assert_true(zone.has_point(p), "场地角 %s 落在顶栏与手牌栏之间（%s）" % [corner, p])
		var own_y: float = grid.y - 3.0 if view[0] == 0 else 3.0
		var own: Vector2 = rig.input.tile_to_screen(Vector2(grid.x * 0.5, own_y))
		assert_true(own.x < (rig.size as Vector2).x * 0.5, "本方半场在屏幕左侧（我左敌右）")
		_dispose(rig)
