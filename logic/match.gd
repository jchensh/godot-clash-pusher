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
const RunModifiersScript = preload("res://logic/run_modifiers.gd")

var config            # ConfigLoader
var battle            # Battle
var skill_system      # SkillSystem
var clock             # SimClock
var player            # Player（OWNER_PLAYER）
var opponent          # Player（OWNER_OPPONENT）
var opponent_controller = null   # 规则 AI（可空，鸭子类型）：每逻辑 tick 由 update 驱动
var ai_difficulty := "normal"    # 关卡 AI 难度（V2-6）：供 AIController 读取分级行为
var net_tick: int = 0            # V4-S3 lockstep：advance_tick 推进过的 tick 数（单机 update 不用）

func _init(config_ = null) -> void:
	config = config_

# 按关卡配置搭好一局：2D 场地（河+双桥+地形）+ 双方各 3 塔（2 公主 1 王）、
# 两个对称 Player、固定时钟。
# modifiers（V3-4c）：relic / 节点难度修正器数组；经 RunModifiers 作用于 **effective level 副本**，
# 不污染 ConfigLoader 基础配置。空数组 = 行为与改前一致（起手圣水仍 0）。
# opponent_deck_override（V4-S3 lockstep）：联机时双方卡组都由服务端开局下发，
# 故需能显式指定对手卡组（side2_deck）；单机不传 = 用关卡 ai_deck（行为不变）。
func setup(level_id: String = "level_01", player_deck_override: Array = [], modifiers: Array = [], opponent_deck_override: Array = []) -> void:
	var level: Dictionary = RunModifiersScript.effective_level(config.get_level(level_id), modifiers)
	ai_difficulty = String(level.get("ai_difficulty", "normal"))
	battle = BattleScript.new()
	battle.build_arena(level, config.get_arena("default"))
	skill_system = SkillSystemScript.new(config, battle)
	clock = SimClockScript.new()
	var emax := float(level.get("elixir_max", 10))
	var regen := float(level.get("elixir_regen_rate", 1.0))
	var estart := float(level.get("elixir_start", 0.0))   # 默认 0（决策日志 7）；relic「起手圣水」可抬高
	# 玩家卡组：组卡界面给了覆盖（非空）就用它，否则用关卡默认（决策 34，V2-7c）。
	var player_deck_ids: Array = player_deck_override if not player_deck_override.is_empty() else level.get("player_deck", [])
	var opp_deck_ids: Array = opponent_deck_override if not opponent_deck_override.is_empty() else level.get("ai_deck", [])
	player = _make_player(UnitScript.OWNER_PLAYER, player_deck_ids, emax, regen, estart)
	opponent = _make_player(UnitScript.OWNER_OPPONENT, opp_deck_ids, emax, regen, estart)

func _make_player(owner_id: int, deck_ids: Array, emax: float, regen: float, estart: float = 0.0):
	var elixir = ElixirScript.new(emax, regen, estart)
	var deck = DeckScript.new(deck_ids)
	return PlayerScript.new(owner_id, elixir, deck, config, skill_system)

# V5-S1：注入双方出兵数值乘区——我方 power_mult（卡 level/rank，V5-S4/5）/ 敌方 coef（关卡难度系数，V5-S3）。
# 仅缩放 spawn 的单位 hp/damage，不动 speed/range/tick。默认双方 1.0（行为同改前）。
func set_stat_mults(player_mult: float = 1.0, opponent_mult: float = 1.0) -> void:
	if player != null:
		player.unit_stat_mult = player_mult
	if opponent != null:
		opponent.unit_stat_mult = opponent_mult

# V5-S3：按闯关关卡搭一局——读 stages 配置：encounter→敌方卡组、difficulty_coef→敌方出兵乘区、
# ai_difficulty→AI 行为档；其余对局参数（圣水/塔血/时长）走 base_level（默认 ladder_01）。
# 敌塔 HP 随 coef 放大（V5-S8d，scale_opponent_towers）；我方塔不缩放。player_data 非空 → 我方按本卡
# level/rank 养成乘区（V5-S4，per-card）；敌方按 coef flat 乘区。
func setup_stage(stage_id: String, player_deck_override: Array = [], player_data = null) -> void:
	var stage: Dictionary = config.get_stage(stage_id)
	var coef := float(stage.get("difficulty_coef", 1.0))
	var enc: Dictionary = config.get_encounter(String(stage.get("encounter", "")))
	var enemy_deck: Array = enc.get("deck", [])
	var base_level := String(stage.get("base_level", "ladder_01"))
	setup(base_level, player_deck_override, [], enemy_deck)
	ai_difficulty = String(stage.get("ai_difficulty", ai_difficulty))
	set_stat_mults(1.0, coef)        # 敌方 coef；我方 flat 1.0（养成走 player_data per-card）
	scale_opponent_towers(coef)      # V5-S8d：敌塔 HP 也随 coef 放大（我方塔不动）→ 高系数关推塔更难
	if player_data != null:
		player.player_data = player_data

# V5-S8d：把敌方(OWNER_OPPONENT)三塔 HP 乘 mult（满血开局）。我方塔不动 → 高 coef 关推塔更难、
# 防守相对更易（吻合「战力为底」：需养成才推得动）。mult≈1.0 时 no-op（零回归）。
func scale_opponent_towers(mult: float) -> void:
	if battle == null or is_equal_approx(mult, 1.0):
		return
	for t in battle.opponent_towers:
		t.max_hp *= mult
		t.hp = t.max_hp

# 注入对手控制器（规则 AI）。不注入则对手被动（Step 7 行为）。
func set_opponent_controller(controller) -> void:
	opponent_controller = controller

# 显示层每帧调用：固定 tick 推进。对局已结束则不再推进。
func update(real_dt: float) -> void:
	if battle == null or battle.is_over():
		return
	var n: int = clock.advance(real_dt)
	for i in n:
		player.regen(SimClockScript.TICK_DELTA)
		opponent.regen(SimClockScript.TICK_DELTA)
		if opponent_controller != null:
			opponent_controller.tick(SimClockScript.TICK_DELTA)
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


# ============================================================================
# V4-S3 lockstep —— 联机对战专用（单机 update() 完全不走以下路径）。
#
# 与单机的根本区别：tick 不由本地时钟驱动、对手不由 AI 驱动，而是
# **两端各自的 Match 收到服务端同一个 TickBundle 后调 advance_tick(同一组 deploys)**，
# 各自跑 logic/ 推进同一 tick。逻辑层无随机 + 卡组确定性循环（决策见 PLAN_V4 §5.3）→
# 同输入必同输出；每 N tick 调 state_hash() 三方对帐校验是否真同步。
#
# side 约定：wire 的 side=1 ↔ OWNER_PLAYER(player)，side=2 ↔ OWNER_OPPONENT(opponent)，
# 两端一致（本地玩家是 1 还是 2 只影响 view 的视角/输入，不影响 Match 内部对称推进）。
# ============================================================================

const _HASH_Q := 1000.0   # 状态量化精度：浮点 ×1000 取整再哈希，吸收末位浮点噪声

# 推进恰好一个 lockstep tick。deploys = 本 tick 双方出兵指令，顺序由服务端 TickBundle 决定
# （两端收到同序 → 应用同序 → 确定性一致）。每条 = {side:int(1/2), card_id:String, pos:Vector2(tile)}。
# 顺序与单机 update 对齐：先双方圣水回涨 → 再应用出兵 → 再 battle.step 结算。
func advance_tick(deploys: Array = []) -> void:
	if battle == null or battle.is_over():
		return
	player.regen(SimClockScript.TICK_DELTA)
	opponent.regen(SimClockScript.TICK_DELTA)
	for d in deploys:
		_apply_deploy(d)
	battle.step(SimClockScript.TICK_DELTA)
	net_tick += 1

# 应用一条出兵：按 side 选 Player，按 card_id 在其手牌反查格位再 try_play_card。
# 卡不在手 / side 非法 → 确定性 no-op（丢弃非法或作弊指令，两端一致）。
# 圣水不足 / 落点非法由 try_play_card 自身按确定性规则拒绝。
func _apply_deploy(d: Dictionary) -> void:
	var side := int(d.get("side", 0))
	var p = null
	if side == 1:
		p = player
	elif side == 2:
		p = opponent
	if p == null:
		return
	var card_id = d.get("card_id", null)
	if card_id == null:
		return
	var pos: Vector2 = d.get("pos", Vector2.ZERO)
	var idx: int = p.deck.get_hand().find(card_id)
	if idx < 0:
		return
	p.try_play_card(idx, pos)

# 当前权威状态的确定性哈希（sha256，32 bytes），按 proto 约定 = units + towers + elixir。
# 浮点全部量化成 int32（×1000 取整）再写入固定字节序，避免末位浮点表示差异误判不同步。
# 遍历顺序固定：圣水(双方) → units(arena 列表序，spawn 确定性) → 塔(player 序 + opponent 序)。
func state_hash() -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	if battle == null:
		return PackedByteArray()
	buf.put_32(_q(player.elixir.get_amount()) if player != null else 0)
	buf.put_32(_q(opponent.elixir.get_amount()) if opponent != null else 0)
	if battle.arena != null:
		var us: Array = battle.arena.units
		buf.put_32(us.size())
		for u in us:
			buf.put_utf8_string(u.unit_id)
			buf.put_32(u.owner_id)
			buf.put_32(_q(u.pos.x))
			buf.put_32(_q(u.pos.y))
			buf.put_32(_q(u.hp))
			buf.put_32(_q(u._attack_cooldown))
	for t in battle.player_towers:
		_hash_tower(buf, t)
	for t in battle.opponent_towers:
		_hash_tower(buf, t)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf.data_array)
	return ctx.finish()

func _hash_tower(buf: StreamPeerBuffer, t) -> void:
	buf.put_utf8_string(t.kind)
	buf.put_32(t.owner_id)
	buf.put_32(_q(t.hp))
	buf.put_32(_q(t._attack_cooldown))

func _q(v: float) -> int:
	return int(round(v * _HASH_Q))
