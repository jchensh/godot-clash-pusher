# run_balance_probe.gd —— V5-S8b 平衡 probe 跑批（headless，SceneTree 脚本）。
#
# 用法（git bash 用 Godot 全路径 console exe）：
#   "$GODOT" --headless --path 'F:\godotProject' --script res://tools/run_balance_probe.gd
#
# 对「计划曲线预览」（10 章代表遭遇 × 计划系数 coef(idx)=1+(idx-1)*0.016）扫我方战力门槛，
# 打印报告表，供 S8d 调参（系数斜率 / recommended_power 的 T / 升级% / 成本）。
# 这是测量工具、非游戏逻辑，不参与 CI；铺满 100 关后（S8c）可改为按真 stages 跑全表。
extends SceneTree

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const BalanceProbeScript = preload("res://tools/balance_probe.gd")

# 计划曲线预览行：(章, 该章主原型遭遇, 该章代表全局关序 idx)。系数与 rec 由公式现算。
const PREVIEW := [
	{"chapter": 1,  "encounter": "starter_easy",      "idx": 5},
	{"chapter": 2,  "encounter": "undead_horde",      "idx": 15},
	{"chapter": 3,  "encounter": "orc_blitz",         "idx": 25},
	{"chapter": 4,  "encounter": "tank_push_a",       "idx": 35},
	{"chapter": 5,  "encounter": "spell_siege",       "idx": 45},
	{"chapter": 6,  "encounter": "vampire_balanced",  "idx": 55},
	{"chapter": 7,  "encounter": "air_raid",          "idx": 65},
	{"chapter": 8,  "encounter": "throne_combined",   "idx": 75},
	{"chapter": 9,  "encounter": "abyss_overload",    "idx": 85},
	{"chapter": 10, "encounter": "final_boss",        "idx": 99},
]

# S8b 实测：双 normal AI（都防守）→ 多数局打到超时、胜负由微小塔血差 + 卡组克制主导，
# 故门槛偏粗（对称 1.0× 时本就接近平局）。S8d 调参时宜：①把我方设更激进档(hard)做"高手过线"基准、
# ②看 king_hp_pct/塔血裕度而非纯二元胜负、③细化 step。扫描上限放到 3.0 以覆盖养成满乘区(×3.0)。
const BASE_TEAM_POWER := 920.0   # 初始 8 卡满编 L1R1 战力
const REC_TIGHTNESS := 0.87      # rec 松紧旋钮 T（probe 校准，S8d）
const SWEEP_LO := 0.6
const SWEEP_HI := 3.0            # 覆盖满养成乘区（升级×升阶≈×3.0）
const SWEEP_STEP := 0.3          # 跑批步长（粗，控时长）；细调单关时可缩小
const MAX_SECONDS := 120.0       # 每局封顶（控时长）

func _initialize() -> void:
	var config = ConfigLoaderScript.new()
	if not config.load_all():
		print("[probe] 配置加载失败: ", config.errors)
		quit(1)
		return
	var probe = BalanceProbeScript.new()
	print("=== V5-S8b 平衡 probe：计划曲线预览（我方=ladder 默认 8 卡 / normal AI 双边）===")
	print("跑批参数：扫我方乘区 %.1f→%.1f 步 %.1f，每局封顶 %ds。rec=round(%d×coef×%.2f)。" % [SWEEP_LO, SWEEP_HI, SWEEP_STEP, int(MAX_SECONDS), int(BASE_TEAM_POWER), REC_TIGHTNESS])
	print("章 | 遭遇 | idx | coef | rec | 胜阈(乘区) | 胜阈战力 | 裕度 vs rec | 备注")
	for row in PREVIEW:
		var idx := int(row["idx"])
		var coef := 1.0 + float(idx - 1) * 0.016
		var rec := int(round(BASE_TEAM_POWER * coef * REC_TIGHTNESS))
		var enc: Dictionary = config.get_encounter(String(row["encounter"]))
		var base := {
			"enemy_deck": enc.get("deck", []),
			"coef": coef,
			"ai_difficulty": "normal",
			"player_difficulty": "normal",
			"max_seconds": MAX_SECONDS,
		}
		var r: Dictionary = probe.find_win_threshold(config, base, SWEEP_LO, SWEEP_HI, SWEEP_STEP)
		var thr := float(r["threshold"])
		var thr_s := ("%.2f" % thr) if thr >= 0.0 else (">%.1f" % SWEEP_HI)
		var thr_power_s := "n/a"
		var margin_s := "n/a"
		if thr >= 0.0:
			var thr_power := int(round(BASE_TEAM_POWER * thr))
			thr_power_s = str(thr_power)
			margin_s = "%+d%%" % int(round((float(thr_power) / float(rec) - 1.0) * 100.0))
		var note := "" if bool(r["monotone"]) else "非单调!"
		print("%2d | %-16s | %3d | %.2f | %4d | %9s | %8s | %11s | %s" % [
			int(row["chapter"]), String(row["encounter"]), idx, coef, rec, thr_s, thr_power_s, margin_s, note])
	print("=== 完。门槛随章节应单调上升；裕度负=偏难(需养成)、正=偏易。S8d 据此调旋钮。===")
	quit(0)
