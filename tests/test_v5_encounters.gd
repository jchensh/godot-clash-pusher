# V5-S8a：遭遇模板池铺量（3→15）+ ConfigLoader 校验加固。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")

const ARCHETYPES := ["balanced", "tank", "swarm", "undead", "control", "air", "ranged", "siege", "boss"]

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

# 全配置（含 15 模板）校验无误。
func test_config_loads_clean() -> void:
	var c = _config()
	assert_true(c.errors.is_empty(), "全配置校验无误: %s" % str(c.errors))

# 模板数 ≥15（铺量目标）。
func test_encounter_count_at_least_15() -> void:
	var c = _config()
	var n := 0
	for eid in c.encounters:
		if not String(eid).begins_with("_"):
			n += 1
	assert_true(n >= 15, "遭遇模板 ≥15（现 %d）" % n)

# 每模板 = 8 张互不重复的合法卡。
func test_every_encounter_8_distinct_valid_cards() -> void:
	var c = _config()
	for eid in c.encounters:
		if String(eid).begins_with("_"):
			continue
		var deck = c.encounters[eid].get("deck", [])
		assert_eq((deck as Array).size(), 8, "模板 %s deck=8 张" % eid)
		var seen := {}
		for cid in deck:
			assert_true(c.has_card(str(cid)), "模板 %s 的卡 %s 存在" % [eid, str(cid)])
			assert_false(seen.has(str(cid)), "模板 %s 卡 %s 不重复" % [eid, str(cid)])
			seen[str(cid)] = true

# 每模板 archetype 合法 + 关键原型全覆盖（多样性）。
func test_archetype_legal_and_full_coverage() -> void:
	var c = _config()
	var present := {}
	for eid in c.encounters:
		if String(eid).begins_with("_"):
			continue
		var a := str(c.encounters[eid].get("archetype", ""))
		assert_true(ARCHETYPES.has(a), "模板 %s 原型合法(%s)" % [eid, a])
		present[a] = true
	for need in ARCHETYPES:
		assert_true(present.has(need), "原型 %s 至少 1 个模板" % need)

# 加固校验生效：注入坏模板（重复卡 + 非法原型）→ _validate 捕获并报错。
func test_validation_catches_dup_and_bad_archetype() -> void:
	var c = _config()
	assert_true(c.errors.is_empty(), "前置：基线干净")
	c.encounters["zz_bad"] = {
		"archetype": "nope",
		"deck": ["knight", "knight", "archers", "goblins", "minions", "arrows", "zap", "giant"],
	}
	c._validate()
	var msg := str(c.errors)
	assert_true(msg.find("zz_bad") >= 0, "坏模板被校验捕获: %s" % msg)
	assert_true(msg.find("archetype") >= 0, "捕获非法 archetype")
	assert_true(msg.find("重复卡") >= 0, "捕获重复卡")
