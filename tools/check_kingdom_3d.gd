## D6 王国页 3D 冒烟（真实场景树，不联网）：Online 换成桩（配置=仓库 JSON、王国状态=固定快照、登录恒成功），
## 检查：①3D 场景就绪（16 槽、居民、镜头生效且投影与引擎一致）②建筑形态跟状态（空地/施工脚手架/建成；
## 状态变化后自动更新）③点建筑 → 弹该建筑操作窗；拖动平移不触发点选；滚轮缩放有界 ④居民在走。
## 可选 --shot <dir>：非 headless 运行时截图（自检用）。
## 用法：godot --headless --path . --script res://tools/check_kingdom_3d.gd
extends SceneTree

const Loader := preload("res://logic/config_loader.gd")
const KingdomCamera := preload("res://view/three_d/kingdom_camera.gd")

var _failures: Array[String] = []
var _shot_dir := ""


class KingdomStub:
	var cache: Dictionary = {}
	var is_loaded := true
	var remaining: Dictionary = {}

	func refresh(_http, _token) -> Dictionary:
		return {"ok": true}

	func remaining_s(building: String) -> int:
		return int(remaining.get(building, 0))

	func building_level(building: String) -> int:
		return int(((cache.get("buildings", {}) as Dictionary).get(building, {}) as Dictionary).get("level", 0))

	func get_cache() -> Dictionary:
		return cache


class EconomyStub:
	func get_cache():
		return {}


class OnlineStub extends Node:
	var loader
	var kingdom_stub := KingdomStub.new()
	var economy_stub := EconomyStub.new()

	func is_online_ready() -> bool:
		return true

	func config():
		return loader

	func kingdom():
		return kingdom_stub

	func economy():
		return economy_stub

	func ensure(_http) -> bool:
		return true

	func token() -> String:
		return ""

	func nickname() -> String:
		return "测试员"

	func avatar_card_id() -> String:
		return "knight"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i >= 0 and i + 1 < args.size():
		_shot_dir = args[i + 1]
	_check.call_deferred()


func _check() -> void:
	var loader = Loader.new()
	loader.load_all()
	var online := root.get_node_or_null("Online")
	if online != null:
		root.remove_child(online)
		online.free()
	var stub := OnlineStub.new()
	stub.name = "Online"
	stub.loader = loader
	# 状态快照：王城 3 级、农田 2 级、工坊未建、箭塔 1 级施工中、其余按序部分建成。
	var levels := {"keep": 3, "farm": 2, "workshop": 0, "watchtower": 1, "granary": 1, "mint": 1, "wall": 2,
		"quarry": 1, "stoneworks": 0, "ironworks": 1, "ranch": 1, "shop": 1, "camp_infantry": 1, "camp_spear": 0,
		"camp_crossbow": 1, "camp_cavalry": 1}
	var buildings := {}
	for b in levels:
		buildings[b] = {"level": levels[b]}
	stub.kingdom_stub.cache = {"buildings": buildings, "resources": {"food": 120, "wood": 80}, "pending": {}}
	stub.kingdom_stub.remaining = {"watchtower": 600}
	root.add_child(stub)
	var page: Control = load("res://view/kingdom.tscn").instantiate()
	root.add_child(page)
	current_scene = page
	for f in 3:
		await process_frame
	var world = page.get("_world")
	if world == null or not world.camera.current:
		_failures.append("王国 3D 场景未就绪或镜头未生效")
		_finish()
		return
	if world.slot_ids().size() != 16 or world.walker_count() < 4:
		_failures.append("槽位 %d / 居民 %d 不足" % [world.slot_ids().size(), world.walker_count()])
	_check_projection(world)
	_check_states(world, levels)
	await _shot("overview")
	world.look_at_px(Vector2(300, 1250))
	await _shot("scaffold")
	world.look_at_px(Vector2(705, 660))
	# 施工完成 → 脚手架自动拆；新建空地 → 建成。
	stub.kingdom_stub.remaining = {}
	(stub.kingdom_stub.cache["buildings"] as Dictionary)["workshop"] = {"level": 1}
	page._process(0.016)
	var s: Dictionary = world._slots
	if (s["watchtower"]["scaffold"] as Node3D).visible or not (s["workshop"]["model"] as Node3D).visible:
		_failures.append("状态变化后建筑形态未更新（拆脚手架 / 空地变建筑）")
	await _check_click(page, world)
	await _check_drag_zoom(page, world)
	var before: Vector3 = (world._walkers[0]["node"] as Node3D).position
	for f in 30:
		page._process(0.05)
	if (world._walkers[0]["node"] as Node3D).position.distance_to(before) < 0.05:
		_failures.append("居民没有走动")
	world.zoom_at(Vector2(375, 667), 0.6)
	await _shot("zoom_in")
	_finish()


func _check_projection(world) -> void:
	for px in [Vector2(705, 660), Vector2(150, 1420), Vector2(1350, 230)]:
		var w: Vector3 = world.to_world(px)
		var ours: Vector2 = world.world_to_screen(w)
		var engine: Vector2 = world.camera.unproject_position(w)
		if ours.distance_to(engine) > 0.5:
			_failures.append("投影不一致 %s ours=%s engine=%s" % [px, ours, engine])


func _check_states(world, levels: Dictionary) -> void:
	for b in levels:
		var s: Dictionary = world._slots[b]
		var built: bool = int(levels[b]) > 0
		if (s["model"] as Node3D).visible != built or (s["plot"] as Node3D).visible == built:
			_failures.append("%s 形态不对（level=%d）" % [b, levels[b]])
		var scaffold: bool = (s["scaffold"] as Node3D).visible
		if scaffold != (b == "watchtower"):
			_failures.append("%s 脚手架显示=%s" % [b, scaffold])
	for e in world._slots["watchtower"]["extras"]:
		if not (e as Node3D).visible:
			_failures.append("箭塔建成后角楼副本应现身")


## 点王城正面 → 弹王城操作窗；点空白地面 → 不弹。
func _check_click(page, world) -> void:
	var p: Vector2 = world.base_screen("keep") + Vector2(0, -20)
	page._click(p)
	await process_frame
	var ui = root.get_node("UI")
	var modal = _top_modal(ui)
	if modal == null or str(modal.get("building")) != "keep":
		_failures.append("点王城未弹出王城操作窗（%s）" % (str(modal.get("building")) if modal != null else "无弹窗"))
	if modal != null:
		modal.close()
		await process_frame


func _check_drag_zoom(page, world) -> void:
	var t0: Vector3 = world.target
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(375, 700)
	page._gui_input(press)
	for i in 6:
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(375 + i * 20, 700 + i * 10)
		page._gui_input(mv)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(475, 750)
	page._gui_input(release)
	await process_frame
	if world.target.distance_to(t0) < 0.5:
		_failures.append("拖动未平移镜头")
	if _top_modal(root.get_node("UI")) != null:
		_failures.append("拖动后不应弹窗")
	for i in 20:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = Vector2(375, 667)
		page._gui_input(wheel)
	if absf(world.size - KingdomCamera.SIZE_MAX) > 0.01:
		_failures.append("滚轮缩小应停在上限（size=%.2f）" % world.size)
	var b: Rect2 = world.bounds
	if not b.grow(0.01).has_point(Vector2(world.target.x, world.target.z)):
		_failures.append("镜头焦点越出城墙范围")


func _top_modal(ui):
	for layer in ui.get_children():
		for child in layer.get_children():
			if child.get("building") != null and child.is_inside_tree():
				return child
	return null


func _shot(label: String) -> void:
	if _shot_dir == "":
		return
	for f in 4:
		await process_frame
	root.get_texture().get_image().save_png(_shot_dir.path_join("d6_%s.png" % label))


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("KINGDOM_3D: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)
