# V3-4a 测试：RunState —— Roguelite run 推进 / 胜负流转（二元永久死亡）+ headless 跑通一条 run。
# 流转：仅玩家胜推进，走完末节点通关；对手胜/平局 → 永久死亡。
# 末两测为 headless 集成：用真 Match 逐节点建场跑 tick，强制结果喂回 advance，验端到端接线。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const RunMapScript = preload("res://logic/run_map.gd")
const RunStateScript = preload("res://logic/run_state.gd")
const MatchScript = preload("res://logic/match.gd")
const BattleScript = preload("res://logic/battle.gd")

func _loader():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	return loader

func _make_run(loader = null):
	if loader == null:
		loader = _loader()
	var m = RunMapScript.new()
	m.build(loader.get_run("default"))
	var starter: Array = loader.get_run("default").get("starter_deck", [])
	return RunStateScript.new(m, starter)

# ---------- 状态与流转（注入结果，纯逻辑） ----------

func test_initial_state() -> void:
	var run = _make_run()
	assert_eq(run.status, RunStateScript.RUN_ONGOING, "开局进行中")
	assert_false(run.is_over(), "未结束")
	assert_eq(run.cursor, 0, "光标在首节点")
	assert_eq(run.wins, 0, "0 胜")
	assert_eq(run.deck.size(), 8, "run 卡组 = starter 8 张")
	assert_eq(String(run.current_node().get("level_id")), "level_02", "首节点 = level_02")

func test_deck_is_independent_copy() -> void:
	# run 卡组应是传入数组的副本——改 run.deck 不回写配置（draft V3-4b 安全改写）。
	var src := ["knight", "archers", "giant", "goblins"]
	var run = RunStateScript.new(RunMapScript.new(), src)
	run.deck.append("zap")
	assert_eq(src.size(), 4, "原数组不被 run 修改")

func test_win_advances_to_next_node() -> void:
	var run = _make_run()
	run.advance(BattleScript.RESULT_PLAYER_WIN)
	assert_eq(run.cursor, 1, "胜后推进到下一节点")
	assert_eq(run.wins, 1, "1 胜")
	assert_false(run.is_over(), "未通关（还有节点）")
	assert_eq(String(run.current_node().get("level_id")), "level_01", "第二节点 = level_01")

func test_full_run_all_wins_then_won() -> void:
	var run = _make_run()
	for i in 9:
		assert_false(run.is_over(), "第 %d 战前 run 仍进行" % (i + 1))
		run.advance(BattleScript.RESULT_PLAYER_WIN)
	assert_eq(run.status, RunStateScript.RUN_WON, "9 连胜 → 通关")
	assert_eq(run.wins, 9, "9 胜")
	assert_true(run.current_node().is_empty(), "通关后无当前节点")
	# 通关后再喂结果是 no-op（不回退/不越界）。
	run.advance(BattleScript.RESULT_PLAYER_WIN)
	assert_eq(run.status, RunStateScript.RUN_WON, "结束后 advance 无副作用")
	assert_eq(run.wins, 9, "胜场不再增加")

func test_opponent_win_is_permadeath() -> void:
	var run = _make_run()
	run.advance(BattleScript.RESULT_OPPONENT_WIN)
	assert_eq(run.status, RunStateScript.RUN_LOST, "对手胜 → run 失败")
	assert_true(run.is_over(), "run 结束")
	assert_eq(run.cursor, 0, "失败不推进")

func test_draw_is_permadeath() -> void:
	# 平局视为「未取胜」→ 永久死亡（必须明确取胜才过关，V3-4a 决策）。
	var run = _make_run()
	run.advance(BattleScript.RESULT_DRAW)
	assert_eq(run.status, RunStateScript.RUN_LOST, "平局 → run 失败")

func test_ongoing_result_is_noop() -> void:
	# 战斗未结束就喂结果（不应发生）→ 防御性 no-op。
	var run = _make_run()
	run.advance(BattleScript.RESULT_ONGOING)
	assert_eq(run.status, RunStateScript.RUN_ONGOING, "未结束结果不改 run 状态")
	assert_eq(run.cursor, 0, "不推进")

func test_loss_midrun_stops_progress() -> void:
	var run = _make_run()
	run.advance(BattleScript.RESULT_PLAYER_WIN)   # 过第 1 节点
	run.advance(BattleScript.RESULT_PLAYER_WIN)   # 过第 2 节点
	run.advance(BattleScript.RESULT_OPPONENT_WIN) # 第 3 节点败北
	assert_eq(run.status, RunStateScript.RUN_LOST, "中途败北 → 失败")
	assert_eq(run.wins, 2, "保留已取胜场数")

# ---------- headless 跑通一条 run（真 Match 集成） ----------

func test_headless_run_through_all_wins() -> void:
	# 逐节点：用 run 卡组建真 Match（验证 level_id/卡组/arena 接线）、跑几 tick、强制玩家胜、喂回 advance。
	var loader = _loader()
	var run = _make_run(loader)
	var guard := 0
	while not run.is_over() and guard < 30:
		guard += 1
		var node := run.current_node()
		assert_false(node.is_empty(), "进行中应有当前节点")
		var m = MatchScript.new(loader)
		m.setup(String(node.get("level_id")), run.deck)
		assert_eq(m.player.deck.total(), 8, "run 卡组接入玩家（8 张）")
		# 跑几 tick 证明该节点的对局能正常推进（无运行期错误）。
		for i in 3:
			m.update(0.5)
		# 强制玩家胜：打爆对手王塔 → step 触发胜负判定。
		m.battle.opponent_king.take_damage(m.battle.opponent_king.max_hp)
		m.battle.step(0.1)
		assert_eq(m.get_result(), BattleScript.RESULT_PLAYER_WIN, "强制玩家胜")
		run.advance(m.get_result())
	assert_eq(run.status, RunStateScript.RUN_WON, "headless 全胜跑通一条 run → 通关")
	assert_eq(run.wins, 9, "共 9 胜")

func test_headless_run_aborts_on_loss() -> void:
	# 首节点强制玩家败 → run 立即失败、不再连战。
	var loader = _loader()
	var run = _make_run(loader)
	var node := run.current_node()
	var m = MatchScript.new(loader)
	m.setup(String(node.get("level_id")), run.deck)
	m.battle.player_king.take_damage(m.battle.player_king.max_hp)
	m.battle.step(0.1)
	assert_eq(m.get_result(), BattleScript.RESULT_OPPONENT_WIN, "强制玩家败")
	run.advance(m.get_result())
	assert_eq(run.status, RunStateScript.RUN_LOST, "首战败北 → run 失败")
	assert_eq(run.cursor, 0, "失败不推进")
