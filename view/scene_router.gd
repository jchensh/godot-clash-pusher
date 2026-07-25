# SceneRouter（autoload `Router`）—— 场景路由（框架地基#1，KAN-99）。
#
# 借鉴 crystal-bit godot-game-template（GGT）的集中式场景管理：全工程唯一切场景入口。
# - ROUTES 路由表集中登记全部可达场景（替代各文件散装路径常量与硬编码字符串）；
# - Router.goto("stage_map") 切场景：黑幕淡出→换场→淡入，转场期幕布 STOP 挡输入（防连点）；
#   转场中再到的 goto（如新场景 _ready 登录路由重定向）暂存接力、不丢单——黑幕保持到终点不闪屏；
# - Router.reload() 重载当前路由（params 保留）；引擎直启场景（编辑器 F6）无路由历史时退引擎 reload；
# - params 随路由传递：目标场景 _ready 里 Router.param("key") 读。为 GameState 静态握手参数化
#   铺路——本步存量握手不动（KAN-99「不做」），后续步逐流迁移。
# 层级：转场幕布 CanvasLayer=100，恒高于 MODAL=50 / TOAST=90（ui_layers.gd）——转场压一切。
# 规约：view 层禁止直调 get_tree().change_scene_to_file / reload_current_scene
#   （test_scene_router 规约扫描把关，唯一豁免 = 本文件）。
extends Node

const GameStateScript := preload("res://view/game_state.gd")
const LandscapeWrap := preload("res://view/ui/landscape_wrap.gd")
const TRANSITION_LAYER := 100
const FADE_S := 0.15

# 全部可达场景。加新场景先在此登记再 goto（test_scene_router 校验 view/ 根下 tscn 全登记 + 路径存在）。
const ROUTES := {
	"main_menu": "res://view/main_menu.tscn",
	"battle": "res://view/battle_scene.tscn",
	"net_battle": "res://view/net_battle_scene.tscn",
	"run": "res://view/run_scene.tscn",
	"stage_map": "res://view/stage_map.tscn",
	"level_select": "res://view/level_select.tscn",
	"campaign": "res://view/campaign_scene.tscn",
	"deck_builder": "res://view/deck_builder.tscn",
	"card_collection": "res://view/card_collection.tscn",
	"card_detail": "res://view/card_detail.tscn",
	"base_camp": "res://view/base_camp.tscn",
	"kingdom": "res://view/kingdom.tscn",
	"settings": "res://view/settings.tscn",
	"account_create": "res://view/account_create.tscn",
	"login": "res://view/login.tscn",
}

var _layer: CanvasLayer
var _dim: ColorRect
var _route := ""
var _params: Dictionary = {}
var _busy := false
var _pending: Array = []   # 转场中到达的 goto 暂存 [route, params]（只留最后一个，收尾接力）

func _init() -> void:
	# _init 装配（对齐 ui_layers.gd）：headless 单测手动实例化同样可用。
	_layer = CanvasLayer.new()
	_layer.layer = TRANSITION_LAYER
	add_child(_layer)
	_dim = ColorRect.new()
	_dim.color = Color.BLACK
	_dim.modulate.a = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 静止时不挡手；仅转场期 STOP
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # ⚠️ 带 offsets 版才真铺满（见 modal.gd 同注释）
	_layer.add_child(_dim)

func _ready() -> void:
	apply_ui_layout()   # 开机即按持久化偏好定窗口方向（autoload 先于主场景，首屏就是对的）
	_wrap_boot_scene.call_deferred()   # 引擎直启的主场景不走 goto → 横屏下补包壳

func _wrap_boot_scene() -> void:
	if GameStateScript.ui_layout() != "landscape":
		return
	var cs := get_tree().current_scene
	if cs == null or cs.get_script() == LandscapeWrap:
		return
	var path := cs.scene_file_path
	var mode := _wrap_mode(path)
	if mode == "":
		return   # 战斗场景自适配横屏，不包壳
	get_tree().root.remove_child(cs)   # 原地收养进壳（不重建场景，_ready 已跑过的状态保留）
	var target: Node = LandscapeWrap.wrap(cs, mode)
	get_tree().root.add_child(target)
	get_tree().current_scene = target
	Log.i("[Router] 开机场景已包横屏壳（%s，%s）" % [path, mode])

# —— 全局横屏模式（L1，2026-07-26）：窗口/方向/内容缩放的唯一切换收口 ——
# 桌面=改窗口尺寸并居中；移动端=切屏幕方向；Web=只改逻辑分辨率（浏览器自己转）。
# 逻辑分辨率 720×1280 ↔ 1280×720（40px/格 信息密度不变）；页面重建靠调用方 reload/goto。
func apply_ui_layout() -> void:
	var land: bool = GameStateScript.ui_layout() == "landscape"
	var base := Vector2i(1280, 720) if land else Vector2i(720, 1280)
	get_tree().root.content_scale_size = base
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(
				DisplayServer.SCREEN_SENSOR_LANDSCAPE if land else DisplayServer.SCREEN_PORTRAIT)
	elif not OS.has_feature("web") and not DisplayServer.get_name() == "headless":
		var win := get_window()
		if win.mode == Window.MODE_WINDOWED:
			win.size = base
			var scr := DisplayServer.screen_get_usable_rect(win.current_screen)
			win.position = scr.position + (scr.size - win.size) / 2

# 路由名 → 场景路径；也接受 res:// 原始路径直通（动态路径调用方用）。未知返回 ""。
func resolve(route: String) -> String:
	if ROUTES.has(route):
		return String(ROUTES[route])
	if route.begins_with("res://"):
		return route
	return ""

# 唯一切场景入口（fire-and-forget 协程，调用方不必 await）。
func goto(route: String, params: Dictionary = {}) -> void:
	var path := resolve(route)
	if path == "":
		push_error("[Router] 未知路由: %s" % route)
		return
	if _busy:
		# 不丢单：新场景 _ready 里的自动重定向（登录路由/报到失败弹回）常落在转场收尾窗口内。
		Log.i("[Router] 转场进行中，暂存接力 goto(%s)" % route)
		_pending = [route, params]
		return
	_busy = true
	_begin_route(route, params)
	Log.i("[Router] goto %s (%s)" % [route, path])
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	var err := _switch_scene(path)
	if err != OK:
		push_error("[Router] 切场景失败 err=%d path=%s" % [err, path])
	await get_tree().process_frame   # change_scene 延迟生效：等新场景挂树再揭幕
	await get_tree().process_frame
	if _pending.is_empty():
		await _fade_to(0.0)
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	_flush_pending()   # 转场中重定向过 → 幕布保持黑、直接接力去终点（不闪屏）

# L2 全局横屏：竖屏走引擎原生换场；横屏手动实例化 + LandscapeWrap 包壳。
# L3：单机战斗不包壳（battle_scene 自带真横屏满屏投影）；教程战斗例外包 fit 保竖版画布
# （教程高亮是竖版语义）；联机/战役=fit 过渡（H6 另排）；菜单页=scroll 居中立柱。
func _switch_scene(path: String) -> int:
	if GameStateScript.ui_layout() != "landscape":
		return get_tree().change_scene_to_file(path)
	var ps := load(path) as PackedScene
	if ps == null:
		return ERR_CANT_OPEN
	var page := ps.instantiate()
	var mode := _wrap_mode(path)
	var target: Node = page if mode == "" else LandscapeWrap.wrap(page, mode)
	var old := get_tree().current_scene
	get_tree().root.add_child(target)
	get_tree().current_scene = target
	if old != null:
		old.queue_free()
	return OK

# L4 起原生横屏页面白名单：已按 mockup 实装横屏布局的页面不再包壳，逐页迁移逐页加。
const LANDSCAPE_NATIVE := ["res://view/main_menu.tscn", "res://view/stage_map.tscn",
	"res://view/deck_builder.tscn", "res://view/card_collection.tscn"]

# 返回包壳模式；"" = 不包壳（场景自适配横屏）。⚠️ net_battle_scene 也含 "battle_scene"
# 子串，判断顺序要先网络后单机。
func _wrap_mode(path: String) -> String:
	if path.ends_with("net_battle_scene.tscn") or path.contains("campaign_scene"):
		return "fit"
	if path.ends_with("battle_scene.tscn"):
		return "fit" if GameStateScript.tutorial else ""
	if path in LANDSCAPE_NATIVE:
		return ""
	return "scroll"

# 重载当前路由（params 保留）。设置页换语言重建、战斗「再来一局」用。
func reload() -> void:
	if _route != "":
		goto(_route, _params)
	else:
		get_tree().reload_current_scene()   # 编辑器 F6 直启场景无路由历史 → 引擎兜底

func current_route() -> String:
	return _route

func route_params() -> Dictionary:
	return _params

func param(key: String, def = null):
	return _params.get(key, def)

func _begin_route(route: String, params: Dictionary) -> void:
	_route = route
	_params = params.duplicate(true)   # 深拷贝隔离：调用方事后改自己的字典不影响路由参数

func _flush_pending() -> void:
	if _pending.is_empty():
		return
	var route: String = _pending[0]
	var params: Dictionary = _pending[1]
	_pending = []
	goto(route, params)

func _fade_to(a: float) -> void:
	if absf(_dim.modulate.a - a) < 0.001:
		return   # 已在目标态（接力链上避免 0.15s 空等）
	var tw := _dim.create_tween()
	tw.tween_property(_dim, "modulate:a", a, FADE_S)
	await tw.finished
