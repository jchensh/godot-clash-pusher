## D8b 画质三档：档位表单调、平台默认、存读与自动调档（下次进页才生效、手动锁定）、各档在战斗 3D 层的落实
## （阴影/圆影/描边/投影/动画频率/粒子/特效上限/合批脚环与血条），以及任何档位都不影响对局 hash。
extends "res://tests/test_case.gd"

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const UnitScript := preload("res://logic/unit.gd")
const AIControllerScript := preload("res://ai/ai_controller.gd")
const BattleField3D := preload("res://view/three_d/battle_field_3d.gd")
const Quality := preload("res://view/three_d/quality.gd")

const SCREEN := Vector2(750, 1334)
const DECK := ["fireball", "arrows", "zap", "knight", "archers", "giant", "goblins", "minions"]

var _loader = null


func _config():
	if _loader == null:
		_loader = Loader.new()
		_loader.load_all()
	return _loader


func _field(m, level: int):
	Quality.override_level = level
	var field = BattleField3D.new()
	field.setup(m.battle, _config(), SCREEN, 54.0, 176.0, {"players": [m.player, m.opponent]})
	return field


func _dispose(field) -> void:
	field.presenter.clear()
	field.free()
	Quality.override_level = -1


func _has_outline(node: Node) -> bool:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = (mi as MeshInstance3D).get_surface_override_material(0)
		if mat == null:
			mat = (mi as MeshInstance3D).material_override
		if mat != null and mat.next_pass != null:
			return true
	return false


func _casts(node: Node) -> bool:
	for gi in node.find_children("*", "GeometryInstance3D", true, false):
		if (gi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return true
	return false


func test_profiles_are_ordered() -> void:
	var hi: Dictionary = Quality.PROFILES[Quality.HIGH]
	var mid: Dictionary = Quality.PROFILES[Quality.MID]
	var lo: Dictionary = Quality.PROFILES[Quality.LOW]
	assert_true(hi["scale3d"] > mid["scale3d"] and mid["scale3d"] > lo["scale3d"], "渲染倍率 高>中>低")
	assert_true(hi["lod_px"] < mid["lod_px"] and mid["lod_px"] < lo["lod_px"], "LOD 阈值 高<中<低（低档更早换低模）")
	assert_true(hi["particles"] >= mid["particles"] and mid["particles"] >= lo["particles"], "粒子量逐档减少")
	assert_eq(str(lo["shadow"]), "blob", "低档 = 贴地圆影")
	for lv in [Quality.LOW, Quality.MID, Quality.HIGH]:
		Quality.override_level = lv
		assert_true(Quality.outline("unit"), "%s 档单位恒描边" % Quality.LABELS[lv])
	Quality.override_level = -1
	assert_eq(Quality.default_for({"web": true, "mobile": true}), Quality.LOW, "网页/小游戏默认低")
	assert_eq(Quality.default_for({"mobile": true}), Quality.MID, "手机原生默认中")
	assert_eq(Quality.default_for({}), Quality.HIGH, "电脑默认高")


func test_save_load_and_auto_tune() -> void:
	var keep_path := Quality.settings_path
	Quality.settings_path = "user://test_quality_%d.cfg" % Time.get_ticks_usec()
	Quality._level = -1
	Quality._pending = -1
	Quality.set_level(Quality.MID, false)
	Quality._level = -1   # 模拟重启：从盘读
	assert_eq(Quality.level(), Quality.MID, "存盘后读回")
	assert_false(Quality.is_manual(), "自动档")
	assert_eq(Quality.auto_tune(8.0), Quality.HIGH, "帧耗时很低 → 下次升一档")
	assert_eq(Quality.level(), Quality.MID, "一局中途不切换")
	Quality.begin_scene(null)
	assert_eq(Quality.level(), Quality.HIGH, "下次进 3D 页生效")
	assert_eq(Quality.auto_tune(8.0), Quality.HIGH, "已是最高档不再升")
	assert_eq(Quality.auto_tune(55.0), Quality.MID, "帧耗时过高 → 降一档")
	Quality.begin_scene(null)
	assert_eq(Quality.auto_tune(30.0), Quality.MID, "30 毫秒左右保持不动")
	Quality.set_level(Quality.LOW, true)
	assert_eq(Quality.auto_tune(5.0), Quality.LOW, "手动选过的档不自动调")
	Quality._level = -1
	assert_true(Quality.is_manual() and Quality.level() == Quality.LOW, "手动标记存盘")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.settings_path))
	Quality.settings_path = keep_path
	Quality._level = -1
	Quality._pending = -1
	Quality.session_tuned = false


## 回归：自动调档待生效后玩家手选，手选必须赢（不被下一次 begin_scene 覆盖）；设置页高亮看待生效档。
func test_manual_pick_overrides_pending_auto_tune() -> void:
	var keep_path := Quality.settings_path
	Quality.settings_path = "user://test_quality_pick_%d.cfg" % Time.get_ticks_usec()
	Quality._level = -1
	Quality._pending = -1
	Quality.session_tuned = false
	Quality.set_level(Quality.MID, false)
	assert_true(Quality.wants_tune(), "自动档、本次启动未调过 → 需要调档")
	assert_eq(Quality.auto_tune(8.0), Quality.HIGH, "自动调档：下次升到高")
	assert_eq(Quality.next_level(), Quality.HIGH, "设置页高亮待生效档")
	assert_false(Quality.wants_tune(), "每次启动只自动调一次")
	Quality.set_level(Quality.LOW, true)
	Quality.begin_scene(null)
	assert_eq(Quality.level(), Quality.LOW, "手选清掉待生效的自动结果")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Quality.settings_path))
	Quality.settings_path = keep_path
	Quality._level = -1
	Quality._pending = -1
	Quality.session_tuned = false


func test_frame_p90_drops_outliers() -> void:
	var samples: Array = []
	for i in 80:
		samples.append(16.0)
	for i in 20:
		samples.append(3000.0)   # 切后台 / 断线追帧
	assert_almost_eq(Quality.frame_p90(samples), 16.0, 0.001, "异常长帧不计入 p90")
	assert_eq(Quality.frame_p90([16.0, 3000.0, 3000.0]), -1.0, "有效样本不足不下结论")


## 回归：断线重连对同一战场节点再 setup，不得在局中换档（光照只建一次，换档会让阴影方案错乱）。
func test_reconnect_setup_keeps_tier() -> void:
	var m = MatchScript.new(_config())
	m.setup_stage("stage_1_1", DECK, null, {})
	var field = BattleField3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(field)   # 进树才走 begin_scene
	Quality.session_tuned = true
	field.setup(m.battle, _config(), SCREEN, 54.0, 176.0, {"players": [m.player, m.opponent]})
	Quality._pending = Quality.LOW   # 局内自动调档结果：重连时不得生效
	var again = MatchScript.new(_config())
	again.setup_stage("stage_1_1", DECK, null, {})
	field.setup(again.battle, _config(), SCREEN, 54.0, 176.0, {"players": [again.player, again.opponent]})
	assert_eq(field.get_children().filter(func(n): return n.name.begins_with("Sun")).size(), 1, "光照不重复建")
	assert_eq(Quality._pending, Quality.LOW, "重连不消费待生效档（留到下一局）")
	Quality._pending = -1
	Quality.session_tuned = false
	field.get_parent().remove_child(field)
	_dispose(field)


func test_batches_grow_past_capacity() -> void:
	const Batches := preload("res://view/three_d/battle_batches.gd")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = Batches.CAPACITY
	Batches._ensure(mm, Batches.CAPACITY + 5)
	assert_eq(mm.instance_count, Batches.CAPACITY * 2, "超出容量翻倍扩容，不丢实例")
	Batches._ensure(mm, 10)
	assert_eq(mm.instance_count, Batches.CAPACITY * 2, "够用时不缩不动")


func test_viewport_follows_tier() -> void:
	var vp := SubViewport.new()
	for lv in [Quality.LOW, Quality.MID, Quality.HIGH]:
		Quality.override_level = lv
		Quality.apply_viewport(vp)
		assert_almost_eq(vp.scaling_3d_scale, float(Quality.PROFILES[lv]["scale3d"]), 0.001, "渲染倍率按档")
		assert_almost_eq(vp.mesh_lod_threshold, float(Quality.PROFILES[lv]["lod_px"]), 0.001, "LOD 阈值按档")
	Quality.override_level = -1
	vp.free()


func test_battle_layer_per_tier() -> void:
	for lv in [Quality.LOW, Quality.MID, Quality.HIGH]:
		var tag: String = Quality.LABELS[lv]
		var m = MatchScript.new(_config())
		m.setup_stage("stage_1_1", DECK, null, {})
		var field = _field(m, lv)
		var hurt = UnitScript.new("archer_body", 0, _config().get_unit("archer_body"), Vector2(13.0, 22.0))
		hurt.take_damage(40.0)
		m.battle.arena.add_unit(hurt)
		m.battle.arena.add_unit(UnitScript.new("knight_body", 1, _config().get_unit("knight_body"), Vector2(9.0, 8.0)))
		field.advance(0.05)
		var sun := field.get_node("Sun") as DirectionalLight3D
		assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL, "%s：阴影单层" % tag)
		assert_eq(sun.shadow_enabled, lv != Quality.LOW, "%s：实时阴影开关" % tag)
		var blobs: int = field.presenter.blob_count()
		assert_eq(blobs, (2 + 6) if lv == Quality.LOW else 0, "%s：圆影 = 单位 + 塔（仅低档）" % tag)
		var actor = field.presenter.actor_for(hurt)
		assert_true(_has_outline(actor), "%s：单位恒描边" % tag)
		assert_eq(_casts(actor.get_node("Visual")), lv != Quality.LOW, "%s：单位投影" % tag)
		if lv == Quality.LOW:
			assert_eq(actor._player.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "低档动画手动推进")
		var tower = field.presenter.tower_actor_for(m.battle.player_towers[0])
		assert_eq(_has_outline(tower), lv != Quality.LOW, "%s：塔描边" % tag)
		var fence: Node = field.presenter.find_child("Fence", true, false)
		assert_eq((fence as GeometryInstance3D).material_override.next_pass != null, lv == Quality.HIGH, "%s：场边点缀描边" % tag)
		assert_eq((fence as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, lv == Quality.HIGH,
			"%s：场边点缀投影" % tag)
		assert_eq(field.presenter.batches.ring_count(), 2, "%s：脚环合批 = 单位数" % tag)
		assert_eq(field.presenter.batches.bar_count(), 1, "%s：血条合批 = 受伤单位数" % tag)
		assert_null(actor.get_node_or_null("TeamRing"), "%s：单位不再各自建脚环" % tag)
		field.fx.cast("fireball", 0, Vector2(9.0, 8.0))
		assert_eq(int(field.fx.stats["particles"]) > 0, lv != Quality.LOW, "%s：粒子（低档不放）" % tag)
		var solid: MeshInstance3D = field.fx.solid("blob", Color.WHITE, Vector3.ZERO, 1.0, true)
		assert_eq((solid.material_override as Material).next_pass != null, lv != Quality.LOW, "%s：特效件描边" % tag)
		assert_eq(solid.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, lv == Quality.HIGH, "%s：特效件投影" % tag)
		_dispose(field)


func test_fx_cap_limits_optional_effects() -> void:
	var m = MatchScript.new(_config())
	m.setup_stage("stage_1_1", DECK, null, {})
	var field = _field(m, Quality.LOW)
	for i in 6:
		field.fx.cast("arrows", 0, Vector2(13.0, 10.0))   # 每次 14 支箭 + 范围环
	var cap: int = Quality.PROFILES[Quality.LOW]["fx_cap"]
	assert_true(field.fx.active_parts() >= cap, "法术恒放，可超过上限")
	field.fx._on_hit(12345, Vector2(1.0, 1.0), Vector3.ZERO, 50.0, 100.0)
	assert_true(int(field.fx.stats["capped"]) >= 1, "超上限时受击星这类可选特效不放")
	_dispose(field)


func test_every_tier_is_hash_neutral() -> void:
	for lv in [Quality.LOW, Quality.HIGH]:
		var m = MatchScript.new(_config())
		m.setup_stage("stage_1_1", DECK, null, {})
		m.set_opponent_controller(AIControllerScript.new(m, _config(), m.ai_difficulty))
		var bare = MatchScript.new(_config())
		bare.setup_stage("stage_1_1", DECK, null, {})
		bare.set_opponent_controller(AIControllerScript.new(bare, _config(), bare.ai_difficulty))
		var field = _field(m, lv)
		for f in 200:
			for mm in [m, bare]:
				var hand: Array = mm.player.deck.get_hand()
				for i in hand.size():
					if mm.player.can_play(i) and mm.player.try_play_card(i, Vector2(7.0 + f % 12, 24.0 if i % 2 == 0 else 8.0)):
						break
			m.update(0.2)
			field.advance(0.2)
			bare.update(0.2)
			if m.state_hash() != bare.state_hash():
				assert_true(false, "%s 档 hash 在第 %d 帧分叉" % [Quality.LABELS[lv], f])
				break
			if m.is_over():
				break
		_dispose(field)
