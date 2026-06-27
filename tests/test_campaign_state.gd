extends "res://tests/test_case.gd"

# CampaignState（V3-5a）：战役线性进度 + 可重试流转（胜推进 / 败留原地重打 / 全胜通关）。

const CampaignStateScript = preload("res://logic/campaign_state.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const BattleScript = preload("res://logic/battle.gd")

func _levels() -> Array:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return (loader.get_campaign("default").get("levels", []) as Array)

func test_initial_state() -> void:
	var cs = CampaignStateScript.new(_levels())
	assert_eq(cs.size(), 6, "战役 6 关")
	assert_eq(cs.cursor, 0, "初始 cursor 0")
	assert_false(cs.is_over(), "初始未结束")
	assert_eq(cs.current_level_id(), "campaign_01", "首关 = campaign_01")
	assert_eq(cs.current_focus(), "deploy", "首关焦点 = deploy")

func test_win_advances() -> void:
	var cs = CampaignStateScript.new(_levels())
	cs.advance(BattleScript.RESULT_PLAYER_WIN)
	assert_eq(cs.cursor, 1, "胜 → 推进到下一关")
	assert_eq(cs.current_level_id(), "campaign_02", "推进到第二关")
	assert_eq(cs.current_focus(), "elixir", "第二关焦点 = elixir")

func test_loss_and_draw_retry_same_level() -> void:
	var cs = CampaignStateScript.new(_levels())
	cs.advance(BattleScript.RESULT_OPPONENT_WIN)
	assert_eq(cs.cursor, 0, "败 → 留在当前关可重打")
	assert_false(cs.is_over(), "败不结束战役（区别于 roguelite 永久死亡）")
	cs.advance(BattleScript.RESULT_DRAW)
	assert_eq(cs.cursor, 0, "平 → 也留原地")
	cs.advance(BattleScript.RESULT_ONGOING)
	assert_eq(cs.cursor, 0, "未结束喂入 → no-op")

func test_clear_after_all_wins() -> void:
	var cs = CampaignStateScript.new(_levels())
	for i in 6:
		cs.advance(BattleScript.RESULT_PLAYER_WIN)
	assert_true(cs.is_over(), "6 连胜 → 战役结束")
	assert_eq(cs.status, CampaignStateScript.CAMPAIGN_CLEARED, "状态 = 通关")
	assert_eq(cs.current(), {}, "通关后无当前关")
	cs.advance(BattleScript.RESULT_PLAYER_WIN)   # 通关后无副作用
	assert_eq(cs.status, CampaignStateScript.CAMPAIGN_CLEARED, "通关后 advance no-op")

func test_save_load_roundtrip() -> void:
	var cs = CampaignStateScript.new(_levels())
	cs.advance(BattleScript.RESULT_PLAYER_WIN)
	cs.advance(BattleScript.RESULT_PLAYER_WIN)
	var d = cs.to_dict()
	var cs2 = CampaignStateScript.new(_levels())
	cs2.load_dict(d)
	assert_eq(cs2.cursor, 2, "load 恢复 cursor")
	assert_eq(cs2.current_level_id(), "campaign_03", "恢复到正确关")
	assert_false(cs2.is_over(), "进行中状态恢复")
