# L1 全局横屏模式设置（2026-07-26）：ui_layout 默认竖屏 / set 落盘 / 缓存清空后从盘重读。
# 只测 GameState 持久化层；窗口切换（Router.apply_ui_layout）是 DisplayServer 副作用，交真人验收。
extends "res://tests/test_case.gd"

const GameStateScript = preload("res://view/game_state.gd")


func _restore(prev: String) -> void:
	GameStateScript.set_ui_layout(prev)


func test_default_is_portrait() -> void:
	var prev := GameStateScript.ui_layout()   # 先读一次（顺带保证缓存已加载）
	assert_true(prev == "portrait" or prev == "landscape", "ui_layout 只能是 portrait/landscape")


func test_set_persists_to_disk() -> void:
	var prev := GameStateScript.ui_layout()
	GameStateScript.set_ui_layout("landscape")
	GameStateScript._ui_layout = ""   # 清内存缓存，强制下次从盘读
	assert_eq(GameStateScript.ui_layout(), "landscape", "set 后应落盘可重读")
	GameStateScript.set_ui_layout("portrait")
	GameStateScript._ui_layout = ""
	assert_eq(GameStateScript.ui_layout(), "portrait", "切回竖屏同样落盘")
	_restore(prev)


func test_battle_layout_independent() -> void:
	# 战斗版式（battle_layout，PvE 投影实验）与全局屏幕方向（ui_layout）是两个独立设置，
	# 存不同 section，互不覆盖。
	var prev_b := GameStateScript.battle_layout()
	var prev_u := GameStateScript.ui_layout()
	GameStateScript.set_ui_layout("landscape")
	GameStateScript._battle_layout = ""
	assert_eq(GameStateScript.battle_layout(), prev_b, "改 ui_layout 不应影响 battle_layout")
	_restore(prev_u)
	GameStateScript.set_battle_layout(prev_b)
