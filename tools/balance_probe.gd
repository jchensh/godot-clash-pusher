# BalanceProbe —— V5-S8b 平衡测量 harness（headless AI-vs-AI）。
#
# 逻辑层确定性、无随机 → 同 (encounter, coef, ai档, 我方乘区, 卡组) 必同结果。
# 本类跑完整一局 AI 双边对打（两侧都用真游戏 AIController，经 controlled_owner 可选边驱动），
# 读 outcome；扫我方战力乘区找「胜负翻转门槛」，对比 recommended_power 验证操作弥补窗口（PLAN §4）。
# 纯逻辑、可 headless 单测；不碰渲染、不写文件。run_balance_probe.gd（SceneTree 跑批）负责打印报告。
# 用 preload 路径加载、不引用自身 class_name（沿用 V3-4d 踩坑经验）。
extends RefCounted

const MatchScript = preload("res://logic/match.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const SimClockScript = preload("res://logic/sim_clock.gd")
const BattleScript = preload("res://logic/battle.gd")

# 跑一局确定性 AI-vs-AI。params 字段（均可缺省）：
#   base_level(String=ladder_01) / player_deck(Array=空用 base 默认) / enemy_deck(Array=空用 base ai_deck) /
#   coef(float=1.0 敌方出兵乘区) / player_mult(float=1.0 我方出兵乘区) /
#   ai_difficulty(String=normal 敌方档) / player_difficulty(String=normal 我方档) /
#   max_seconds(float=0 用关卡时长封顶)
# 返回 {won:bool, result:int, king_hp_pct:float(我方王塔), duration_sec:float, ticks:int}。
func run_one(config, params: Dictionary) -> Dictionary:
	var base_level := String(params.get("base_level", "ladder_01"))
	var player_deck: Array = params.get("player_deck", [])
	var enemy_deck: Array = params.get("enemy_deck", [])
	var coef := float(params.get("coef", 1.0))
	var player_mult := float(params.get("player_mult", 1.0))
	var ai_diff := String(params.get("ai_difficulty", "normal"))
	var player_diff := String(params.get("player_difficulty", "normal"))
	var max_seconds := float(params.get("max_seconds", 0.0))

	var m = MatchScript.new(config)
	m.setup(base_level, player_deck, [], enemy_deck)
	m.ai_difficulty = ai_diff
	m.set_stat_mults(player_mult, coef)
	var enemy_ai = AIControllerScript.new(m, config, ai_diff, AIControllerScript.OWNER_OPPONENT)
	var player_ai = AIControllerScript.new(m, config, player_diff, AIControllerScript.OWNER_PLAYER)

	var dt: float = SimClockScript.TICK_DELTA
	var limit: float = max_seconds if max_seconds > 0.0 else float(m.battle.match_duration)
	var max_ticks: int = int(ceil(limit / dt)) if limit > 0.0 else 100000
	var ticks := 0
	# 顺序对齐单机 update：双方圣水回涨 → AI 出牌(我方先) → battle.step 结算。
	while not m.is_over() and ticks < max_ticks:
		m.player.regen(dt)
		m.opponent.regen(dt)
		player_ai.tick(dt)
		enemy_ai.tick(dt)
		m.battle.step(dt)
		ticks += 1

	var res: int = int(m.get_result())
	var pk = m.battle.player_king
	var king_pct := 0.0
	if pk != null and float(pk.max_hp) > 0.0:
		king_pct = float(pk.hp) / float(pk.max_hp)
	return {
		"won": res == BattleScript.RESULT_PLAYER_WIN,
		"result": res,
		"king_hp_pct": king_pct,
		"duration_sec": float(ticks) * dt,
		"ticks": ticks,
	}

# 扫我方乘区 [lo,hi] 步 step，找首个让我方胜的乘区（门槛）。base_params 同 run_one（player_mult 被覆盖）。
# 返回 {threshold:float(-1=扫到上限仍不胜), monotone:bool(赢过又输回=false), sweep:[{mult,won,king_hp_pct,duration}]}。
func find_win_threshold(config, base_params: Dictionary, lo: float, hi: float, step: float) -> Dictionary:
	var sweep: Array = []
	var threshold := -1.0
	var monotone := true
	var seen_win := false
	var mult := lo
	while mult <= hi + 1.0e-6:
		var p: Dictionary = base_params.duplicate(true)
		p["player_mult"] = mult
		var out: Dictionary = run_one(config, p)
		sweep.append({"mult": mult, "won": out["won"], "king_hp_pct": out["king_hp_pct"], "duration": out["duration_sec"]})
		if bool(out["won"]):
			if threshold < 0.0:
				threshold = mult
			seen_win = true
		elif seen_win:
			monotone = false   # 已经赢过、又输回去 = 非单调（门槛不可靠）
		mult = snappedf(mult + step, 0.0001)
	return {"threshold": threshold, "monotone": monotone, "sweep": sweep}
