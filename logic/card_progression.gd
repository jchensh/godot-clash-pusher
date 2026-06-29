# CardProgression —— V5-S5：把卡的升阶解锁（card_progression.rank_unlocks[r].ops）应用到 skills
# 数组，返回 effective 副本（深拷贝、不改 base；rank 2..当前 rank 顺序叠加）。
#
# ops 类型：
#   count_add  —— spawn 块 count += value
#   num_add    —— 某块 field（radius/damage…）+= value
#   num_mult   —— 某块 field *= value
#   unit_field —— 在 spawn 块挂 _unit_override[field]=value（SkillSystem 生成单位前合并进 unit 配置，
#                 如 death_spawn_count；见 skill_system._spawn_unit）
# type=stat 的解锁不需 ops（数值跳已由 PlayerData.card_stat_mult 的阶乘吸收）。
# 纯静态、可单测。block 缺省 = 0（当前卡均单积木）。
extends RefCounted
class_name CardProgression

static func effective_skills(base_skills: Array, rank_unlocks: Dictionary, rank: int) -> Array:
	var skills: Array = base_skills.duplicate(true)
	for r in range(2, rank + 1):
		var entry = rank_unlocks.get(str(r), {})
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ops = entry.get("ops", [])
		if typeof(ops) != TYPE_ARRAY:
			continue
		for op in ops:
			if typeof(op) == TYPE_DICTIONARY:
				_apply_op(skills, op)
	return skills

static func _apply_op(skills: Array, op: Dictionary) -> void:
	var idx := int(op.get("block", 0))
	if idx < 0 or idx >= skills.size():
		return
	var block = skills[idx]
	if typeof(block) != TYPE_DICTIONARY:
		return
	match String(op.get("op", "")):
		"count_add":
			block["count"] = int(block.get("count", 0)) + int(op.get("value", 0))
		"num_add":
			var fa := String(op.get("field", ""))
			block[fa] = float(block.get(fa, 0.0)) + float(op.get("value", 0.0))
		"num_mult":
			var fm := String(op.get("field", ""))
			block[fm] = float(block.get(fm, 0.0)) * float(op.get("value", 1.0))
		"unit_field":
			var ov = block.get("_unit_override", {})
			if typeof(ov) != TYPE_DICTIONARY:
				ov = {}
			ov[String(op.get("field", ""))] = op.get("value")
			block["_unit_override"] = ov
