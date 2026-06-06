# Match —— 一局对战的逻辑总驱动（PLAN §3 数据流的「逻辑层」一侧）。
#
# 组合：Battle（塔/lane/胜负）+ 两个对称 Player（圣水+卡组）+ SkillSystem + SimClock。
# update(real_dt) 由显示层每帧调用：把可变帧 dt 经 SimClock 折成固定 10Hz tick，
# 逐 tick 推进双方圣水回涨 + battle.step，使「游戏速度与渲染帧率解耦」（PLAN §8）。
# 显示层只读本类状态作画；出牌一律经 player/opponent.try_play_card（玩家 AI 对称）。
# 纯逻辑、可 headless 测；跨脚本一律 preload。
extends RefCounted
class_name Match

const BattleScript = preload("res://logic/battle.gd")
const SkillSystemScript = preload("res://logic/skill_system.gd")
const PlayerScript = preload("res://logic/player.gd")
const ElixirScript = preload("res://logic/elixir.gd")
const DeckScript = preload("res://logic/deck.gd")
const SimClockScript = preload("res://logic/sim_clock.gd")
const UnitScript = preload("res://logic/unit.gd")

var config            # ConfigLoader
var battle            # Battle
var skill_system      # SkillSystem
var clock             # SimClock
var player            # Player（OWNER_PLAYER）
var opponent          # Player（OWNER_OPPONENT）

func _init(config_ = null) -> void:
	config = config_

# 按关卡配置搭好一局：双方各 3 塔 + 单 lane（V1）、两个对称 Player、固定时钟。
func setup(level_id: String = "level_01") -> void:
	var level: Dictionary = config.get_level(level_id)
	battle = BattleScript.new()
	battle.build_v1_single_lane(level)
	skill_system = SkillSystemScript.new(config, battle)
	clock = SimClockScript.new()
	var emax := float(level.get("elixir_max", 10))
	var regen := float(level.get("elixir_regen_rate", 1.0))
	player = _make_player(UnitScript.OWNER_PLAYER, level.get("player_deck", []), emax, regen)
	opponent = _make_player(UnitScript.OWNER_OPPONENT, level.get("ai_deck", []), emax, regen)

func _make_player(owner_id: int, deck_ids: Array, emax: float, regen: float):
	var elixir = ElixirScript.new(emax, regen, 0.0)   # 起始圣水 0（决策日志 7）
	var deck = DeckScript.new(deck_ids)
	return PlayerScript.new(owner_id, elixir, deck, config, skill_system)

# 显示层每帧调用：固定 tick 推进。对局已结束则不再推进。
func update(real_dt: float) -> void:
	if battle == null or battle.is_over():
		return
	var n: int = clock.advance(real_dt)
	for i in n:
		player.regen(SimClockScript.TICK_DELTA)
		opponent.regen(SimClockScript.TICK_DELTA)
		battle.step(SimClockScript.TICK_DELTA)
		if battle.is_over():
			break

func is_over() -> bool:
	return battle != null and battle.is_over()

func get_result() -> int:
	return battle.result if battle != null else BattleScript.RESULT_ONGOING

# 显示层插值用：当前未满一个 tick 的余量比例 0.0~1.0。
func get_interpolation_fraction() -> float:
	return clock.get_interpolation_fraction() if clock != null else 0.0
