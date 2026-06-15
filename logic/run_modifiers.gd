# RunModifiers —— Roguelite 数值修正器引擎（V3-4c）。
#
# 对一份 level 配置应用一组 mod（relic 修正器 / 节点难度修正），返回 **effective 副本**——
# base_level 深拷贝后修改，**绝不污染基础配置**（ConfigLoader 的 dict 不变）。
# mod 格式：`{ field: {"add": x, "mult": y} }`，单源单字段 `val = val * mult(默认1) + add(默认0)`；
# 多个 mod 源按数组顺序**顺序叠加**（确定性）。
# 作用域 = level 级数值（圣水回速/上限/起手、对局时长、王/公主塔血）；
# 单位级 relic（兵伤/血加成）留后续——需注入 SkillSystem 生成路径，本步不做。
extends RefCounted
class_name RunModifiers

# 可修正的 level 顶层数值字段（tower_hp 嵌套字段单列处理）。
const _LEVEL_FIELDS := ["elixir_regen_rate", "elixir_max", "elixir_start", "match_duration"]

# 返回 base_level 应用全部 mod 后的 effective 副本（深拷贝，base 不变）。
static func effective_level(base_level: Dictionary, mod_sources: Array) -> Dictionary:
	var lv: Dictionary = base_level.duplicate(true)   # 深拷贝 → base 不被改
	if not lv.has("elixir_start"):
		lv["elixir_start"] = 0.0
	var tower_hp: Dictionary = {}
	if typeof(lv.get("tower_hp")) == TYPE_DICTIONARY:
		tower_hp = lv["tower_hp"]                       # 已是深拷贝的独立 dict
	for src in mod_sources:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for field in _LEVEL_FIELDS:
			if src.has(field):
				lv[field] = _apply(float(lv.get(field, 0.0)), src[field])
		if src.has("tower_hp_king"):
			tower_hp["king"] = _apply(float(tower_hp.get("king", 0.0)), src["tower_hp_king"])
		if src.has("tower_hp_princess"):
			tower_hp["princess"] = _apply(float(tower_hp.get("princess", 0.0)), src["tower_hp_princess"])
	lv["tower_hp"] = tower_hp
	return lv

# 节点难度修正（V3-4d）：run 配置里 node_modifiers[node_type]（elite/boss 抬塔血等），无则空。
static func node_mod(run_cfg: Dictionary, node_type: String) -> Dictionary:
	var nm = run_cfg.get("node_modifiers", {})
	if typeof(nm) != TYPE_DICTIONARY:
		return {}
	var m = nm.get(node_type, {})
	return m if typeof(m) == TYPE_DICTIONARY else {}

# 解析 relic id 列表 → mod 源数组（查 relic_defs 取各自 mods）。
static func relic_mods(relic_ids: Array, relic_defs: Dictionary) -> Array:
	var out: Array = []
	for rid in relic_ids:
		var rdef = relic_defs.get(rid, {})
		if typeof(rdef) == TYPE_DICTIONARY and typeof(rdef.get("mods")) == TYPE_DICTIONARY:
			out.append(rdef["mods"])
	return out

static func _apply(val: float, op) -> float:
	if typeof(op) != TYPE_DICTIONARY:
		return val
	return val * float(op.get("mult", 1.0)) + float(op.get("add", 0.0))
