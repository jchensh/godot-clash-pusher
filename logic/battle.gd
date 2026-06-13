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
const ArenaScript = preload("res://logic/arena.gd")

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
var lanes: Array = []             # Lane（V2 1D 模型；V3 2D 重构期间与 arena 并存）
var arena = null                  # Arena（V3 2D 场地；V3-1 重构逐步接管）

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

# 便捷搭建：按 level 配置建一个 V2 三 lane 对局（PLAN_V2 §3 A）。
# 拓扑：lane 0 左→公主、lane 1 中→王、lane 2 右→公主；双方各 1 王 + 2 公主。
# 侧路（0/2）挂兜底王塔：公主塔被摧毁后该 lane 单位转打王塔（皇室战争式）。
# 6 塔全部计入 player/opponent_towers，胜负与超时比塔血规则与 V1 一致。返回 lanes 数组。
func build_v2_three_lanes(level: Dictionary) -> Array:
	match_duration = float(level.get("match_duration", 0.0))
	var tower_hp: Dictionary = level.get("tower_hp", {})
	var king_hp := float(tower_hp.get("king", 0.0))
	var princess_hp := float(tower_hp.get("princess", 0.0))

	var p_king = TowerScript.new(TowerScript.KIND_KING, UnitScript.OWNER_PLAYER, king_hp)
	var p_left = TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_PLAYER, princess_hp)
	var p_right = TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_PLAYER, princess_hp)
	add_player_tower(p_king)
	add_player_tower(p_left)
	add_player_tower(p_right)

	var o_king = TowerScript.new(TowerScript.KIND_KING, UnitScript.OWNER_OPPONENT, king_hp)
	var o_left = TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_OPPONENT, princess_hp)
	var o_right = TowerScript.new(TowerScript.KIND_PRINCESS, UnitScript.OWNER_OPPONENT, princess_hp)
	add_opponent_tower(o_king)
	add_opponent_tower(o_left)
	add_opponent_tower(o_right)

	var lane_left = LaneScript.new(0)
	lane_left.set_towers(p_left, o_left)
	lane_left.set_king_fallback(p_king, o_king)
	add_lane(lane_left)

	var lane_mid = LaneScript.new(1)
	lane_mid.set_towers(p_king, o_king)   # 中路主塔即王塔，无需兜底
	add_lane(lane_mid)

	var lane_right = LaneScript.new(2)
	lane_right.set_towers(p_right, o_right)
	lane_right.set_king_fallback(p_king, o_king)
	add_lane(lane_right)

	return lanes

# 便捷搭建：按 level + arena 配置建一个 V3 2D 场地对局（PLAN_V3 §4）。
# 建 2D 地形 + 双方各 3 塔（2 公主 + 1 王，按 arena 塔位摆放、注册占位）。
# 胜负与超时比塔血规则沿用 V1/V2（6 塔全部计入 player/opponent_towers）。返回 Arena。
# V3-1a：只建地形与塔；单位移动/寻路/tick 见后续小步。
func build_arena(level: Dictionary, arena_cfg: Dictionary):
	match_duration = float(level.get("match_duration", 0.0))
	var tower_hp: Dictionary = level.get("tower_hp", {})
	var king_hp := float(tower_hp.get("king", 0.0))
	var princess_hp := float(tower_hp.get("princess", 0.0))

	arena = ArenaScript.new()
	arena.setup(arena_cfg)

	var towers_cfg: Dictionary = arena_cfg.get("towers", {})
	_build_side_towers(UnitScript.OWNER_PLAYER, towers_cfg.get("player", {}), king_hp, princess_hp)
	_build_side_towers(UnitScript.OWNER_OPPONENT, towers_cfg.get("enemy", {}), king_hp, princess_hp)
	return arena

func _build_side_towers(owner_id: int, side_cfg: Dictionary, king_hp: float, princess_hp: float) -> void:
	for key in side_cfg:
		var t: Dictionary = side_cfg[key]
		var is_king: bool = String(key).begins_with("king")
		var kind: String = TowerScript.KIND_KING if is_king else TowerScript.KIND_PRINCESS
		var hp: float = king_hp if is_king else princess_hp
		var tower = TowerScript.new(kind, owner_id, hp)
		tower.pos = Vector2(float(t.get("x", 0.0)), float(t.get("y", 0.0)))
		tower.fw = int(t.get("fw", 3))
		tower.fh = int(t.get("fh", 3))
		if owner_id == UnitScript.OWNER_PLAYER:
			add_player_tower(tower)
		else:
			add_opponent_tower(tower)
		arena.add_tower_footprint(tower.pos.x, tower.pos.y, tower.fw, tower.fh)

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
