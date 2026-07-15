# Events 事件总线单测（框架地基#2，KAN-100）。
#
# 覆盖：信号契约 / EconomyStateCache 变更广播（seed 与 _apply 两条落地路径，offline 树
# 手动挂 Events 节点即可收）/ 无总线安全（offline 单测树、极早期启动不炸）/ logic 层
# 封禁扫描（lockstep 确定性边界：逻辑层禁用总线）。
# 订阅端行为（页面自动刷新）需活树+渲染 → 真人验收（KAN-100 用例）。
extends "res://tests/test_case.gd"

const EventsScript = preload("res://view/events.gd")
const CacheScript = preload("res://net/economy_state_cache.gd")
const PlayerDataScript = preload("res://logic/player_data.gd")

func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root

# 取真 autoload（--script 模式下 autoload 其实已挂 root——对齐 test_ui_layers._ui 的 get-or-create；
# ⚠️ 别 add_child 同名节点：会被引擎自动改名，发射端查到真 autoload、订阅却连在孤儿上）。
func _bus() -> Node:
	var ev = _root().get_node_or_null("Events")
	if ev == null:
		ev = EventsScript.new()
		ev.name = "Events"
		_root().add_child(ev)
	return ev

func test_signal_contract() -> void:
	var ev = EventsScript.new()
	assert_true(ev.has_signal("economy_changed"), "economy_changed 信号存在")
	ev.free()

func test_seed_from_local_emits() -> void:
	var ev := _bus()
	var got: Array = []
	var cb := func(c) -> void: got.append(c)
	ev.economy_changed.connect(cb)
	var cache = CacheScript.new()
	var pd = PlayerDataScript.new()
	cache.seed_from_local(pd)
	ev.economy_changed.disconnect(cb)
	assert_eq(got.size(), 1, "seed_from_local 广播一次")
	assert_true(not got.is_empty() and got[0] == pd, "载荷 = 缓存 PlayerData")

func test_apply_emits_with_snapshot() -> void:
	# _apply 是 refresh/领挂机/升级/升阶/解锁/通关发奖/GM 共用的快照落地点（广播主路径）。
	var ev := _bus()
	var got: Array = []
	var cb := func(c) -> void: got.append(c)
	ev.economy_changed.connect(cb)
	var cache = CacheScript.new()
	cache._apply({
		"gold": 500, "gems": 7, "idle_last_collect_ts": 1234567890,
		"highest_cleared": "stage_1_1",
		"cards": {"knight": {"level": 3, "rank": 2, "shards": 5, "unlocked": true}},
		"stages": {"stage_1_1": {"stars": 3, "cleared": true}},
	}, ["knight"])
	ev.economy_changed.disconnect(cb)
	assert_eq(got.size(), 1, "_apply 广播一次")
	assert_true(not got.is_empty() and int(got[0].gold) == 500, "载荷是已应用的新快照")
	assert_true(cache.is_loaded, "is_loaded 置位（原语义不变）")

func test_safe_without_bus() -> void:
	# 无 Events 可寻（极早期启动/异常环境）→ 变更安静跳过、不崩。autoload 在测试树也存在，
	# 临时改名把它「藏起来」模拟缺席，测完还原。
	var ev = _root().get_node_or_null("Events")
	if ev != null:
		ev.name = "EventsHiddenForTest"
	var cache = CacheScript.new()
	cache.seed_from_local(PlayerDataScript.new())
	if ev != null:
		ev.name = "Events"
	assert_not_null(cache.get_cache(), "无总线时缓存照常工作")

func test_logic_layer_never_uses_bus() -> void:
	# 边界铁律（KAN-100）：logic/ 战斗逻辑层禁用事件总线——lockstep 确定性要求调用顺序严格固定。
	var re := RegEx.new()
	re.compile("\\bEvents\\.")
	var offenders: Array = []
	_scan("res://logic", re, offenders)
	assert_eq(offenders.size(), 0, "logic/ 禁用事件总线，违规: %s" % str(offenders))

func _scan(dir_path: String, re: RegEx, offenders: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."):
				_scan(p, re, offenders)
		elif f.ends_with(".gd"):
			if re.search(FileAccess.get_file_as_string(p)) != null:
				offenders.append(p)
		f = d.get_next()
