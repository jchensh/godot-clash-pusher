# run_stage_balance.gd —— V5-S8d 真关卡平衡 probe 跑批（headless，SceneTree）。
#
# 用法："$GODOT" --headless --path 'F:\godotProject' --script res://tools/run_stage_balance.gd
#
# 对真 stages.json 的每关（采样每章 首/中/boss 控时长）跑 AI-vs-AI：我方=hard(技术型推塔基准) +
# 养成乘区 = recommended_power/920；敌方 = 关卡 coef(单位) + coef(敌塔 HP) + ai_difficulty。
# 量 @rec / @-15% / @-30% 三档我方乘区的胜负 + 我方王塔剩血%，验证操作弥补窗口（PLAN §4）。
# ★ AI-vs-AI 仅粗信号（S8b 已证 timeout 主导、AI 质量敏感）：用来抓 cliff/不可过/太易等粗问题，
#   手感终判 = S8e 真人。改 SAMPLE_INDICES=[1..10] 可跑全 100（更慢）。
extends SceneTree

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const BalanceProbeScript = preload("res://tools/balance_probe.gd")
const StageProgressScript = preload("res://logic/stage_progress.gd")

const BASE_TEAM_POWER := 920.0
const PLAYER_DIFF := "hard"            # 技术型玩家基准（最激进推塔）
const MAX_SECONDS := 120.0
const SAMPLE_INDICES := [1, 5, 10]     # 每章取 首/中/boss；改 range(1,11) 跑全章

func _probe(probe, config, st: Dictionary, player_mult: float) -> Dictionary:
	var coef := float(st["difficulty_coef"])
	return probe.run_one(config, {
		"enemy_deck": (config.get_encounter(String(st["encounter"])).get("deck", []) as Array),
		"base_level": String(st.get("base_level", "ladder_01")),
		"coef": coef,
		"enemy_tower_mult": coef,
		"player_mult": player_mult,
		"ai_difficulty": String(st["ai_difficulty"]),
		"player_difficulty": PLAYER_DIFF,
		"max_seconds": MAX_SECONDS,
	})

func _initialize() -> void:
	var config = ConfigLoaderScript.new()
	if not config.load_all():
		print("[probe] 配置加载失败: ", config.errors)
		quit(1)
		return
	var probe = BalanceProbeScript.new()
	var sp = StageProgressScript.new(config.stages)
	print("=== V5-S8d 真关卡平衡 probe（我方=%s 技术基准 / 敌塔随 coef / 每章 首·中·boss 采样）===" % PLAYER_DIFF)
	print("target 乘区 = recommended_power / %d；±档检验操作弥补窗口。king%% = 我方王塔剩血。" % int(BASE_TEAM_POWER))
	print("关          | coef | rec  | ai      | @rec | king% | @-15% | @-30% | 判定")
	for sid in sp.ordered_ids():
		var st: Dictionary = config.stages[sid]
		if not SAMPLE_INDICES.has(int(st["index"])):
			continue
		var rec := int(st["recommended_power"])
		var target := float(rec) / BASE_TEAM_POWER
		var at_rec := _probe(probe, config, st, target)
		var at_85 := _probe(probe, config, st, target * 0.85)
		var at_70 := _probe(probe, config, st, target * 0.70)
		var verdict := "合理"
		if not bool(at_rec["won"]):
			verdict = "偏难(rec过不了)"
		elif bool(at_70["won"]):
			verdict = "偏易(-30%还能过)"
		print("%-11s | %.2f | %4d | %-7s |  %s  |  %3d%% |   %s   |   %s   | %s" % [
			sid, float(st["difficulty_coef"]), rec, String(st["ai_difficulty"]),
			("胜" if bool(at_rec["won"]) else "负"),
			int(round(float(at_rec["king_hp_pct"]) * 100.0)),
			("胜" if bool(at_85["won"]) else "负"),
			("胜" if bool(at_70["won"]) else "负"),
			verdict])
	print("=== 完。理想：@rec 胜且 king%% 不接近 100（有来有回）、@-30%% 多数负（养成才过）。AI-vs-AI 仅粗信号、手感终判 S8e。===")
	quit(0)
