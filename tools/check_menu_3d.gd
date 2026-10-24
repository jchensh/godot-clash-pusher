## D7 页面 3D 冒烟（真实场景树，不联网）：Online 换成桩（配置=仓库 JSON、登录恒成功、经济=固定快照）。
## ①卡牌详情：兵牌显示 3D 角色、点一下切动作、同卡刷新不重载模型；法术卡退回 2D 肖像
## ②主菜单：章节主视觉是 3D 小场景且不吃点击 ③登录页：底部 3D 小场景不压表单。
## 可选 --shot <dir>：非 headless 运行时截图（自检用）。
## 用法：godot --headless --path . --script res://tools/check_menu_3d.gd
extends SceneTree

const Loader := preload("res://logic/config_loader.gd")
const GameStateScript := preload("res://view/game_state.gd")

var _failures: Array[String] = []
var _shot_dir := ""
var _menu_script: GDScript


class CacheStub:
	var gold := 12000
	var gems := 300
	var stages := {}

	func is_unlocked(_cid) -> bool:
		return true

	func card_state(_cid) -> Dictionary:
		return {"level": 3, "rank": 2, "shards": 40}

	func card_power(_cid, _config) -> int:
		return 1234

	func card_stat_mult(_cid, _config) -> float:
		return 1.2

	func level_cap(_rank, _config) -> int:
		return 10

	func upgrade_cost(_cid, _config) -> int:
		return 500

	func rank_up_cost(_cid, _config) -> Dictionary:
		return {"shards": 50, "gold": 2000}

	func can_unlock(_cid, _config) -> bool:
		return false


class EconomyStub:
	var is_loaded := true
	var cache := CacheStub.new()

	func get_cache():
		return cache

	func refresh(_http, _token, _ids) -> Dictionary:
		return {"ok": true}


class KingdomStub:
	var cache := {}
	var is_loaded := false

	func refresh(_http, _token) -> Dictionary:
		return {"ok": true}


class OnlineStub extends Node:
	var loader
	var econ := EconomyStub.new()
	var kd := KingdomStub.new()

	func is_online_ready() -> bool:
		return true

	func config():
		return loader

	func economy():
		return econ

	func kingdom():
		return kd

	func ensure(_http) -> bool:
		return true

	func needs_login() -> bool:
		return true

	func token() -> String:
		return ""

	func nickname() -> String:
		return "测试员"

	func avatar_card_id() -> String:
		return "knight"

	func trophies() -> int:
		return 120


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
	root.add_child(stub)
	await _check_card_detail()
	await _check_main_menu()
	await _check_login()
	for failure in _failures:
		push_error(failure)
	print("MENU_3D: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)


func _open(path_or_script) -> Node:
	var page: Node
	if path_or_script is GDScript:
		page = (path_or_script as GDScript).new()
	else:
		page = (load(str(path_or_script)) as PackedScene).instantiate()
	root.add_child(page)
	current_scene = page
	for f in 4:
		await process_frame
	return page


func _close(page: Node) -> void:
	root.remove_child(page)
	page.free()
	await process_frame


func _check_card_detail() -> void:
	GameStateScript.detail_card = "knight"
	var page := await _open("res://view/card_detail.tscn")
	var stage = page.get("_stage")
	if stage == null or not stage.visible or not stage.has_model():
		_failures.append("卡牌详情（兵牌）未显示 3D 角色")
	else:
		var held: Node3D = stage.model()
		var before: String = stage.action
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		stage._gui_input(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		stage._gui_input(release)
		if stage.action == before:
			_failures.append("点 3D 角色未切换动作（%s）" % before)
		page._populate()   # 经济刷新（升级后）重建内容
		await process_frame
		if stage.model() != held:
			_failures.append("同一张卡刷新后不应重载模型")
		await _shot("card_detail")
	await _close(page)
	GameStateScript.detail_card = "fireball"
	page = await _open("res://view/card_detail.tscn")
	var spell_stage = page.get("_stage")
	if spell_stage != null and spell_stage.visible:
		_failures.append("法术卡不应显示 3D 预览台")
	await _shot("card_detail_spell")
	await _close(page)


func _check_main_menu() -> void:
	# 子类化屏蔽登录路由：直接建菜单 + 用经济桩回填（运行时编译，避开加载期 autoload 全局名未注册）。
	_menu_script = GDScript.new()
	_menu_script.source_code = "\n".join(["extends \"res://view/main_menu.gd\"", "",
		"func _bootstrap() -> void:", "\t_build_menu()", "\t_populate(GameStateScript.economy().get_cache(), GameStateScript.config())", ""])
	if _menu_script.reload() != OK:
		_failures.append("主菜单测试子类编译失败")
		return
	var page := await _open(_menu_script)
	var dio = page.get_node_or_null("ShowpieceDiorama")
	if dio == null or dio.model_count() < 8:
		_failures.append("主菜单章节主视觉未建 3D 小场景")
	elif dio.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_failures.append("主视觉小场景不应吃点击")
	await _shot("main_menu")
	await _close(page)


func _check_login() -> void:
	var page := await _open("res://view/login.tscn")
	var dio = page.get_node_or_null("LoginDiorama")
	var btn: Button = page.get("_enter_btn")
	if dio == null or dio.model_count() < 8:
		_failures.append("登录页未建 3D 小场景")
	elif btn != null and Rect2(dio.position, dio.size).intersects(Rect2(btn.position, btn.size)):
		_failures.append("登录页小场景压住了进入按钮")
	await _shot("login")
	await _close(page)


func _shot(label: String) -> void:
	if _shot_dir == "":
		return
	for f in 6:
		await process_frame
	root.get_texture().get_image().save_png(_shot_dir.path_join("d7_%s.png" % label))
