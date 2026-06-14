# ConfigLoader —— 读取 res://config 下的三张 JSON（cards/units/levels）并存为字典。
#
# 职责边界（重要）：
#   - 只负责「读入 + 基础结构校验 + 交叉引用校验」。
#   - 不解释技能语义、距离/速度单位等（属 PLAN §9 待细化，留到 Step 4/6 处理）。
#   - 不依赖 Godot 渲染，可在 --headless 下运行。
# 数值/卡牌全走 JSON：改数值不改代码。
extends RefCounted
class_name ConfigLoader

const DEFAULT_CONFIG_DIR := "res://config"

var cards: Dictionary = {}
var units: Dictionary = {}
var levels: Dictionary = {}
var arena: Dictionary = {}      # V3：2D 场地配置（arena.json），结构性、不进 Excel 镜像
var errors: Array[String] = []

# 读入配置；全部成功且校验无误返回 true，否则 false（详情见 errors）。
func load_all(config_dir: String = DEFAULT_CONFIG_DIR) -> bool:
	errors.clear()
	cards = _load_json_dict(config_dir.path_join("cards.json"))
	units = _load_json_dict(config_dir.path_join("units.json"))
	levels = _load_json_dict(config_dir.path_join("levels.json"))
	arena = _load_json_dict(config_dir.path_join("arena.json"))
	_validate()
	return errors.is_empty()

func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("配置文件不存在: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("配置文件为空或读取失败: %s" % path)
		return {}
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("JSON 解析失败 %s (第 %d 行): %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("配置根节点应为对象(Dictionary): %s" % path)
		return {}
	return json.data

# 基础 + 交叉引用校验。只查结构与引用完整性，不查语义合理性。
func _validate() -> void:
	for id in cards:
		var card = cards[id]
		if typeof(card) != TYPE_DICTIONARY:
			errors.append("card '%s' 应为对象" % id)
			continue
		if not card.has("elixir_cost"):
			errors.append("card '%s' 缺少 elixir_cost" % id)
		if not (card.has("skills") and typeof(card["skills"]) == TYPE_ARRAY):
			errors.append("card '%s' 缺少 skills 数组" % id)

	for id in units:
		var u = units[id]
		if typeof(u) != TYPE_DICTIONARY:
			errors.append("unit '%s' 应为对象" % id)
			continue
		for f in ["hp", "damage", "attack_speed", "move_speed", "attack_range", "target_type"]:
			if not u.has(f):
				errors.append("unit '%s' 缺少 %s" % [id, f])
		# V3：attack_range 量纲改为 tile 距离（≥0，无上限）；move_speed 为 tile/秒。
		if u.has("attack_range"):
			var attack_range = u.get("attack_range")
			if not _is_number(attack_range):
				errors.append("unit '%s' 的 attack_range 应为数字" % id)
			elif float(attack_range) < 0.0:
				errors.append("unit '%s' 的 attack_range 应 ≥ 0" % id)
		if u.has("target_type") and not ["ground", "air"].has(str(u.get("target_type"))):
			errors.append("unit '%s' 的 target_type 应为 ground 或 air" % id)

	for id in levels:
		var lv = levels[id]
		if typeof(lv) != TYPE_DICTIONARY:
			errors.append("level '%s' 应为对象" % id)
			continue
		for f in ["elixir_regen_rate", "elixir_max", "match_duration"]:
			if not lv.has(f):
				errors.append("level '%s' 缺少 %s" % [id, f])

	# arena.json（V3）：至少有 default 场地，含 grid/river/deploy/towers。
	if arena.is_empty() or not arena.has("default"):
		errors.append("arena.json 缺少 default 场地配置")
	elif typeof(arena.get("default")) != TYPE_DICTIONARY:
		errors.append("arena.default 应为对象")
	else:
		for f in ["grid", "river", "deploy", "towers"]:
			if not (arena["default"] as Dictionary).has(f):
				errors.append("arena.default 缺少 %s" % f)

	# 交叉引用：spawn_unit.unit_id 必须在 units 中；deck 中的 card 必须在 cards 中。
	for cid in cards:
		var card = cards[cid]
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var skills = card.get("skills", [])
		if typeof(skills) != TYPE_ARRAY:
			continue
		for sk in skills:
			if typeof(sk) == TYPE_DICTIONARY and sk.get("type") == "spawn_unit":
				var uid = sk.get("unit_id", "")
				if not units.has(uid):
					errors.append("card '%s' 的 spawn_unit 引用了不存在的 unit '%s'" % [cid, str(uid)])

	# 交叉引用：unit.death_spawn_unit（亡语召唤，V3-3）必须在 units 中。
	for uid in units:
		var u = units[uid]
		if typeof(u) == TYPE_DICTIONARY and u.has("death_spawn_unit"):
			var dsid = str(u.get("death_spawn_unit", ""))
			if not units.has(dsid):
				errors.append("unit '%s' 的 death_spawn_unit 引用了不存在的 unit '%s'" % [uid, dsid])

	for lid in levels:
		var lv = levels[lid]
		if typeof(lv) != TYPE_DICTIONARY:
			continue
		for deck_key in ["player_deck", "ai_deck"]:
			var deck = lv.get(deck_key, [])
			if typeof(deck) != TYPE_ARRAY:
				continue
			for cid in deck:
				if not cards.has(cid):
					errors.append("level '%s' 的 %s 引用了不存在的 card '%s'" % [lid, deck_key, str(cid)])

# —— 便捷访问 ——
func get_card(id: String) -> Dictionary:
	return cards.get(id, {})

func get_unit(id: String) -> Dictionary:
	return units.get(id, {})

func get_level(id: String) -> Dictionary:
	return levels.get(id, {})

func get_arena(id: String = "default") -> Dictionary:
	return arena.get(id, {})

func has_card(id: String) -> bool:
	return cards.has(id)

func has_unit(id: String) -> bool:
	return units.has(id)

func has_level(id: String) -> bool:
	return levels.has(id)

func _is_number(value) -> bool:
	var t := typeof(value)
	return t == TYPE_INT or t == TYPE_FLOAT
