## D8 战斗性能近似测量（电脑上按手机分辨率跑真实战斗页，真机实测另记欠账）。
## 场景：自由对战页，双方持续补兵把场上存活单位维持在 --units 个（25 种正式模型轮换，含骨骼动画），
## 每秒交替放一张法术（10 种轮换）+ 远程开火/受击/阵亡特效自然产生；塔设为打不掉，保证测量窗口内满场。
## 关垂直同步、不限帧，热身 3 秒后逐帧采样 --seconds 秒：帧耗时、脚本处理耗时、渲染 CPU/GPU 耗时、draw call、
## 渲染物体数、图元（三角面，含描边与阴影 pass）、骨架/骨骼数、静态内存、显存、特效件数。结果打印 PERF_JSON 一行。
## 用法：godot --path . --resolution 750x1334 --script res://tools/perf_battle_3d.gd -- --units 30 --seconds 20
## 只读测量：不改任何画质/降配设置（D8 用户决策：降配方案由用户拍板）。
extends SceneTree

const GameStateScript := preload("res://view/game_state.gd")
const UnitScript := preload("res://logic/unit.gd")
const UnitModels := preload("res://view/three_d/unit_models.gd")
const Catalog := preload("res://view/three_d/fx_catalog.gd")

var _units := 30
var _fx := true
var _scale3d := 1.0
var _page_us := 0
var _seconds := 20.0
var _scene: Node
var _field
var _m
var _rid: RID
var _samples: Array = []
var _spell_i := 0
var _spawn_i := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--units")
	if i >= 0:
		_units = int(args[i + 1])
	_fx = args.find("--no-fx") < 0
	i = args.find("--scale3d")   # 3D 渲染倍率：1.44 ≈ 1080 宽手机物理分辨率（窗口受显示器限制开不到时用）
	if i >= 0:
		_scale3d = float(args[i + 1])
	i = args.find("--seconds")
	if i >= 0:
		_seconds = float(args[i + 1])
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	_field = _scene.get("_field3d")
	_m = _scene.get("match_obj")
	_m.set_opponent_controller(null)
	_scene.set_process(false)   # 由本脚本逐帧代调，便于计时页面处理耗时
	if not _fx:   # 对照：关掉特效层（只测单位/地形/HUD）
		_field.fx.clear()
		_field.fx.set("_battle", null)
	_m.battle.match_duration = 0.0   # 不计时
	for t in _m.battle.player_towers + _m.battle.opponent_towers:
		t.max_hp = 1.0e9
		t.hp = 1.0e9
	root.scaling_3d_scale = _scale3d
	_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	var t := 0.0
	var spell_t := 0.0
	while t < 3.0 + _seconds:
		await process_frame
		var dt := maxf(Engine.get_main_loop().root.get_process_delta_time(), 0.0001)
		t += dt
		_fill_units()
		var t0 := Time.get_ticks_usec()
		_scene._process(dt)
		_page_us = Time.get_ticks_usec() - t0
		spell_t += dt
		if spell_t >= 1.0 and _fx:
			spell_t = 0.0
			_cast_spell()
		if t >= 3.0:
			_sample(dt)
	_report()
	quit(0)


func _fill_units() -> void:
	var alive := 0
	for u in _m.battle.arena.get_units():
		if u.is_alive():
			alive += 1
	var ids: Array = UnitModels.MODELS.keys()
	while alive < _units:
		var unit_id: String = ids[_spawn_i % ids.size()]
		var owner := _spawn_i % 2
		var y := randf_range(17.0, 26.0) if owner == 0 else randf_range(4.0, 13.0)
		var pos := Vector2(randf_range(4.0, 22.0), y)
		var u = UnitScript.new(unit_id, owner, GameStateScript.config().get_unit(unit_id), pos)
		_m.battle.arena.add_unit(u)
		_spawn_i += 1
		alive += 1


func _cast_spell() -> void:
	var cids: Array = Catalog.SPELLS.keys()
	var cid: String = cids[_spell_i % cids.size()]
	var owner := _spell_i % 2
	var pos := Vector2(randf_range(6.0, 20.0), randf_range(5.0, 12.0) if owner == 0 else randf_range(18.0, 25.0))
	var p = _m.player if owner == 0 else _m.opponent
	p.skill_system.play_card(cid, owner, pos)
	p.play_observer.on_card_played(owner, cid, pos)
	_spell_i += 1


func _sample(dt: float) -> void:
	var skeletons := 0
	var bones := 0
	for node in _field.find_children("*", "Skeleton3D", true, false):
		if (node as Node3D).is_visible_in_tree():
			skeletons += 1
			bones += (node as Skeleton3D).get_bone_count()
	_samples.append({
		"frame_ms": dt * 1000.0,
		"page_ms": _page_us / 1000.0,
		"presenter_ms": _field.presenter_usec / 1000.0,
		"fx_ms": _field.fx_usec / 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_rid)
			+ RenderingServer.get_frame_setup_time_cpu(),
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_rid),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"units": _field.presenter.unit_actor_count() + _field.presenter.dying_count(),
		"skeletons": skeletons,
		"bones": bones,
		"fx_parts": _field.fx.active_parts(),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	})


func _report() -> void:
	var win := DisplayServer.window_get_size()
	var out := {"fx": _fx, "scale3d": _scale3d, "resolution": "%dx%d" % [win.x, win.y], "target_units": _units,
		"frames": _samples.size(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method()}
	for key in _samples[0].keys():
		var values: Array = []
		for s in _samples:
			values.append(float(s[key]))
		values.sort()
		var total := 0.0
		for v in values:
			total += v
		out[key] = {"avg": snappedf(total / values.size(), 0.01),
			"p95": snappedf(values[int(values.size() * 0.95)], 0.01), "max": snappedf(values[-1], 0.01)}
	print("PERF_JSON ", JSON.stringify(out))
