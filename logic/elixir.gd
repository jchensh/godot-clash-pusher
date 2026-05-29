# Elixir —— 一方的圣水系统（玩家与 AI 共用）。
#
# 规则：
#   - 随时间按 regen_rate（每秒回涨量）线性回涨，封顶到 maximum。
#   - 出牌时 spend 扣除，不足则拒绝。
#   - 内部用 float 保存，回涨平滑；display 取 float 画条、取 int 判断可出牌。
# 时间推进由固定逻辑 tick 驱动（见 SimClock）：每 tick 调一次 tick(SimClock.TICK_DELTA)。
# regen_rate 是「每秒」量，所以 tick 频率改变不影响数值含义。
extends RefCounted
class_name Elixir

var current: float = 0.0
var maximum: float = 10.0
var regen_rate: float = 1.0     # 圣水/秒

func _init(maximum_: float = 10.0, regen_rate_: float = 1.0, start_: float = 0.0) -> void:
	maximum = maxf(maximum_, 0.0)
	regen_rate = maxf(regen_rate_, 0.0)
	current = clampf(start_, 0.0, maximum)

# 推进 dt 秒（通常 dt = SimClock.TICK_DELTA），回涨并封顶。
func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	current = minf(current + regen_rate * dt, maximum)

func can_spend(amount: float) -> bool:
	return current >= amount

# 扣除；不足返回 false 且不改变状态。
func spend(amount: float) -> bool:
	if amount < 0.0 or not can_spend(amount):
		return false
	current = maxf(current - amount, 0.0)
	return true

# 当前圣水（float，用于显示平滑）。
func get_amount() -> float:
	return current

# 当前可用整数圣水（用于「够不够出这张牌」的判断/显示）。
func get_int() -> int:
	return floori(current)

func is_full() -> bool:
	return current >= maximum
