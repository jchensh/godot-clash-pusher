# 决策 49（2026-08-30）横屏线封存语义锁定：全局恒竖屏、战斗恒横板投影。
# ui_layout()/battle_layout() 不再读 settings.cfg，set_* 保留但不影响读取——
# 本测试钉死封存口径，防止未来误恢复持久化读取（恢复须走用户决策）。
extends "res://tests/test_case.gd"

const GameStateScript = preload("res://view/game_state.gd")


func test_ui_layout_sealed_portrait() -> void:
	assert_eq(GameStateScript.ui_layout(), "portrait", "决策 49：全局恒竖屏")
	GameStateScript.set_ui_layout("landscape")   # 旧入口已下线；即便被调用也不改变读取
	GameStateScript._ui_layout = ""
	assert_eq(GameStateScript.ui_layout(), "portrait", "set 后读取仍恒竖屏（封存）")
	GameStateScript.set_ui_layout("portrait")    # 还原盘上值，不留脏配置


func test_battle_layout_sealed_landscape() -> void:
	assert_eq(GameStateScript.battle_layout(), "landscape", "决策 49：战斗恒竖屏横板投影")
	GameStateScript.set_battle_layout("portrait")
	GameStateScript._battle_layout = ""
	assert_eq(GameStateScript.battle_layout(), "landscape", "set 后读取仍恒横板（封存）")
	GameStateScript.set_battle_layout("landscape")
