# Battle —— 战斗总控：对局计时、双方塔状态、胜负判定（PLAN §4，Step 5）。
#
# 三塔制：每方 1 王塔 + 2 公主塔。
# 胜负（Step 5 决策）：
#   - 王塔归零 → 该方立即负（公主塔归零不结束对局，只计入剩余塔血）。
#   - 时间到（match_duration）→ 比双方剩余塔血总和，多者胜，相等判平。
# 逻辑用固定 tick 驱动：step(dt) 由显示层（Step 7）经 SimClock.advance 循环调用；
# 单元测试直接喂 dt。Battle 不关心像素/渲染。
#
# 跨脚本一律用 preload（按路径加载），不依赖 class_name 全局注册，避免新脚本
# 未生成 .uid 时的解析问题（见 HISTORY Step 4 踩坑）。
extends RefCounted
class_name Battle

const TowerScript = preload("res://logic/tower.gd")
const LaneScript = preload("res://logic/lane.gd")
const UnitScript = preload("res://logic/unit.gd")

const RESULT_ONGOING := 0
const RESULT_PLAYER_WIN := 1
const RESULT_OPPONENT_WIN := 2
const RESULT_DRAW := 3

const _EPSILON := 1e-9

var match_duration: float = 0.0   # 对局时长（秒），来自 level 配置；<=0 表示不计时
var elapsed: float = 0.0          # 已推进的逻辑时间（秒）
var result: int = RESULT_ONGOING

var player_towers: Array = []     # Tower
var opponent_towers: Array = []   # Tower
var player_king = null            # 玩家王塔（胜负关键）
var opponent_king = null          # 对手王塔
var lanes: Array = []             # Lane

func _init(match_duration_: float = 0.0) -> void:
	match_duration = maxf(match_duration_, 0.0)

func add_player_tower(tower) -> void:
	player_towers.append(tower)
	if tower.is_king():
		player_king = tower

func add_opponent_tower(tower) -> void:
	opponent_towers.append(tower)
	if tower.is_king():
		opponent_king = tower

func add_lane(lane) -> void:
	lanes.append(lane)

func get_lane(lane_index: int):
	for lane in lanes:
		if lane.lane_index == lane_index:
			return lane
	return null

# 便捷搭建：按 level 配置建一个 V1 单 lane 对局
# （双方各 1 王 + 2 公主；单 lane 两端接双方王塔）。返回该 lane 供调用方部署单位。
func build_v1_single_lane(level: Dictionary):
	match_duration = float(level.get("match_duration", 0.0))
	var tower_hp: Dictionary = level.get("tower_hp", {})
	var king_hp := float(tower_hp.get("king", 0.0))
	var princess_hp := float(tower_hp.get("princess", 0.0))

	var p_king = TowerScript.new(TowerScript.KIND_KING, UnitScript.OWNER_PLAYER, king_hp)
	add_player_tower(p_king)
	add_player_tower(TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_PLAYER, princess_hp))
	add_player_tower(TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_PLAYER, princess_hp))

	var o_king = TowerScript.new(TowerScript.KIND_KING, UnitScript.OWNER_OPPONENT, king_hp)
	add_opponent_tower(o_king)
	add_opponent_tower(TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_OPPONENT, princess_hp))
	add_opponent_tower(TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_OPPONENT, princess_hp))

	var lane = LaneScript.new(0)
	lane.set_towers(p_king, o_king)   # end0(progress 0)=玩家王塔, end1(progress 1)=对手王塔
	add_lane(lane)
	return lane

func is_over() -> bool:
	return result != RESULT_ONGOING

func remaining_time() -> float:
	return maxf(match_duration - elapsed, 0.0)

func total_tower_hp(side_towers: Array) -> float:
	var sum := 0.0
	for t in side_towers:
		sum += float(t.hp)
	return sum

# 推进一个逻辑步（dt 秒）：先结算各 lane，再计时与胜负。对局已结束则不再推进。
func step(dt: float) -> void:
	if dt <= 0.0 or is_over():
		return
	for lane in lanes:
		lane.tick(dt)
	elapsed += dt
	_check_victory()

func _check_victory() -> void:
	var player_king_down: bool = player_king != null and player_king.is_destroyed()
	var opponent_king_down: bool = opponent_king != null and opponent_king.is_destroyed()

	# 王塔归零 → 立即判负（同 tick 双王塔皆毁 → 平）。
	if player_king_down and opponent_king_down:
		result = RESULT_DRAW
		return
	if opponent_king_down:
		result = RESULT_PLAYER_WIN
		return
	if player_king_down:
		result = RESULT_OPPONENT_WIN
		return

	# 时间到 → 比剩余塔血总和。
	if match_duration > 0.0 and elapsed >= match_duration - _EPSILON:
		var p := total_tower_hp(player_towers)
		var o := total_tower_hp(opponent_towers)
		if p > o:
			result = RESULT_PLAYER_WIN
		elif o > p:
			result = RESULT_OPPONENT_WIN
		else:
			result = RESULT_DRAW
