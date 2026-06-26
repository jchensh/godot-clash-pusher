# V5-S4：卡牌升级（金币 sink + 数值曲线 + 等级上限受阶限制）+ 养成接进战斗（我方乘区按 level/rank）。
extends "res://tests/test_case.gd"

const PlayerDataScript = preload("res://logic/player_data.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const UnitScript = preload("res://logic/unit.gd")

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

func _pd(config):
	var ids: Array = []
	for cid in config.cards:
		ids.append(cid)
	var p = PlayerDataScript.new()
	p.init_new(ids)
	return p

func test_upgrade_spends_gold_and_levels() -> void:
	var config = _config()
	var p = _pd(config)
	p.gold = 1000
	assert_eq(p.upgrade_cost("knight", config), 80, "L1 升级成本 80（common base）")
	assert_true(p.upgrade_card("knight", config), "升级成功")
	assert_eq(int(p.card_state("knight").get("level")), 2, "等级 → 2")
	assert_eq(p.gold, 920, "扣 80 金币")

func test_upgrade_cost_rises_with_level() -> void:
	var config = _config()
	var p = _pd(config)
	var c1 = p.upgrade_cost("knight", config)
	p.cards["knight"]["level"] = 3
	assert_true(p.upgrade_cost("knight", config) > c1, "等级越高升级越贵")

func test_upgrade_blocked_at_rank_level_cap() -> void:
	var config = _config()
	var p = _pd(config)
	p.gold = 100000
	# rank 1 等级上限 = 4。到 4 后应拒绝（需先升阶）。
	p.cards["knight"]["level"] = 4
	p.cards["knight"]["rank"] = 1
	assert_false(p.upgrade_card("knight", config), "rank1 满级(4) 不能再升")
	assert_eq(int(p.card_state("knight").get("level")), 4, "等级不变")

func test_upgrade_rejects_insufficient_gold() -> void:
	var config = _config()
	var p = _pd(config)
	p.gold = 10   # < 80
	assert_false(p.upgrade_card("knight", config), "金币不足拒绝")
	assert_eq(int(p.card_state("knight").get("level")), 1, "等级不变")
	assert_eq(p.gold, 10, "金币不变")

func test_upgrade_rejects_locked_card() -> void:
	var config = _config()
	var p = _pd(config)
	p.gold = 100000
	assert_false(p.is_unlocked("golem"), "golem 默认锁定")
	assert_false(p.upgrade_card("golem", config), "锁定卡不能升级")

# —— 养成接进战斗：升级我方卡 → 出兵真变强 ——
func test_player_data_scales_own_units_in_battle() -> void:
	var config = _config()
	var p = _pd(config)
	p.cards["knight"]["rank"] = 2     # rank2 上限 7，允许到 level 6
	p.cards["knight"]["level"] = 6    # mult = (1+5*0.1)*1.25 = 1.5*1.25 = 1.875
	var m = MatchScript.new(config)
	m.setup_stage("stage_1_1", [], p)  # 传入 player_data
	m.player.elixir.tick(50.0)
	var idx: int = m.player.deck.get_hand().find("knight")
	assert_true(idx >= 0, "knight 在手")
	assert_true(m.player.try_play_card(idx, Vector2(9, 20)), "出牌成功")
	var u = null
	for unit in m.battle.arena.units:
		if unit.owner_id == UnitScript.OWNER_PLAYER:
			u = unit
	assert_not_null(u, "我方生成单位")
	assert_almost_eq(u.max_hp, 1125.0, 1.0, "升级后 knight 600*1.875=1125 变肉")
