# V3-1b 测试：Player 圣水门槛 + 出牌 + 卡组循环 + 2D 部署校验（纯逻辑）。
extends "res://tests/test_case.gd"

const PlayerScript = preload("res://logic/player.gd")
const ElixirScript = preload("res://logic/elixir.gd")
const DeckScript = preload("res://logic/deck.gd")
const BattleScript = preload("res://logic/battle.gd")
const SkillSystemScript = preload("res://logic/skill_system.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const UnitScript = preload("res://logic/unit.gd")

# 己方半场地面落点 / 敌方半场点（arena.json default：玩家 y>=17，对手 y<=15）
const PLAYER_SPOT := Vector2(9, 20)
const ENEMY_SPOT := Vector2(9, 8)

# 返回 [loader, battle, skill]
func _setup():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var battle = BattleScript.new()
	battle.build_arena(loader.get_level("level_01"), loader.get_arena("default"))
	var skill = SkillSystemScript.new(loader, battle)
	return [loader, battle, skill]

func _deck_ids(loader) -> Array:
	return loader.get_level("level_01").get("player_deck")

func _player(loader, skill, start_elixir: float, owner: int = UnitScript.OWNER_PLAYER):
	var elixir = ElixirScript.new(10.0, 1.0, start_elixir)
	var deck = DeckScript.new(_deck_ids(loader))
	return PlayerScript.new(owner, elixir, deck, loader, skill)

func _units(ctx) -> Array:
	return ctx[1].arena.get_units()

func test_cannot_play_without_enough_elixir() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 0.0)            # 0 圣水
	var ok = p.try_play_card(0, PLAYER_SPOT)        # hand[0]=knight，费 3
	assert_false(ok, "圣水不足不能出牌")
	assert_eq(_units(ctx).size(), 0, "未生成单位")
	assert_almost_eq(p.elixir.get_amount(), 0.0, 0.0001, "圣水未变")

func test_play_spends_elixir_and_spawns() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 5.0)            # 5 圣水
	var ok = p.try_play_card(0, PLAYER_SPOT)        # knight 费 3
	assert_true(ok, "圣水足够，出牌成功")
	assert_almost_eq(p.elixir.get_amount(), 2.0, 0.0001, "扣 3 圣水")
	assert_eq(_units(ctx).size(), 1, "生成 1 个骑士")
	assert_eq(_units(ctx)[0].owner_id, UnitScript.OWNER_PLAYER, "owner 为玩家")
	assert_almost_eq(_units(ctx)[0].pos.y, PLAYER_SPOT.y, 0.0001, "在出牌点生成")

func test_play_rotates_deck() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 10.0)
	var hand_before = p.deck.get_hand()             # [knight, archers, giant, goblins]
	p.try_play_card(0, PLAYER_SPOT)
	var hand_after = p.deck.get_hand()
	assert_eq(hand_after[0], "minions", "队首补入第 0 格")
	assert_ne(hand_after[0], hand_before[0], "第 0 格已替换")
	assert_eq(p.deck.total(), 8, "牌组总数不变")

func test_can_play_reflects_elixir() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 2.0)            # 2 圣水
	assert_false(p.can_play(0), "knight(3) 不可出")
	assert_true(p.can_play(3), "goblins(2) 可出")

func test_regen_increases_elixir() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 0.0)
	p.regen(1.0)                                    # 1.0 圣水/秒
	assert_almost_eq(p.elixir.get_amount(), 1.0, 0.0001, "圣水按秒回涨")

func test_invalid_hand_index_is_noop() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 10.0)
	assert_false(p.try_play_card(99, PLAYER_SPOT), "越界下标返回 false")
	assert_false(p.try_play_card(-1, PLAYER_SPOT), "负下标返回 false")
	assert_almost_eq(p.elixir.get_amount(), 10.0, 0.0001, "圣水未动")
	assert_eq(_units(ctx).size(), 0, "未生成单位")

# ---- 2D 部署校验（决策 26 / 36：固定己方半场 + 地面）----

func test_troop_deploy_rejected_outside_own_half() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 10.0)            # hand[0]=knight（兵）
	var ok = p.try_play_card(0, ENEMY_SPOT)          # 敌方半场
	assert_false(ok, "兵牌落点越界己方半场 → 拒绝")
	assert_almost_eq(p.elixir.get_amount(), 10.0, 0.0001, "拒绝后未扣圣水")
	assert_eq(_units(ctx).size(), 0, "拒绝后未生成单位")
	assert_eq(p.deck.get_hand()[0], "knight", "拒绝后手牌未循环")

func test_troop_deploy_allowed_at_half_boundary() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 10.0)
	var ok = p.try_play_card(0, Vector2(9, 17))      # 边界 y=17 属己方半场（player_y_min）
	assert_true(ok, "落点正好在半场边界 → 允许")
	assert_eq(_units(ctx).size(), 1, "生成单位")

func test_troop_deploy_rejected_on_water() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 10.0)
	# 河区(y=15,16)是水且不在玩家半场——双重非法；这里验证地面校验生效。
	var ok = p.try_play_card(0, Vector2(9, 15))
	assert_false(ok, "落水点 → 拒绝")

func test_spell_allowed_in_enemy_half() -> void:
	var ctx = _setup()
	var loader = ctx[0]
	var deck = DeckScript.new(["fireball", "knight", "giant", "goblins", "minions", "archers", "arrows", "zap"])
	var p = PlayerScript.new(UnitScript.OWNER_PLAYER, ElixirScript.new(10.0, 1.0, 10.0), deck, loader, ctx[2])
	var ok = p.try_play_card(0, ENEMY_SPOT)          # hand[0]=fireball（纯法术），打敌方半场
	assert_true(ok, "纯法术不受半场限制，可打敌方半场")
	assert_almost_eq(p.elixir.get_amount(), 6.0, 0.0001, "扣 4 圣水(fireball)")

func test_opponent_troop_deploy_rejected_in_player_half() -> void:
	var ctx = _setup()
	var p = _player(ctx[0], ctx[2], 10.0, UnitScript.OWNER_OPPONENT)
	var ok = p.try_play_card(0, PLAYER_SPOT)         # 对手半场 y<=15；y=20 进了玩家半场
	assert_false(ok, "对手兵牌落点进玩家半场 → 拒绝")
	assert_almost_eq(p.elixir.get_amount(), 10.0, 0.0001, "拒绝后未扣圣水")
