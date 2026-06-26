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
var run: Dictionary = {}        # V3-4：Roguelite run 结构（run.json），结构性、不进 Excel 镜像
var relics: Dictionary = {}     # V3-4c：relic 修正器池（relics.json），结构性、不进 Excel 镜像
var campaign: Dictionary = {}   # V3-5：短战役关卡序列（campaign.json），结构性、不进 Excel 镜像
var tutorial: Dictionary = {}   # V3-5b：新手引导脚本（tutorial.json），结构性、不进 Excel 镜像
var audio_assets: Dictionary = {} # V3-8：音频资源表（AudioConfig.xlsx -> audio_assets.json）
var stages: Dictionary = {}          # V5-S0：闯关关卡表（stages.json），结构性、不进 Excel 镜像
var encounters: Dictionary = {}      # V5-S0：遭遇模板池（encounters.json），结构性、不进 Excel 镜像
var economy: Dictionary = {}         # V5-S0：经济数值（economy.json）
var card_progression: Dictionary = {} # V5-S0：卡牌养成元数据（card_progression.json）
var errors: Array[String] = []

# 读入配置；全部成功且校验无误返回 true，否则 false（详情见 errors）。
func load_all(config_dir: String = DEFAULT_CONFIG_DIR) -> bool:
	errors.clear()
	cards = _load_json_dict(config_dir.path_join("cards.json"))
	units = _load_json_dict(config_dir.path_join("units.json"))
	levels = _load_json_dict(config_dir.path_join("levels.json"))
	arena = _load_json_dict(config_dir.path_join("arena.json"))
	run = _load_json_dict(config_dir.path_join("run.json"))
	relics = _load_json_dict(config_dir.path_join("relics.json"))
	campaign = _load_json_dict(config_dir.path_join("campaign.json"))
	tutorial = _load_json_dict(config_dir.path_join("tutorial.json"))
	audio_assets = _load_json_dict(config_dir.path_join("audio_assets.json"))
	stages = _load_json_dict(config_dir.path_join("stages.json"))
	encounters = _load_json_dict(config_dir.path_join("encounters.json"))
	economy = _load_json_dict(config_dir.path_join("economy.json"))
	card_progression = _load_json_dict(config_dir.path_join("card_progression.json"))
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

	# run.json（V3-4 Roguelite）：至少有 default，含非空 acts；每个节点 type 合法、
	# level_id 必须在 levels 中；starter_deck（若有）的卡必须在 cards 中。
	if run.is_empty() or not run.has("default"):
		errors.append("run.json 缺少 default run 配置")
	elif typeof(run.get("default")) != TYPE_DICTIONARY:
		errors.append("run.default 应为对象")
	else:
		var rd: Dictionary = run["default"]
		if not (rd.has("acts") and typeof(rd["acts"]) == TYPE_ARRAY and not (rd["acts"] as Array).is_empty()):
			errors.append("run.default 缺少非空 acts 数组")
		else:
			for act in (rd["acts"] as Array):
				if typeof(act) != TYPE_DICTIONARY:
					continue
				var act_nodes = act.get("nodes", [])
				if typeof(act_nodes) != TYPE_ARRAY:
					errors.append("run.default 某 act 缺少 nodes 数组")
					continue
				for n in act_nodes:
					if typeof(n) != TYPE_DICTIONARY:
						continue
					if not ["battle", "elite", "boss"].has(String(n.get("type", ""))):
						errors.append("run 节点 type 非法: '%s'" % str(n.get("type", "")))
					if not levels.has(String(n.get("level_id", ""))):
						errors.append("run 节点引用了不存在的 level '%s'" % str(n.get("level_id", "")))
		var starter = rd.get("starter_deck", [])
		if typeof(starter) == TYPE_ARRAY:
			for cid in starter:
				if not cards.has(cid):
					errors.append("run.default 的 starter_deck 引用了不存在的 card '%s'" % str(cid))

	# campaign.json（V3-5）：default 含非空 levels；每关 level_id 须在 levels 中。
	if campaign.is_empty() or not campaign.has("default"):
		errors.append("campaign.json 缺少 default 战役配置")
	elif typeof(campaign.get("default")) != TYPE_DICTIONARY:
		errors.append("campaign.default 应为对象")
	else:
		var clevels = (campaign["default"] as Dictionary).get("levels", [])
		if typeof(clevels) != TYPE_ARRAY or (clevels as Array).is_empty():
			errors.append("campaign.default 缺少非空 levels 数组")
		else:
			for cn in (clevels as Array):
				if typeof(cn) != TYPE_DICTIONARY:
					continue
				if not levels.has(String(cn.get("level_id", ""))):
					errors.append("campaign 关卡引用了不存在的 level '%s'" % str(cn.get("level_id", "")))

	# relics.json（V3-4c）：每个 relic 须为对象且含 mods 对象（数值修正器）。
	for rid in relics:
		var rdef = relics[rid]
		if typeof(rdef) != TYPE_DICTIONARY:
			errors.append("relic '%s' 应为对象" % str(rid))
			continue
		if typeof(rdef.get("mods")) != TYPE_DICTIONARY:
			errors.append("relic '%s' 缺少 mods 对象" % str(rid))

	# audio_assets.json（V3-8）：由 AudioConfig.xlsx 生成；运行时按 asset_id 查表播放。
	for aid in audio_assets:
		var adef = audio_assets[aid]
		if typeof(adef) != TYPE_DICTIONARY:
			errors.append("audio asset '%s' 应为对象" % str(aid))
			continue
		for f in ["display_name_zh", "type", "bus", "path", "asset_status", "loop", "volume_db", "pitch_min", "pitch_max", "max_polyphony"]:
			if not adef.has(f):
				errors.append("audio asset '%s' 缺少 %s" % [str(aid), f])
		if adef.has("type") and not ["music", "ambience", "stinger", "ui", "sfx"].has(str(adef.get("type"))):
			errors.append("audio asset '%s' 的 type 非法" % str(aid))
		if adef.has("asset_status") and not ["planned", "sourced", "imported", "final"].has(str(adef.get("asset_status"))):
			errors.append("audio asset '%s' 的 asset_status 非法" % str(aid))
		if adef.has("path") and not str(adef.get("path")).begins_with("res://sound/"):
			errors.append("audio asset '%s' 的 path 必须在 res://sound/ 下" % str(aid))

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

	# —— V5（KAN-50）新表校验 ——
	# card_progression.json：每卡为对象 + rarity 合法 + base_power 数字；id 须在 cards 中；
	# 且 cards 每张卡都应有 progression 条目（双向覆盖，防漏配）。忽略 _ 开头元字段。
	var _rarities := ["common", "rare", "epic", "legendary"]
	for cpid in card_progression:
		if String(cpid).begins_with("_"):
			continue
		var cp = card_progression[cpid]
		if typeof(cp) != TYPE_DICTIONARY:
			errors.append("card_progression '%s' 应为对象" % str(cpid))
			continue
		if not _rarities.has(str(cp.get("rarity", ""))):
			errors.append("card_progression '%s' 的 rarity 非法" % str(cpid))
		if not _is_number(cp.get("base_power")):
			errors.append("card_progression '%s' 缺少数字 base_power" % str(cpid))
		if not cards.has(str(cpid)):
			errors.append("card_progression '%s' 不在 cards 中" % str(cpid))
	for cid in cards:
		if not card_progression.has(cid):
			errors.append("card '%s' 缺少 card_progression 条目" % str(cid))

	# encounters.json：每模板 deck 正好 8 张、卡须在 cards 中。
	for eid in encounters:
		if String(eid).begins_with("_"):
			continue
		var enc = encounters[eid]
		if typeof(enc) != TYPE_DICTIONARY:
			errors.append("encounter '%s' 应为对象" % str(eid))
			continue
		var edeck = enc.get("deck", [])
		if typeof(edeck) != TYPE_ARRAY or (edeck as Array).size() != 8:
			errors.append("encounter '%s' 的 deck 应为 8 张卡数组" % str(eid))
		else:
			for cid in edeck:
				if not cards.has(cid):
					errors.append("encounter '%s' 的 deck 引用了不存在的 card '%s'" % [str(eid), str(cid)])

	# stages.json：含 chapter/index/encounter/difficulty_coef/ai_difficulty；encounter 须在
	# encounters 中；ai_difficulty 合法；difficulty_coef ≥1.0；奖励/掉落 card 须在 cards 中。
	var _diffs := ["rookie", "easy", "normal", "hard", "extreme"]
	for sid in stages:
		if String(sid).begins_with("_"):
			continue
		var st = stages[sid]
		if typeof(st) != TYPE_DICTIONARY:
			errors.append("stage '%s' 应为对象" % str(sid))
			continue
		for sf in ["chapter", "index", "encounter", "difficulty_coef", "ai_difficulty"]:
			if not st.has(sf):
				errors.append("stage '%s' 缺少 %s" % [str(sid), sf])
		if st.has("encounter") and not encounters.has(str(st.get("encounter"))):
			errors.append("stage '%s' 引用了不存在的 encounter '%s'" % [str(sid), str(st.get("encounter"))])
		if st.has("ai_difficulty") and not _diffs.has(str(st.get("ai_difficulty"))):
			errors.append("stage '%s' 的 ai_difficulty 非法" % str(sid))
		if st.has("difficulty_coef") and (not _is_number(st.get("difficulty_coef")) or float(st.get("difficulty_coef")) < 1.0):
			errors.append("stage '%s' 的 difficulty_coef 应为 ≥1.0 的数字" % str(sid))
		if st.has("base_level") and not levels.has(str(st.get("base_level"))):
			errors.append("stage '%s' 的 base_level 引用了不存在的 level '%s'" % [str(sid), str(st.get("base_level"))])
		var fc = st.get("first_clear", {})
		if typeof(fc) == TYPE_DICTIONARY and typeof(fc.get("shards")) == TYPE_DICTIONARY:
			for cid in (fc["shards"] as Dictionary):
				if not cards.has(cid):
					errors.append("stage '%s' first_clear.shards 引用了不存在的 card '%s'" % [str(sid), str(cid)])
		var sd = st.get("shard_drop", {})
		if typeof(sd) == TYPE_DICTIONARY:
			for cid in (sd as Dictionary):
				if not cards.has(cid):
					errors.append("stage '%s' shard_drop 引用了不存在的 card '%s'" % [str(sid), str(cid)])

	# economy.json：含关键顶层键。
	for ef in ["upgrade_total_gold", "rank_up", "unlock_shards", "idle", "rewards"]:
		if not economy.has(ef):
			errors.append("economy.json 缺少 %s" % ef)

# —— 便捷访问 ——
func get_card(id: String) -> Dictionary:
	return cards.get(id, {})

func get_unit(id: String) -> Dictionary:
	return units.get(id, {})

func get_level(id: String) -> Dictionary:
	return levels.get(id, {})

func get_arena(id: String = "default") -> Dictionary:
	return arena.get(id, {})

func get_run(id: String = "default") -> Dictionary:
	return run.get(id, {})

func get_campaign(id: String = "default") -> Dictionary:
	return campaign.get(id, {})

func get_tutorial(level_id: String) -> Dictionary:
	return tutorial.get(level_id, {})

func get_relic(id: String) -> Dictionary:
	return relics.get(id, {})

func get_audio_asset(id: String) -> Dictionary:
	return audio_assets.get(id, {})

func has_card(id: String) -> bool:
	return cards.has(id)

func has_unit(id: String) -> bool:
	return units.has(id)

func has_level(id: String) -> bool:
	return levels.has(id)

func has_audio_asset(id: String) -> bool:
	return audio_assets.has(id)

# —— V5 新表访问 ——
func get_stage(id: String) -> Dictionary:
	return stages.get(id, {})

func get_encounter(id: String) -> Dictionary:
	return encounters.get(id, {})

func get_economy() -> Dictionary:
	return economy

func get_card_progression(id: String) -> Dictionary:
	return card_progression.get(id, {})

func has_stage(id: String) -> bool:
	return stages.has(id)

func has_encounter(id: String) -> bool:
	return encounters.has(id)

func _is_number(value) -> bool:
	var t := typeof(value)
	return t == TYPE_INT or t == TYPE_FLOAT
