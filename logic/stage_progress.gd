# StageProgress —— V5 闯关线性推进 + 星级判定（复用 CampaignState 范式 [[campaign_state]]，
# 但进度持久在 PlayerData.stages，跨 run 留存）。
#
# 关卡按 (chapter, index) 排成一条线性序列：序列第一关恒解锁，之后每关需前一关已通关才解锁。
# 通关 = 玩家胜（≥1 星）；星级 = 通关(1 星) + 命中的 bonus 目标数（保塔血/限时…），上限 = stars 配置条数。
# 纯逻辑、确定性、可 headless 单测；读写 PlayerData.stages（{stars,cleared}）+ highest_cleared。
extends RefCounted
class_name StageProgress

var ordered: Array = []   # [{id, chapter, index}...]，按 (chapter, index) 升序

func _init(stages_config: Dictionary = {}) -> void:
	build(stages_config)

func build(stages_config: Dictionary) -> void:
	var items: Array = []
	for sid in stages_config:
		if String(sid).begins_with("_"):
			continue
		var st = stages_config[sid]
		if typeof(st) != TYPE_DICTIONARY:
			continue
		items.append({"id": String(sid), "chapter": int(st.get("chapter", 0)), "index": int(st.get("index", 0))})
	items.sort_custom(_cmp_stage)
	ordered = items

func _cmp_stage(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("chapter", 0)) != int(b.get("chapter", 0)):
		return int(a.get("chapter", 0)) < int(b.get("chapter", 0))
	return int(a.get("index", 0)) < int(b.get("index", 0))

func ordered_ids() -> Array:
	var out: Array = []
	for it in ordered:
		out.append(String(it.get("id", "")))
	return out

# 某关是否解锁：序列第一关恒解锁；否则前一关已通关。
func is_unlocked(stage_id: String, player_data) -> bool:
	var ids := ordered_ids()
	var i := ids.find(stage_id)
	if i < 0:
		return false
	if i == 0:
		return true
	return _is_cleared(ids[i - 1], player_data)

# 下一关 = 序列中第一个未通关的关（其前面都已通关 → 必已解锁）。全通关 → ""。
func next_stage(player_data) -> String:
	for sid in ordered_ids():
		if not _is_cleared(sid, player_data):
			return sid
	return ""

func is_all_cleared(player_data) -> bool:
	var ids := ordered_ids()
	if ids.is_empty():
		return false
	for sid in ids:
		if not _is_cleared(sid, player_data):
			return false
	return true

# 某章累计星数（章节奖励用，V5-S6）。
func chapter_stars(chapter: int, player_data) -> int:
	var total := 0
	for it in ordered:
		if int(it.get("chapter", 0)) != chapter:
			continue
		var st = player_data.stages.get(String(it.get("id", "")), {})
		if typeof(st) == TYPE_DICTIONARY:
			total += int(st.get("stars", 0))
	return total

# 喂入一关结果：stars≥1 = 通关 → 标记 cleared + 星数取 max + 刷新 highest_cleared。
# stars=0（未取胜）= 不推进（沿用 roguelite/campaign 二元：仅胜推进 [[campaign_state]]）。
func apply_result(stage_id: String, stars: int, player_data) -> void:
	if stars <= 0:
		return
	var prev = player_data.stages.get(stage_id, {})
	var prev_stars := 0
	if typeof(prev) == TYPE_DICTIONARY:
		prev_stars = int(prev.get("stars", 0))
	player_data.stages[stage_id] = {"stars": maxi(prev_stars, stars), "cleared": true}
	_update_highest(player_data)

func _update_highest(player_data) -> void:
	var highest := ""
	for sid in ordered_ids():
		if _is_cleared(sid, player_data):
			highest = sid
	player_data.highest_cleared = highest

func _is_cleared(stage_id: String, player_data) -> bool:
	var st = player_data.stages.get(stage_id, {})
	return typeof(st) == TYPE_DICTIONARY and bool(st.get("cleared", false))

# —— 星级判定（纯静态函数，给 view/battle 在战斗结束时调）——
# outcome = {won:bool, king_hp_pct:float(0~1), duration_sec:float}。
# 未通关 → 0 星；通关 → 命中的目标数（goal "win" 必中 → 至少 1 星）。
static func judge_stars(stars_config: Array, outcome: Dictionary) -> int:
	if not bool(outcome.get("won", false)):
		return 0
	var stars := 0
	for goal in stars_config:
		if typeof(goal) == TYPE_DICTIONARY and _goal_met(goal, outcome):
			stars += 1
	return stars

static func _goal_met(goal: Dictionary, outcome: Dictionary) -> bool:
	match String(goal.get("goal", "")):
		"win":
			return bool(outcome.get("won", false))
		"king_hp_pct":
			return float(outcome.get("king_hp_pct", 0.0)) >= float(goal.get("min", 0.0))
		"time_under":
			return float(outcome.get("duration_sec", 1.0e9)) <= float(goal.get("sec", 0.0))
	return false
