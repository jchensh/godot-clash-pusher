# V3-4a 测试：RunMap —— Roguelite 节点地图（线性连战链）。
# 验证 acts 结构正确展开成扁平节点链、节点带 type/act 标签、越界返回空。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const RunMapScript = preload("res://logic/run_map.gd")

func _make_map():
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var m = RunMapScript.new()
	m.build(loader.get_run("default"))
	return m

func test_build_flattens_acts_into_linear_chain() -> void:
	var m = _make_map()
	# 3 act × 3 战 = 9 节点（V3-4a 决策）。
	assert_eq(m.size(), 9, "默认 run = 3 act × 3 战 = 9 节点")

func test_nodes_carry_type_and_act() -> void:
	var m = _make_map()
	var first = m.node_at(0)
	assert_eq(String(first.get("type")), "battle", "首节点 type=battle")
	assert_eq(String(first.get("level_id")), "level_02", "首节点引用 level_02")
	assert_eq(int(first.get("act")), 0, "首节点属 act 0")
	# 每 act 末节点（下标 2/5/8）为 boss（V3-4d 差异化的种子标签）。
	for idx in [2, 5, 8]:
		assert_eq(String(m.node_at(idx).get("type")), "boss", "节点 %d 为 act 末 boss" % idx)
	# act 标签随展开递增：节点 0-2 → act0，3-5 → act1，6-8 → act2。
	assert_eq(int(m.node_at(3).get("act")), 1, "节点 3 属 act 1")
	assert_eq(int(m.node_at(8).get("act")), 2, "节点 8 属 act 2")

func test_node_at_out_of_range_returns_empty() -> void:
	var m = _make_map()
	assert_true(m.node_at(-1).is_empty(), "负下标返回空")
	assert_true(m.node_at(9).is_empty(), "越界下标返回空")

func test_all_node_levels_exist() -> void:
	# 节点 level_id 必须都是真实关卡（与 ConfigLoader 交叉校验一致）。
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var m = RunMapScript.new()
	m.build(loader.get_run("default"))
	for i in m.size():
		assert_true(loader.has_level(String(m.node_at(i).get("level_id"))), "节点 %d 的 level 存在" % i)
