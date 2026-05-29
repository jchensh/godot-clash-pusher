# Deck —— 循环卡组（皇室战争式）。玩家与 AI 共用。
#
# 一副 8 张牌：4 张在手（可出，格位固定），其余 4 张在队列等待。
# 出牌规则：打出手牌某一格 → 该格由队首（下一张）补上 → 打出的牌回到队尾。
# 纯逻辑：只搬运 card id，不关心圣水/数值（那些在 Player / ConfigLoader）。
#
# V1 不洗牌（确定性循环，利于测试）；如需开局随机化，后续再加可选 seeded shuffle。
extends RefCounted
class_name Deck

const HAND_SIZE := 4
const DECK_SIZE := 8

var _hand: Array = []      # 固定 HAND_SIZE 格，存 card id
var _queue: Array = []     # 等待队列；front=下一张要补的，back=刚打出的回到这

func _init(card_ids: Array = []) -> void:
	if not card_ids.is_empty():
		setup(card_ids)

# 用一副牌（card id 列表，应恰好 DECK_SIZE 张）初始化：前 HAND_SIZE 张进手牌，其余进队列。
func setup(card_ids: Array) -> void:
	if card_ids.size() != DECK_SIZE:
		push_error("Deck 需要恰好 %d 张牌，收到 %d 张" % [DECK_SIZE, card_ids.size()])
	_hand = card_ids.slice(0, HAND_SIZE)
	_queue = card_ids.slice(HAND_SIZE)

# 当前手牌（返回副本，外部修改影响不到内部）。
func get_hand() -> Array:
	return _hand.duplicate()

# 下一张将补入手牌的牌（队首）；队列空则返回 null。
func peek_next() -> Variant:
	return _queue[0] if not _queue.is_empty() else null

# 打出第 hand_index 格手牌：队首补入该格、打出的牌回到队尾，返回打出的 card id。
# 非法下标或队列为空时返回 null 且不改变任何状态。
func play(hand_index: int) -> Variant:
	if hand_index < 0 or hand_index >= _hand.size():
		return null
	if _queue.is_empty():
		return null
	var played = _hand[hand_index]
	_hand[hand_index] = _queue.pop_front()
	_queue.push_back(played)
	return played

# 牌组总数（应恒为 DECK_SIZE）。
func total() -> int:
	return _hand.size() + _queue.size()
