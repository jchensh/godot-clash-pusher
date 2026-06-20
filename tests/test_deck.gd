# Step 3 测试：Deck 循环卡组（8 库 + 4 手、出一张补一张）。
extends "res://tests/test_case.gd"

const DeckScript = preload("res://logic/deck.gd")
const ConfigLoaderScript = preload("res://logic/config_loader.gd")

const DECK := ["c0", "c1", "c2", "c3", "c4", "c5", "c6", "c7"]

func test_setup_splits_hand_and_queue() -> void:
	var d = DeckScript.new(DECK)
	assert_eq(d.get_hand(), ["c0", "c1", "c2", "c3"], "前 4 张为手牌")
	assert_eq(d.peek_next(), "c4", "队首为第 5 张")
	assert_eq(d.total(), 8, "牌组总数 8")

func test_play_returns_played_card() -> void:
	var d = DeckScript.new(DECK)
	assert_eq(d.play(0), "c0", "打出第 0 格返回 c0")

func test_play_refills_slot_with_next() -> void:
	var d = DeckScript.new(DECK)
	d.play(0)
	assert_eq(d.get_hand(), ["c4", "c1", "c2", "c3"], "第 0 格被队首 c4 补上，其余格不变")
	assert_eq(d.peek_next(), "c5", "队首推进到 c5")

func test_two_plays_exact_state() -> void:
	var d = DeckScript.new(DECK)
	d.play(0)  # hand [c4,c1,c2,c3] queue [c5,c6,c7,c0]
	d.play(0)  # hand [c5,c1,c2,c3] queue [c6,c7,c0,c4]
	assert_eq(d.get_hand(), ["c5", "c1", "c2", "c3"], "两次出第0格后手牌")
	assert_eq(d.peek_next(), "c6", "队首=c6")
	assert_eq(d._queue, ["c6", "c7", "c0", "c4"], "打出的牌依次回到队尾")

func test_play_middle_slot() -> void:
	var d = DeckScript.new(DECK)
	var played = d.play(2)  # 打出 c2
	assert_eq(played, "c2", "返回 c2")
	assert_eq(d.get_hand(), ["c0", "c1", "c4", "c3"], "仅第 2 格被补为 c4")

func test_no_card_lost_or_duplicated() -> void:
	# 不变量：任意多次出牌后，手牌 + 队列恰好等于原始 8 张集合（无丢失、无重复）。
	var d = DeckScript.new(DECK)
	var original := DECK.duplicate()
	original.sort()
	for n in 17:
		d.play(n % DeckScript.HAND_SIZE)
		var all := d.get_hand()
		all.append_array(d._queue)
		all.sort()
		assert_eq(all, original, "第 %d 次出牌后牌组集合应不变" % n)

func test_invalid_index_no_mutation() -> void:
	var d = DeckScript.new(DECK)
	assert_null(d.play(-1), "负下标返回 null")
	assert_null(d.play(4), "越界下标返回 null")
	assert_eq(d.get_hand(), ["c0", "c1", "c2", "c3"], "非法出牌不改变手牌")
	assert_eq(d.peek_next(), "c4", "非法出牌不改变队列")

func test_get_hand_returns_copy() -> void:
	var d = DeckScript.new(DECK)
	var h = d.get_hand()
	h[0] = "HACKED"
	assert_eq(d.get_hand()[0], "c0", "get_hand 返回副本，外部修改不影响内部")

func test_variable_size_deck_for_draft() -> void:
	# V3-4b：draft 后 run 卡组可增长到 >8。Deck 应支持任意 ≥5 张：手牌仍 4、其余进队列、正常循环。
	var big := ["c0", "c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9"]
	var d = DeckScript.new(big)
	assert_eq(d.total(), 10, "10 张牌组总数 10")
	assert_eq(d.get_hand(), ["c0", "c1", "c2", "c3"], "手牌仍取前 4")
	assert_eq(d.peek_next(), "c4", "队首=第 5 张")
	# 循环不变量：多次出牌后集合不变（无丢失/重复）。
	var original := big.duplicate()
	original.sort()
	for n in 23:
		d.play(n % DeckScript.HAND_SIZE)
		var all := d.get_hand()
		all.append_array(d._queue)
		all.sort()
		assert_eq(all, original, "增长卡组第 %d 次出牌后集合不变" % n)

func test_with_real_config_deck() -> void:
	# 与 ConfigLoader 集成：用 level_01 的真实 8 张牌组驱动 Deck。
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var deck_ids = loader.get_level("level_01").get("player_deck")
	var d = DeckScript.new(deck_ids)
	assert_eq(d.total(), 8, "真实牌组总数 8")
	assert_eq(d.get_hand().size(), 4, "手牌 4 张")
	var played = d.play(0)
	assert_true(loader.has_card(played), "打出的应是有效 card id: %s" % str(played))
