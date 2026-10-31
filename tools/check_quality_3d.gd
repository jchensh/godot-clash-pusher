## D8b 画质三档冒烟（真实战斗页）：高 / 中 / 低各开一局，同样的满场单位 + 一发火球。
## 校验各档在真实场景树里的落实：阴影开关与单层模式、低档贴地圆影跟随单位、渲染倍率与 LOD 阈值、
## 脚环与血条合批数量；可选 --shot <dir> 非 headless 运行时各档出一张全屏截图（d8b_high/mid/low.png）供对比。
## 用法：godot --path . --resolution 750x1334 --script res://tools/check_quality_3d.gd -- --shot <dir>
extends SceneTree

const GameStateScript := preload("res://view/game_state.gd")
const UnitScript := preload("res://logic/unit.gd")
const Quality := preload("res://view/three_d/quality.gd")
const UnitModels := preload("res://view/three_d/unit_models.gd")

var _shot_dir := ""
var _failures: Array[String] = []
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
	for lv in [Quality.HIGH, Quality.MID, Quality.LOW]:
		await _tier(lv)
	Quality.override_level = -1
	for failure in _failures:
		push_error(failure)
	var ok := _failures.is_empty() and _done == 3
	print("QUALITY_3D: ", "PASS" if ok else "FAIL (done=%d)" % _done)
	quit(0 if ok else 1)


func _tier(lv: int) -> void:
	var tag: String = ["low", "mid", "high"][lv]
	Quality.override_level = lv
	GameStateScript.campaign = null
	GameStateScript.run = null
	GameStateScript.tutorial = false
	GameStateScript.stage_id = ""
	GameStateScript.level_id = "ladder_01"
	GameStateScript.player_deck = []
	var scene: Node = load("res://view/battle_scene.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_process(false)
	var field = scene.get("_field3d")
	var m = scene.get("match_obj")
	m.set_opponent_controller(null)
	var ids: Array = UnitModels.MODELS.keys()
	for k in 24:
		var owner := k % 2
		var unit_id: String = ids[k % ids.size()]
		var pos := Vector2(5.0 + float(k % 12) * 1.4, 21.0 + float(k / 12) * 2.0 if owner == 0 else 7.0 + float(k / 12) * 2.0)
		var u = UnitScript.new(unit_id, owner, GameStateScript.config().get_unit(unit_id), pos)
		u.take_damage(u.max_hp * 0.3)
		m.battle.arena.add_unit(u)
	for f in 30:
		scene._process(1.0 / 60.0)
	m.player.skill_system.play_card("fireball", 0, Vector2(13.0, 8.0))
	m.player.play_observer.on_card_played(0, "fireball", Vector2(13.0, 8.0))
	for f in 12:
		scene._process(1.0 / 60.0)
	var p: Dictionary = Quality.PROFILES[lv]
	var sun := field.get_node("Sun") as DirectionalLight3D
	if sun.shadow_enabled != (lv != Quality.LOW) or sun.directional_shadow_mode != DirectionalLight3D.SHADOW_ORTHOGONAL:
		_failures.append("%s：阴影设置不符" % tag)
	if absf(root.scaling_3d_scale - float(p["scale3d"])) > 0.001 or absf(root.mesh_lod_threshold - float(p["lod_px"])) > 0.001:
		_failures.append("%s：渲染倍率/LOD 阈值未应用（%s / %s）" % [tag, root.scaling_3d_scale, root.mesh_lod_threshold])
	var alive: int = field.presenter.unit_actor_count() + field.presenter.dying_count()
	var blobs: int = field.presenter.blob_count()
	if (lv == Quality.LOW and blobs < alive) or (lv != Quality.LOW and blobs != 0):
		_failures.append("%s：圆影数 %d（单位 %d）" % [tag, blobs, alive])
	if field.presenter.batches.ring_count() != alive:
		_failures.append("%s：脚环合批 %d ≠ 单位 %d" % [tag, field.presenter.batches.ring_count(), alive])
	if field.presenter.batches.bar_count() < 1:
		_failures.append("%s：受伤单位没有血条" % tag)
	print("QUALITY_3D: %s 单位=%d 圆影=%d 脚环=%d 血条=%d 特效件=%d" % [tag, alive, blobs,
		field.presenter.batches.ring_count(), field.presenter.batches.bar_count(), field.fx.active_parts()])
	if _shot_dir != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_shot_dir.path_join("d8b_%s.png" % tag))
	root.remove_child(scene)
	scene.free()
	await process_frame
	_done += 1
