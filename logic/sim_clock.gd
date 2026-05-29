# SimClock —— 固定时间步长累加器（PLAN §8 核心机制）。
#
# 把显示层的可变帧 dt 转换成离散、定长的逻辑 tick，使**游戏速度与渲染帧率解耦**：
# 无论一帧多长、帧率多少，相同的真实经过时间会产生相同数量的逻辑 tick。
# 逻辑层每个 tick 固定推进 TICK_DELTA 秒，显示层负责在两 tick 之间做插值。
#
# 用法（将在 Battle/Step 5 接入）：
#   var n := clock.advance(delta)        # delta 来自 _process(delta)
#   for i in n: world.step(SimClock.TICK_DELTA)
extends RefCounted
class_name SimClock

const TICK_DELTA := 0.1           # 每个逻辑 tick 的时长（秒）。10 Hz。
const TICKS_PER_SECOND := 10
const MAX_TICKS_PER_ADVANCE := 100  # 单次 advance 的 tick 上限，防止卡顿后的追帧风暴
const _EPSILON := 1e-9            # 容差：吸收浮点累加漂移，避免极接近 TICK_DELTA 时漏掉 tick

var tick_count: int = 0           # 自创建以来推进过的总 tick 数
var _accumulator: float = 0.0

# 喂入真实经过时间（秒），返回本次应执行的逻辑 tick 数。
func advance(real_dt: float) -> int:
	if real_dt <= 0.0:
		return 0
	_accumulator += real_dt
	var n := 0
	while _accumulator >= TICK_DELTA - _EPSILON:
		_accumulator -= TICK_DELTA
		n += 1
		if n >= MAX_TICKS_PER_ADVANCE:
			_accumulator = 0.0    # 丢弃积压，避免一次推进过多 tick
			break
	tick_count += n
	return n

# 当前未满一个 tick 的余量（秒），显示层插值可用：0.0~TICK_DELTA。
func get_interpolation_fraction() -> float:
	return _accumulator / TICK_DELTA
