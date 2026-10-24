## D5 联机对战页 3D 冒烟（真实场景树，不联网）：用桩客户端代替 BattleClient（本地 advance_tick 模拟服务端广播），
## side1/side2 各跑一遍：①进房建 3D 战场、镜头投影与引擎一致 ②手牌按钮同一入口拖卡 → 只发 send_deploy，
##   落点在本方半场、广播回来后本方单位出现在落点；松在手牌栏/敌方半场不发 ③重连再进房：换绑新局、节点数恒
##   = 存活单位、手牌按钮不叠 ④服务端结算信号 → 结算按钮入弹窗层。
## 页面子类化屏蔽 _connect_flow（不登录/不匹配；子类运行时编译——加载期 autoload 全局名尚未注册）；
## Online 换成就绪桩（只供配置/昵称）。
## 用法：godot --headless --path . --script res://tools/check_net_battle_3d.gd
extends SceneTree

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const FieldProjection := preload("res://view/three_d/field_projection.gd")
const NET_SCENE := "res://view/net_battle_scene.gd"
const DECK1 := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]
const DECK2 := ["knight", "goblins", "minions", "archers", "giant", "zap", "fireball", "arrows"]

var _loader = Loader.new()
var _failures: Array[String] = []
var _finished := 0
var _no_net_scene: GDScript


class OnlineStub extends Node:
	var loader

	func is_online_ready() -> bool:
		return true

	func config():
		return loader

	func nickname() -> String:
		return "测试员"

	func avatar_card_id() -> String:
		return "knight"


class StubClient:
	signal deploy_applied(side: int, card_id: String, pos: Vector2)
	var match_obj
	var your_side := 1
	var sent: Array = []        # 本端发出的 DeployCmd（毫 tile 量化）
	var log: Array = []         # 每 tick 广播的指令（重连追帧用）

	func local_player():
		return match_obj.player if your_side == 1 else match_obj.opponent

	func send_deploy(card_id: String, pos: Vector2) -> void:
		sent.append({"side": your_side, "card_id": card_id,
			"pos": Vector2(round(pos.x * 1000.0) / 1000.0, round(pos.y * 1000.0) / 1000.0)})

	func poll(_delta: float = 0.0) -> void:
		pass

	func cancel_match() -> void:
		pass

	## 模拟服务端：把待发指令随下一 tick 广播回来，两端同 tick 落子。
	func step_tick() -> void:
		var deploys := sent.duplicate(true)
		sent.clear()
		log.append(deploys)
		match_obj.advance_tick(deploys)
		for d in deploys:
			deploy_applied.emit(d["side"], d["card_id"], d["pos"])


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	_loader.load_all()
	var online := root.get_node_or_null("Online")
	if online != null:
		root.remove_child(online)
		online.free()
	var stub := OnlineStub.new()
	stub.name = "Online"
	stub.loader = _loader
	root.add_child(stub)
	_no_net_scene = GDScript.new()
	_no_net_scene.source_code = "\n".join(["extends \"%s\"" % NET_SCENE, "", "func _connect_flow() -> void:", "\tpass", ""])
	if _no_net_scene.reload() != OK:
		_failures.append("测试子类编译失败")
	else:
		for side in [1, 2]:
			await _check_side(side)
	if _finished != 2:
		_failures.append("只有 %d/2 个视角跑完（中途脚本错误）" % _finished)
	for failure in _failures:
		push_error(failure)
	print("NET_BATTLE_3D: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)


func _new_match():
	var m = MatchScript.new(_loader)
	m.setup("ladder_01", DECK1, [], DECK2)
	return m


func _check_side(side: int) -> void:
	var ns: Node2D = _no_net_scene.new()
	root.add_child(ns)
	current_scene = ns
	await process_frame
	var c := StubClient.new()
	c.match_obj = _new_match()
	c.your_side = side
	c.deploy_applied.connect(ns._on_deploy_applied)
	ns._client = c
	ns._on_joined(side, "对手", "knight")
	var field = ns._field3d
	if field == null or not field.camera.current:
		_failures.append("side%d 进房未建 3D 战场或镜头未生效" % side)
		return
	_check_projection(ns, field, side)
	_ticks(ns, c, 80)   # 攒圣水
	var me := side - 1
	var own := Vector2(10.5, 24.5) if side == 1 else Vector2(15.5, 5.5)
	var foe := Vector2(10.5, 5.5) if side == 1 else Vector2(15.5, 24.5)
	var index := _spawn_card(ns)
	if index < 0:
		_failures.append("side%d 没有可出的兵牌" % side)
	else:
		for screen in [Vector2(375.0, 1300.0), _finger(field, foe)]:
			ns._on_card_down(index)
			ns._process(0.016)
			if not field.deploy.dragging:
				_failures.append("side%d 按下手牌未开始 3D 拖拽" % side)
			ns._release_card(index, screen)
			if not c.sent.is_empty():
				_failures.append("side%d 松在 %s 不应发指令" % [side, screen])
				c.sent.clear()
		ns._on_card_down(index)
		ns._process(0.016)
		ns._release_card(index, _finger(field, own))
		if c.sent.size() != 1 or (c.sent[0]["pos"] as Vector2).distance_to(own) > 0.01:
			_failures.append("side%d 拖卡应只发一条落点≈%s 的指令：%s" % [side, own, c.sent])
		var before := _count_near(c.match_obj, me, own)
		_ticks(ns, c, 3)
		if _count_near(c.match_obj, me, own) <= before:
			_failures.append("side%d 指令广播落子后落点附近没有本方新单位" % side)
		elif field.presenter.actor_for(_nearest(c.match_obj, me, own)) == null:
			_failures.append("side%d 新单位没有 3D 节点" % side)
	_ticks(ns, c, 300)
	_check_counts(ns, c, side, "断线前")
	# 重连：新建 Match 从头追帧到断线处，再进房。
	var log: Array = c.log.duplicate(true)
	var fresh = _new_match()
	for deploys in log:
		fresh.advance_tick(deploys.duplicate(true))
	c.match_obj = fresh
	var top_children: int = field.get_child_count()
	ns._on_joined(side, "对手", "knight")
	await process_frame   # 旧手牌按钮 queue_free 生效
	if ns._field3d != field or field.get_child_count() != top_children:
		_failures.append("side%d 重连应复用同一 3D 层且不重复建镜头/光照" % side)
	if ns._card_btns.size() != 4:
		_failures.append("side%d 重连后手牌按钮数 %d" % [side, ns._card_btns.size()])
	ns._process(0.016)
	_check_counts(ns, c, side, "重连后")
	_ticks(ns, c, 200)
	_check_counts(ns, c, side, "重连后续打")
	# 服务端结算信号 → 演出 → 结算按钮入弹窗层。
	ns._on_result(side, 0)
	for i in 12:
		ns._process(0.1)
	var buttons := 0
	for child in ns._end_result_layer.get_children():
		if child is Button:
			buttons += 1
	if not ns._end_result_layer.is_inside_tree() or buttons != 2:
		_failures.append("side%d 结算层未入弹窗层或按钮数 %d" % [side, buttons])
	print("NET_BATTLE_3D: side%d tick=%d 追帧=%d 单位节点=%d 结算按钮=%d" % [side, c.match_obj.net_tick, log.size(),
		field.presenter.unit_actor_count(), buttons])
	root.remove_child(ns)
	ns.free()
	_finished += 1
	await process_frame


func _ticks(ns, c, n: int) -> void:
	for i in n:
		c.step_tick()
		ns._process(0.1)


func _check_counts(ns, c, side: int, label: String) -> void:
	var alive := 0
	for u in c.match_obj.battle.arena.get_units():
		if u.is_alive():
			alive += 1
	if ns._field3d.presenter.unit_actor_count() != alive:
		_failures.append("side%d %s 节点数 %d ≠ 存活单位 %d" % [side, label, ns._field3d.presenter.unit_actor_count(), alive])


func _check_projection(ns, field, side: int) -> void:
	var grid: Vector2 = field.deploy.grid
	for tile in [Vector2.ZERO, grid, Vector2(3.5, 20.0), Vector2(20.0, 4.0)]:
		var engine: Vector2 = field.camera.unproject_position(FieldProjection.tile_to_world(tile, grid, side == 2))
		if ns._t2s(tile).distance_to(engine) > 0.5:
			_failures.append("side%d 投影不一致 tile=%s ours=%s engine=%s" % [side, tile, ns._t2s(tile), engine])


func _finger(field, tile: Vector2) -> Vector2:
	return field.tile_to_screen(tile) + Vector2(0.0, field.deploy.lift_pixels())


func _spawn_card(ns) -> int:
	var lp = ns._client.local_player()
	var hand: Array = lp.deck.get_hand()
	for i in hand.size():
		if hand[i] != null and lp.can_play(i) and ns._card_info(str(hand[i]))["spawn"]:
			return i
	return -1


func _count_near(m, owner: int, tile: Vector2) -> int:
	var n := 0
	for unit in m.battle.arena.get_units():
		if unit.owner_id == owner and unit.is_alive() and unit.pos.distance_to(tile) < 1.5:
			n += 1
	return n


func _nearest(m, owner: int, tile: Vector2):
	for unit in m.battle.arena.get_units():
		if unit.owner_id == owner and unit.is_alive() and unit.pos.distance_to(tile) < 1.5:
			return unit
	return null
