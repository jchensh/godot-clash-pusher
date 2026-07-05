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
	"settings": "res://view/settings.tscn",
	"account_create": "res://view/account_create.tscn",
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
		print("[Router] 转场进行中，暂存接力 goto(%s)" % route)
		_pending = [route, params]
		return
	_busy = true
	_begin_route(route, params)
	print("[Router] goto %s (%s)" % [route, path])
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[Router] 切场景失败 err=%d path=%s" % [err, path])
	await get_tree().process_frame   # change_scene 延迟生效：等新场景挂树再揭幕
	await get_tree().process_frame
	if _pending.is_empty():
		await _fade_to(0.0)
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	_flush_pending()   # 转场中重定向过 → 幕布保持黑、直接接力去终点（不闪屏）

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
