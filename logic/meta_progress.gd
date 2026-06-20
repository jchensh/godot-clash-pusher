# MetaProgress —— 局间持久进度 + 解锁解算（V3-4d）。
#
# 跨 run 累积的统计（开局数/通关数/击败 boss 数），存盘于 user://（见 SaveSystem）。
# 解锁 = relic 上的 `unlock` 门控（`{stat: 阈值}`）：满足 → 该 relic 进入「可用池」。
# 纯逻辑、确定性、可单测；compute/查询不修改自身。
extends RefCounted
class_name MetaProgress

var runs_started: int = 0
var runs_won: int = 0
var bosses_defeated: int = 0

func record_run_start() -> void:
	runs_started += 1

func record_boss_defeated() -> void:
	bosses_defeated += 1

func record_run_end(won: bool) -> void:
	if won:
		runs_won += 1

# 当前可用的 relic id 列表：无 `unlock` 门控的（base）+ 门控已满足的（已解锁）。
func available_relics(relic_defs: Dictionary) -> Array:
	var out: Array = []
	for rid in relic_defs:
		var rdef = relic_defs[rid]
		if typeof(rdef) != TYPE_DICTIONARY:
			continue
		if not rdef.has("unlock") or _meets(rdef.get("unlock")):
			out.append(rid)
	return out

# 仅「被 unlock 门控且已满足」的 relic id（解锁解算结果，用于展示/单测）。
func unlocked_ids(relic_defs: Dictionary) -> Array:
	var out: Array = []
	for rid in relic_defs:
		var rdef = relic_defs[rid]
		if typeof(rdef) == TYPE_DICTIONARY and rdef.has("unlock") and _meets(rdef.get("unlock")):
			out.append(rid)
	return out

func _meets(req) -> bool:
	if typeof(req) != TYPE_DICTIONARY:
		return true
	for stat in req:
		if _stat(String(stat)) < int(req[stat]):
			return false
	return true

func _stat(name: String) -> int:
	match name:
		"runs_started": return runs_started
		"runs_won": return runs_won
		"bosses_defeated": return bosses_defeated
	return 0

func to_dict() -> Dictionary:
	return {"runs_started": runs_started, "runs_won": runs_won, "bosses_defeated": bosses_defeated}

# 从 dict 读入（实例方法，不引用自身 class_name → 不依赖全局注册，避免新脚本预检踩坑）。
func load_dict(d: Dictionary) -> void:
	runs_started = int(d.get("runs_started", 0))
	runs_won = int(d.get("runs_won", 0))
	bosses_defeated = int(d.get("bosses_defeated", 0))
