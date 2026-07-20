# K0/K2（DESIGN_KINGDOM）：王国配置校验 + pb 编解码回环 + 客户端快照转换。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const KingdomProto = preload("res://net/proto/kingdom.gd")
const KingdomClient = preload("res://net/kingdom_client.gd")

func _config():
	var c = ConfigLoaderScript.new()
	c.load_all()
	return c

# 真配置全量装载干净（kingdom.json 已并入 ConfigLoader 必载清单）。
func test_config_loads_clean_with_kingdom() -> void:
	var c = _config()
	assert_true(c.errors.is_empty(), "全配置（含 kingdom.json）校验无误: %s" % str(c.errors))
	assert_false(c.kingdom.is_empty(), "kingdom 配置非空")

# P0 七建筑齐 + 等级表连续 + 王城 10 级绑章节。
func test_kingdom_buildings_complete() -> void:
	var c = _config()
	var bs: Dictionary = c.kingdom.get("buildings", {})
	for name in ["keep", "farm", "workshop", "granary", "wall", "watchtower", "mint"]:
		assert_true(bs.has(name), "建筑 %s 存在" % name)
	var keep_levels: Array = (bs["keep"] as Dictionary).get("levels", [])
	assert_eq(keep_levels.size(), 10, "王城 10 级")
	for i in keep_levels.size():
		assert_eq(int((keep_levels[i] as Dictionary).get("level", 0)), i + 1, "王城等级表连续 @%d" % i)
		assert_eq(int((keep_levels[i] as Dictionary).get("chapter_req", -1)), i, "王城 Lv%d 章节门=%d" % [i + 1, i])

# 商业化铁门（DESIGN_KINGDOM §4）：任何建筑成本禁用 gold——金币不能买城建资源。
func test_kingdom_no_gold_cost_gate() -> void:
	var c = _config()
	var bs: Dictionary = c.kingdom.get("buildings", {})
	for name in bs:
		for row in ((bs[name] as Dictionary).get("levels", []) as Array):
			assert_false(((row as Dictionary).get("cost", {}) as Dictionary).has("gold"),
					"建筑 %s 成本不含 gold" % name)
	# 校验器把关：注入 gold 成本必报错。
	var bad = ConfigLoaderScript.new()
	bad.load_all()
	(((bad.kingdom["buildings"] as Dictionary)["farm"] as Dictionary)["levels"] as Array)[0]["cost"] = {"gold": 100}
	bad.errors.clear()
	bad._validate_kingdom()
	assert_false(bad.errors.is_empty(), "gold 成本被校验器捕获")

# 城防曲线（对战维度，K4 接战斗）：城墙满级 +60% HP、箭楼满级 +40% 攻（示意值回归锁）。
func test_kingdom_defense_curve_totals() -> void:
	var c = _config()
	var bs: Dictionary = c.kingdom.get("buildings", {})
	var hp := 0
	for row in ((bs["wall"] as Dictionary).get("levels", []) as Array):
		hp += int((row as Dictionary).get("tower_hp_pct", 0))
	var dmg := 0
	for row in ((bs["watchtower"] as Dictionary).get("levels", []) as Array):
		dmg += int((row as Dictionary).get("tower_dmg_pct", 0))
	assert_eq(hp, 60, "城墙满级塔 HP +60%")
	assert_eq(dmg, 40, "箭楼满级塔攻 +40%")

# pb 编解码回环 + state_to_dict 形状（客户端只消费这个平面字典）。
func test_kingdom_pb_roundtrip_and_dict() -> void:
	var ks = KingdomProto.KingdomState.new()
	ks.set_server_now_ts(1700000000)
	ks.set_pending_gold(30)
	var r = ks.add_resources()
	r.set_resource("food")
	r.set_amount(200)
	var b = ks.add_buildings()
	b.set_building("farm")
	b.set_level(2)
	b.set_upgrade_end_ts(1700000600)
	var p = ks.add_pending()
	p.set_resource("food")
	p.set_amount(60)
	var back = KingdomProto.KingdomState.new()
	assert_eq(back.from_bytes(ks.to_bytes()), KingdomProto.PB_ERR.NO_ERRORS, "pb 回环解码成功")
	var d: Dictionary = KingdomClient.state_to_dict(back)
	assert_eq(int((d["resources"] as Dictionary).get("food", 0)), 200, "资源转换")
	assert_eq(int(((d["buildings"] as Dictionary)["farm"] as Dictionary).get("level", 0)), 2, "建筑等级转换")
	assert_eq(int(((d["buildings"] as Dictionary)["farm"] as Dictionary).get("upgrade_end_ts", 0)), 1700000600, "施工计时转换")
	assert_eq(int((d["pending"] as Dictionary).get("food", 0)), 60, "pending 转换")
	assert_eq(int(d["pending_gold"]), 30, "pending_gold 转换")
	assert_eq(int(d["server_now_ts"]), 1700000000, "服务器时间基准转换")
