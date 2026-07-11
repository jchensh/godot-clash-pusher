# E1：生产在线入口的静态契约与 fail-closed 状态测试（网络集成另走 Docker）。
extends "res://tests/test_case.gd"

const OnlineRuntimeScript := preload("res://net/online_runtime.gd")
const EconomyStateCacheScript := preload("res://net/economy_state_cache.gd")


func test_runtime_starts_not_ready() -> void:
	var runtime = OnlineRuntimeScript.new()
	assert_eq(runtime.state, OnlineRuntimeScript.State.BOOTSTRAP, "启动先经过在线 gate")
	assert_false(runtime.is_online_ready(), "未认证/配置/经济时不可 ready")
	assert_true(runtime.config().cards.is_empty(), "不会在构造期偷读本地权威配置")


func test_api_transport_failure_degrades_ready_runtime() -> void:
	var runtime = OnlineRuntimeScript.new()
	runtime._started = true
	runtime.state = OnlineRuntimeScript.State.ONLINE_READY
	runtime._on_api_transport_failure("api unavailable")
	assert_eq(runtime.state, OnlineRuntimeScript.State.DEGRADED, "Gateway 在线但 API 断开也必须降级")
	assert_false(runtime.is_online_ready(), "复合在线状态 fail-closed")


func test_economy_write_guard_fails_closed() -> void:
	var economy = EconomyStateCacheScript.new()
	economy.online_guard = func(): return false
	assert_false(economy._can_write(), "掉线时写 gate 关闭")
	var result := economy._offline_error()
	assert_false(bool(result.get("ok", true)), "拒绝结果明确失败")
	assert_eq(String(result.get("error", "")), "online session not ready", "拒绝原因稳定")


func test_project_registers_single_online_autoload() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_eq(project.count('Online="*res://net/online_runtime.gd"'), 1, "唯一 Online autoload")


func test_production_scenes_do_not_load_local_config_directly() -> void:
	var paths := [
		"res://view/main_menu.gd",
		"res://view/battle_scene.gd",
		"res://view/net_battle_scene.gd",
		"res://view/deck_builder.gd",
		"res://view/level_select.gd",
		"res://view/campaign_scene.gd",
		"res://view/run_scene.gd",
	]
	for path in paths:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains(".load_all()"), "%s 不得旁路服务器配置" % path)
	var menu := FileAccess.get_file_as_string("res://view/main_menu.gd")
	assert_false(menu.contains("_build_menu(false)"), "登录失败不得构建离线业务菜单")
	var pve := FileAccess.get_file_as_string("res://view/battle_scene.gd")
	assert_true(pve.contains("func _draw_online_pause()"), "PVE 掉线必须给出可见恢复状态")
	assert_true(pve.contains("在线会话中断"), "PVE 恢复提示文案不可静默丢失")
	assert_true(pve.contains("if _stage_returning:"), "战后提交必须 single-flight")
	assert_true(pve.contains("提交战报中"), "战后等待必须有可见状态")
	var stage_map := FileAccess.get_file_as_string("res://view/stage_map.gd")
	var report_pos := stage_map.find("await _report_and_delta")
	var clear_pos := stage_map.find("GameStateScript.stage_last_result = {}")
	assert_true(report_pos >= 0 and clear_pos > report_pos, "pending 只能在服务器确认后清除")
	assert_true(stage_map.contains("结算服务不可用 · 点击重试"), "结算失败必须提供原地重试")
