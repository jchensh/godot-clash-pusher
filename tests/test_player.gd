# Step 7a 测试：Player 圣水门槛 + 出牌 + 卡组循环（纯逻辑）。
extends "res://tests/test_case.gd"

const PlayerScript = preload("res://logic/player.gd")
const ElixirScript = preload("res://logic/elixir.gd")
const DeckScript = preload("res://logic/deck.gd")
const BattleScript = preload("res://logic/battle.gd")
const SkillSystemScript = preload("res://logic/skill_system.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

# 返回 [loader, battle, lane, skill]
func _setup():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	var lane = battle.build_v1_single_lane(loader.get_level("level_01"))
	var skill = SkillSystemScript.new(loader, battle)
	return [loader, battle, lane, skill]

func _deck_ids(loader) -> Array:
	return loader.get_level("level_01").get("player_deck")

func _player(loader, skill, start_elixir: float):
	var elixir = ElixirScript.new(10.0, 1.0, start_elixir)
	var deck = DeckScript.new(_deck_ids(loader))
	return PlayerScript.new(UnitScript.OWNER_PLAYER, elixir, deck, loader, skill)

func test_cannot_play_without_enough_elixir() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[3], 0.0)            # 0 圣水
	var ok = p.try_play_card(0, 0, 0.1)             # hand[0]=knight，费 3
	assert_false(ok, "圣水不足不能出牌")
	assert_eq(ctx[2].get_units().size(), 0, "未生成单位")
	assert_almost_eq(p.elixir.get_amount(), 0.0, 0.0001, "圣水未变")

func test_play_spends_elixir_and_spawns() -> void:
	var ctx = _setup()
	var lane = ctx[2]
	var p = _player(ctx[0], ctx[3], 5.0)            # 5 圣水
	var ok = p.try_play_card(0, 0, 0.1)             # knight 费 3
	assert_true(ok, "圣水足够，出牌成功")
	assert_almost_eq(p.elixir.get_amount(), 2.0, 0.0001, "扣 3 圣水")
	assert_eq(lane.get_units().size(), 1, "生成 1 个骑士")
	assert_eq(lane.get_units()[0].owner_id, UnitScript.OWNER_PLAYER, "owner 为玩家")
	assert_almost_eq(lane.get_units()[0].progress, 0.1, 0.0001, "在出牌位置生成")

func test_play_rotates_deck() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[3], 10.0)
	var hand_before = p.deck.get_hand()             # [knight, archers, giant, goblins]
	p.try_play_card(0, 0, 0.1)
	var hand_after = p.deck.get_hand()
	assert_eq(hand_after[0], "minions", "队首补入第 0 格")
	assert_ne(hand_after[0], hand_before[0], "第 0 格已替换")
	assert_eq(p.deck.total(), 8, "牌组总数不变")

func test_can_play_reflects_elixir() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[3], 2.0)            # 2 圣水
	assert_false(p.can_play(0), "knight(3) 不可出")
	assert_true(p.can_play(3), "goblins(2) 可出")

func test_regen_increases_elixir() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[3], 0.0)
	p.regen(1.0)                                    # 1.0 圣水/秒
	assert_almost_eq(p.elixir.get_amount(), 1.0, 0.0001, "圣水按秒回涨")

func test_invalid_hand_index_is_noop() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[3], 10.0)
	assert_false(p.try_play_card(99, 0, 0.1), "越界下标返回 false")
	assert_false(p.try_play_card(-1, 0, 0.1), "负下标返回 false")
	assert_almost_eq(p.elixir.get_amount(), 10.0, 0.0001, "圣水未动")
	assert_eq(ctx[2].get_units().size(), 0, "未生成单位")
