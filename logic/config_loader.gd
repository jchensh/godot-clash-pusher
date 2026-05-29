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
var errors: Array[String] = []

# 读入三张配置；全部成功且校验无误返回 true，否则 false（详情见 errors）。
func load_all(config_dir: String = DEFAULT_CONFIG_DIR) -> bool:
	errors.clear()
	cards = _load_json_dict(config_dir.path_join("cards.json"))
	units = _load_json_dict(config_dir.path_join("units.json"))
	levels = _load_json_dict(config_dir.path_join("levels.json"))
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
		for f in ["hp", "damage", "move_speed"]:
			if not u.has(f):
				errors.append("unit '%s' 缺少 %s" % [id, f])

	for id in levels:
		var lv = levels[id]
		if typeof(lv) != TYPE_DICTIONARY:
			errors.append("level '%s' 应为对象" % id)
			continue
		for f in ["elixir_regen_rate", "elixir_max", "match_duration"]:
			if not lv.has(f):
				errors.append("level '%s' 缺少 %s" % [id, f])

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

func has_card(id: String) -> bool:
	return cards.has(id)

func has_unit(id: String) -> bool:
	return units.has(id)

func has_level(id: String) -> bool:
	return levels.has(id)
