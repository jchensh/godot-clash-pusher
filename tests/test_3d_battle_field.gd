## D4：正式 PvE 战斗的 3D 战场层——经 3D 镜头拾取的落点出牌，录制→重放仍通过、sim/hash 与不挂 3D 逐 bit 一致；
## battle_scene 的 tile→屏幕映射/特效尺寸/教程半场高亮改借 3D 投影后方向语义正确。
extends "res://tests/test_case.gd"

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const PlayerDataScript := preload("res://logic/player_data.gd")
const PveReplayScript := preload("res://logic/pve_replay.gd")
const PveRecorderScript := preload("res://net/pve_recorder.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")
const BattleField3D := preload("res://view/three_d/battle_field_3d.gd")
const BattleSceneScript := preload("res://view/battle_scene.gd")

const DECK := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]
const STAGE := "stage_1_1"
const SCREEN := Vector2(750, 1334)
const TOP := 54.0                # 与 battle_scene TOPBAR_H / HUD_BOTTOM_H 同值
const HUD := 176.0
# 我方半场里几处非整格的目标点（兵牌）+ 敌方半场一处（法术），轮流出。
const TARGETS := [Vector2(6.37, 24.81), Vector2(19.52, 22.13), Vector2(12.9, 27.4), Vector2(8.2, 6.6)]

var _loader = null


func _config():
	if _loader == null:
		_loader = Loader.new()
		_loader.load_all()
	return _loader


func _progress() -> Dictionary:
	return {"knight": {"level": 4, "rank": 2}, "giant": {"level": 3, "rank": 1}}


func _new_match():
	var pd = PlayerDataScript.new()
	var progress := _progress()
	for cid in progress:
		pd.cards[cid] = {"level": progress[cid]["level"], "rank": progress[cid]["rank"], "shards": 0, "unlocked": true}
	var m = MatchScript.new(_config())
	m.setup_stage(STAGE, DECK, pd, {})
	m.set_opponent_controller(AIControllerScript.new(m, _config(), m.ai_difficulty))
	return m


func _field(m):
	var field = BattleField3D.new()
	field.setup(m.battle, _config(), SCREEN, TOP, HUD, {"lighting": false})
	return field


## 手指放在「目标 tile 投影 + 抬手像素」处 → pick 得到的就是目标附近（相机数学往返）的落点。
func _finger_for(field, tile: Vector2) -> Vector2:
	return field.tile_to_screen(tile) + Vector2(0.0, field.deploy.lift_pixels())


func test_3d_drops_record_replay_and_hash_neutral() -> void:
	var m = _new_match()
	var field = _field(m)
	var rec = PveRecorderScript.new()
	rec.attach(m)
	var plays: Array = []          # [帧号, 手牌格, 落点]，供无 3D 的对照局按帧复现
	var hashes: Array = []
	var k := 0
	for f in 260:
		if m.player.can_play(0):
			var drop: Variant = field.drop_tile(_finger_for(field, TARGETS[k % TARGETS.size()]))
			if drop != null and m.player.try_play_card(0, drop):
				plays.append([f, 0, drop])
				k += 1
		m.update(0.3)
		field.advance(0.3)
		hashes.append(m.state_hash().hex_encode())
		if m.is_over():
			break
	assert_true(plays.size() >= 3, "应经 3D 拾取打出多张牌（实得 %d）" % plays.size())
	assert_true(field.presenter.unit_actor_count() > 0 or m.is_over(), "3D 层应同步出单位节点")
	# ① 录制→重放：落点经相机射线得来（非整格浮点），量化后录制值=执行值，重放逐 hash 通过。
	var hex: Array = []
	for h in rec.hashes:
		hex.append({"t": h["t"], "h": (h["h"] as PackedByteArray).hex_encode()})
	var v: Dictionary = PveReplayScript.replay(_config(), STAGE, DECK, _progress(), rec.cmds, hex)
	assert_eq(String(v["status"]), "pass", "3D 落点局重放应通过: %s" % String(v.get("reason", "")))
	# ② 同帧同落点、不挂 3D 层的对照局：逐帧 hash 全等（3D 层只读）。
	var m2 = _new_match()
	var p := 0
	for f in hashes.size():
		while p < plays.size() and int(plays[p][0]) == f:
			assert_true(m2.player.try_play_card(int(plays[p][1]), plays[p][2]), "对照局同帧出牌应成功")
			p += 1
		m2.update(0.3)
		if m2.state_hash().hex_encode() != hashes[f]:
			assert_true(false, "挂 3D 层与否 hash 在第 %d 帧分叉" % f)
			break
	field.presenter.clear()
	field.free()


func test_scene_projection_uses_3d_camera() -> void:
	var m = _new_match()
	var field = _field(m)
	var bs = BattleSceneScript.new()
	bs.match_obj = m
	bs._vw = SCREEN.x
	bs._vh = SCREEN.y
	bs._landscape = true
	bs._field3d = field
	var a = m.battle.arena
	var p := Vector2(9.3, 17.7)
	assert_true(bs._t2s(p).distance_to(field.tile_to_screen(p)) < 0.001, "_t2s 走 3D 投影")
	assert_true(bs._ur() > 10.0 and absf(bs._ur() - field.tile_px()) < 0.001, "特效尺寸基准 = 3D 一格像素")
	# 「屏幕向上」语义：塔身伤害数字/箭口锚点必须画在塔脚上方。
	assert_true(bs._t2s(p + bs._screen_up_tiles(2.0)).y < bs._t2s(p).y - 1.0, "屏幕向上偏移在 3D 下仍朝上")
	# 我左敌右：我方王塔在屏幕左半、敌方王塔在右半。
	var mine := Vector2.ZERO
	var theirs := Vector2.ZERO
	for t in m.battle.player_towers:
		if t.is_king():
			mine = bs._t2s(t.pos)
	for t in m.battle.opponent_towers:
		if t.is_king():
			theirs = bs._t2s(t.pos)
	assert_true(mine.x < SCREEN.x * 0.5 and theirs.x > SCREEN.x * 0.5, "我方王塔在左、敌方在右")
	# 教程 field 高亮 = 本方半场：罩住我方全部塔，不罩敌塔，且落在顶栏与手牌栏之间。
	var hl: Rect2 = bs._tut_rect("field")
	for t in m.battle.player_towers:
		assert_true(hl.has_point(bs._t2s(t.pos)), "field 高亮应罩住我方塔")
	for t in m.battle.opponent_towers:
		assert_false(hl.has_point(bs._t2s(t.pos)), "field 高亮不应罩住敌塔")
	assert_true(hl.position.y >= TOP and hl.end.y <= SCREEN.y - HUD, "field 高亮不压顶栏/手牌栏")
	# 半场边界上的点：高亮内侧可部署、外侧（越过部署线）不可。
	var inside := Vector2(a.grid_w * 0.5 + 0.5, a.deploy_player_y_min + 0.5)
	assert_true(hl.has_point(bs._t2s(inside)), "部署线内侧在高亮内")
	# 3D 下 2D 精灵配套刀光/星芒/白烟让位给模型动作。
	assert_true(bs._sprite_fx("archer_body", "attack").is_empty(), "3D 下不叠 2D 刀光")
	bs._field3d = null
	bs.free()
	field.presenter.clear()
	field.free()


func test_drop_cancel_and_offfield() -> void:
	var m = _new_match()
	var field = _field(m)
	# 顶部天空（场外）→ 无落点；落点经抬手后仍在场内的手指位置 → 有落点且与 ghost 同一点。
	assert_eq(field.drop_tile(Vector2(SCREEN.x * 0.5, TOP + 4.0)), null, "场外天空不给落点")
	var finger := _finger_for(field, Vector2(10.0, 25.0))
	field.deploy.begin_drag(0, "knight")
	field.deploy.update_drag(finger)
	var drop: Variant = field.drop_tile(finger)
	assert_true(drop != null and (drop as Vector2).distance_to(field.deploy.drop_tile) < 0.0001, "松手落点 = ghost 落点")
	assert_true((drop as Vector2).distance_to(Vector2(10.0, 25.0)) < 0.01, "抬手后落点回到目标格")
	field.deploy.cancel_drag()
	assert_false(field.deploy.dragging, "取消后 ghost 撤掉")
	field.presenter.clear()
	field.free()
