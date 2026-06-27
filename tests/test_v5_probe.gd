# V5-S8b：平衡 probe harness（确定性）+ AIController 可选边（双边、零回归方向）。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const AIControllerScript = preload("res://ai/ai_controller.gd")
const ElixirScript = preload("res://logic/elixir.gd")
const UnitScript = preload("res://logic/unit.gd")
const BalanceProbeScript = preload("res://tools/balance_probe.gd")

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

func _full_elixir(p) -> void:
	p.elixir = ElixirScript.new(10.0, 1.0, 10.0)

func _alive_units(m, owner_id: int) -> Array:
	var out: Array = []
	for u in m.battle.arena.get_units():
		if u.owner_id == owner_id and u.is_alive():
			out.append(u)
	return out

# —— AIController 可选边：我方侧驱动 → 出我方单位、落己方半场(y≥17 部署区) ——
func test_player_side_controller_deploys_player_unit_in_player_half() -> void:
	var c = _config()
	var m = MatchScript.new(c)
	m.setup("ladder_01")
	_full_elixir(m.player)
	var ai = AIControllerScript.new(m, c, "normal", AIControllerScript.OWNER_PLAYER)
	ai.tick(0.1)
	var pus := _alive_units(m, UnitScript.OWNER_PLAYER)
	assert_eq(pus.size(), 1, "玩家侧 AI 出 1 个玩家单位")
	assert_true(float(pus[0].pos.y) >= 17.0, "玩家单位落己方半场(y≥17)，实 y=%.1f" % float(pus[0].pos.y))

# —— 默认对手侧零回归：仍出对手单位、落上半场(y≤15)，与重构前一致 ——
func test_opponent_side_default_unchanged() -> void:
	var c = _config()
	var m = MatchScript.new(c)
	m.setup("ladder_01")
	_full_elixir(m.opponent)
	var ai = AIControllerScript.new(m, c, "normal")   # 默认 OWNER_OPPONENT
	ai.tick(0.1)
	var ous := _alive_units(m, UnitScript.OWNER_OPPONENT)
	assert_eq(ous.size(), 1, "对手侧 AI 出 1 个对手单位")
	assert_true(float(ous[0].pos.y) <= 15.0, "对手单位落上半场(y≤15)，实 y=%.1f" % float(ous[0].pos.y))

# —— probe 确定性：同参数两跑逐字段一致（无随机）——
func test_probe_run_one_deterministic() -> void:
	var c = _config()
	var probe = BalanceProbeScript.new()
	var params := {
		"enemy_deck": c.get_encounter("tank_push_a").get("deck", []),
		"coef": 1.4, "player_mult": 1.0,
		"ai_difficulty": "normal", "player_difficulty": "normal",
		"max_seconds": 60.0,
	}
	var a: Dictionary = probe.run_one(c, params)
	var b: Dictionary = probe.run_one(c, params)
	assert_eq(int(a["result"]), int(b["result"]), "result 一致")
	assert_eq(int(a["ticks"]), int(b["ticks"]), "ticks 一致")
	assert_almost_eq(float(a["king_hp_pct"]), float(b["king_hp_pct"]), 0.0001, "king_hp_pct 一致")

# —— probe 量得到胜负：压倒性优势我方胜、巨大劣势我方不胜（证明门槛有意义）——
func test_probe_measures_dominance() -> void:
	var c = _config()
	var probe = BalanceProbeScript.new()
	var deck: Array = c.get_encounter("starter_easy").get("deck", [])
	var strong: Dictionary = probe.run_one(c, {
		"enemy_deck": deck, "coef": 1.0, "player_mult": 4.0,
		"ai_difficulty": "normal", "player_difficulty": "normal", "max_seconds": 120.0,
	})
	assert_true(bool(strong["won"]), "我方 4× 乘区 vs coef1.0 → 胜（result=%d）" % int(strong["result"]))
	var weak: Dictionary = probe.run_one(c, {
		"enemy_deck": deck, "coef": 3.0, "player_mult": 0.25,
		"ai_difficulty": "normal", "player_difficulty": "normal", "max_seconds": 120.0,
	})
	assert_false(bool(weak["won"]), "我方 0.25× 乘区 vs coef3.0 → 不胜（result=%d）" % int(weak["result"]))

# —— find_win_threshold：扫描表点数正确、门槛落在 [lo,hi] 或 -1 ——
func test_find_win_threshold_shape() -> void:
	var c = _config()
	var probe = BalanceProbeScript.new()
	var base := {
		"enemy_deck": c.get_encounter("starter_easy").get("deck", []),
		"coef": 1.2, "ai_difficulty": "normal", "player_difficulty": "normal", "max_seconds": 90.0,
	}
	var r: Dictionary = probe.find_win_threshold(c, base, 0.8, 1.4, 0.2)
	assert_eq((r["sweep"] as Array).size(), 4, "扫 0.8/1.0/1.2/1.4 共 4 点")
	var thr := float(r["threshold"])
	assert_true(thr < 0.0 or (thr >= 0.8 - 1.0e-6 and thr <= 1.4 + 1.0e-6), "门槛在区间或 -1（实 %.2f）" % thr)
