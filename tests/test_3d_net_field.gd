## D5：联机对战页的 3D 战场层——side1/side2 双视角方向与落点、两端各挂 3D 时 lockstep hash 不变、
## 断线重连（新建 Match + 追帧）换绑后节点不重复、不残留。net_battle_scene 用 new() 裸实例 + StubClient（不进树）。
extends "res://tests/test_case.gd"

const Loader := preload("res://logic/config_loader.gd")
const MatchScript := preload("res://logic/match.gd")
const NetSceneScript := preload("res://view/net_battle_scene.gd")
const BattleField3D := preload("res://view/three_d/battle_field_3d.gd")
const ArenaPresenter := preload("res://view/three_d/arena_presenter.gd")

const SCREEN := Vector2(750, 1334)
const TOP := 54.0                # 与 net_battle_scene TOPBAR_H / HUD_BOTTOM_H 同值
const HUD := 176.0
const DECK1 := ["knight", "archers", "giant", "goblins", "minions", "fireball", "arrows", "zap"]
const DECK2 := ["knight", "goblins", "minions", "archers", "giant", "zap", "fireball", "arrows"]

var _loader = null


class StubClient:
	var match_obj
	var your_side := 1

	func local_player():
		return match_obj.player if your_side == 1 else match_obj.opponent


func _config():
	if _loader == null:
		_loader = Loader.new()
		_loader.load_all()
	return _loader


func _new_match():
	var m = MatchScript.new(_config())
	m.setup("ladder_01", DECK1, [], DECK2)
	return m


func _scene(m, side: int):
	var ns = NetSceneScript.new()
	var c := StubClient.new()
	c.match_obj = m
	c.your_side = side
	ns._client = c
	ns._loader = _config()
	ns._vw = SCREEN.x
	ns._vh = SCREEN.y
	ns._landscape = true
	ns._flip = side == 2
	ns._bind_field_3d(side)
	return ns


func _dispose(ns) -> void:
	ns._field3d.presenter.clear()
	ns.free()


func _finger(field, tile: Vector2) -> Vector2:
	return field.tile_to_screen(tile) + Vector2(0.0, field.deploy.lift_pixels())


func _king(towers: Array):
	for t in towers:
		if t.is_king():
			return t
	return null


func test_both_views_direction_and_drop() -> void:
	for side in [1, 2]:
		var m = _new_match()
		var ns = _scene(m, side)
		var field = ns._field3d
		var me: int = side - 1
		var mine: Array = m.battle.player_towers if side == 1 else m.battle.opponent_towers
		var foe: Array = m.battle.opponent_towers if side == 1 else m.battle.player_towers
		assert_eq(field.deploy.owner_id, me, "side%d 落点合法性按本方 owner" % side)
		assert_eq(field.deploy.flipped, side == 2, "side2 整场翻转")
		var p := Vector2(9.3, 17.7)
		assert_true(ns._t2s(p).distance_to(field.tile_to_screen(p)) < 0.001, "side%d _t2s 走 3D 投影" % side)
		assert_true(ns._ur() > 10.0, "特效尺寸基准有效")
		# 本方王塔恒在左、敌方恒在右；本方塔蓝、敌方塔红。
		assert_true(ns._t2s(_king(mine).pos).x < SCREEN.x * 0.5, "side%d 本方王塔在左" % side)
		assert_true(ns._t2s(_king(foe).pos).x > SCREEN.x * 0.5, "side%d 敌方王塔在右" % side)
		assert_eq(field.presenter._team_color(me), ArenaPresenter.COLOR_BLUE, "side%d 本方蓝" % side)
		assert_eq(field.presenter._team_color(1 - me), ArenaPresenter.COLOR_RED, "side%d 敌方红" % side)
		# 「屏幕向上」偏移（塔身伤害数字/箭口）两视角都朝屏幕上方。
		assert_true(ns._t2s(p + ns._screen_up_tiles(2.0)).y < ns._t2s(p).y - 1.0, "side%d 屏幕向上仍朝上" % side)
		# 落点：本方半场合法、敌方半场非法；手指 → 落点往返回到目标格。
		var own_tile := Vector2(10.0, 25.0) if side == 1 else Vector2(16.0, 5.0)
		var foe_tile := Vector2(10.0, 5.0) if side == 1 else Vector2(16.0, 25.0)
		var drop: Variant = field.drop_tile(_finger(field, own_tile))
		assert_true(drop != null and (drop as Vector2).distance_to(own_tile) < 0.01, "side%d 落点往返" % side)
		assert_true(m.battle.arena.can_deploy(me, drop), "side%d 本方半场可部署" % side)
		var bad: Variant = field.drop_tile(_finger(field, foe_tile))
		assert_true(bad != null and not m.battle.arena.can_deploy(me, bad), "side%d 敌方半场不可部署" % side)
		var half: Rect2 = field.deploy_half_rect()
		assert_true(half.has_point(ns._t2s(_king(mine).pos)) and not half.has_point(ns._t2s(_king(foe).pos)),
			"side%d 本方半场框只罩本方" % side)
		_dispose(ns)


## 两端同一份指令流（双方都经各自翻转视角的 3D 拾取下兵，毫 tile 量化同 DeployCmd），
## 挂 3D 的两端与不挂 3D 的对照逐 tick hash 全等、胜负一致。
func test_lockstep_hash_neutral_both_views() -> void:
	var m1 = _new_match()
	var m2 = _new_match()
	var bare = _new_match()
	var ns1 = _scene(m1, 1)
	var ns2 = _scene(m2, 2)
	var targets1 := [Vector2(6.4, 24.8), Vector2(19.5, 22.1), Vector2(13.0, 27.0)]
	var targets2 := [Vector2(19.6, 5.2), Vector2(6.5, 7.9), Vector2(13.0, 3.0)]
	var sent := 0
	for t in 1500:
		var deploys: Array = []
		if t % 25 == 0:
			for side in [1, 2]:
				var ns = ns1 if side == 1 else ns2
				var lp = ns._client.local_player()
				var hand: Array = lp.deck.get_hand()
				if hand[0] == null or not lp.can_play(0):
					continue
				var tile: Vector2 = (targets1 if side == 1 else targets2)[(t / 25) % 3]
				var pos: Variant = ns._field3d.drop_tile(_finger(ns._field3d, tile))
				if pos == null:
					continue
				var q := Vector2(round(pos.x * 1000.0) / 1000.0, round(pos.y * 1000.0) / 1000.0)
				deploys.append({"side": side, "card_id": str(hand[0]), "pos": q})
				sent += 1
		for m in [m1, m2, bare]:
			m.advance_tick(deploys.duplicate(true))
		ns1._field3d.advance(0.1)
		ns2._field3d.advance(0.1)
		var h: String = bare.state_hash().hex_encode()
		if m1.state_hash().hex_encode() != h or m2.state_hash().hex_encode() != h:
			assert_true(false, "第 %d tick 挂 3D 两端与对照 hash 分叉" % t)
			break
		if bare.is_over():
			break
	assert_true(sent >= 6, "双方都应经 3D 拾取发出指令（实发 %d）" % sent)
	assert_eq(m1.get_result(), bare.get_result(), "胜负一致（side1 端）")
	assert_eq(m2.get_result(), bare.get_result(), "胜负一致（side2 端）")
	_dispose(ns1)
	_dispose(ns2)


## 重连：BattleClient 进房时新建 Match 并从头追帧 → 页面再次 _bind_field_3d；
## 换绑后节点数 = 新局存活单位，旧局节点全释放，镜头/光照/输入不重复建。
func test_reconnect_rebind_no_duplicates() -> void:
	var old_m = _new_match()
	var ns = _scene(old_m, 2)
	var field = ns._field3d
	var top_children: int = field.get_child_count()
	var log: Array = []
	for t in 400:
		var deploys: Array = []
		if t % 30 == 0:
			for side in [1, 2]:
				var p = old_m.player if side == 1 else old_m.opponent
				if p.deck.get_hand()[0] != null and p.can_play(0):
					var tile := Vector2(10.5, 24.5) if side == 1 else Vector2(15.5, 5.5)
					deploys.append({"side": side, "card_id": str(p.deck.get_hand()[0]), "pos": tile})
		log.append(deploys)
		old_m.advance_tick(deploys.duplicate(true))
		field.advance(0.1)
	assert_true(field.presenter.unit_actor_count() > 0, "断线前场上应有单位节点")
	var new_m = _new_match()
	for deploys in log:
		new_m.advance_tick(deploys.duplicate(true))   # 追帧到断线处
	ns._client.match_obj = new_m
	ns._bind_field_3d(2)
	assert_true(ns._field3d == field, "重连复用同一 3D 层")
	assert_eq(field.get_child_count(), top_children, "镜头/光照/输入不重复建")
	var alive := 0
	for u in new_m.battle.arena.get_units():
		if u.is_alive():
			alive += 1
	assert_eq(field.presenter.unit_actor_count(), alive, "换绑后单位节点 = 新局存活单位")
	assert_eq(field.presenter.dying_count(), 0, "旧局节点不转死亡残留")
	var towers: int = new_m.battle.player_towers.size() + new_m.battle.opponent_towers.size()
	var extras := 1 + (1 if field.presenter.get_node_or_null("BlobShadows") != null else 0)   # D8b 合批层（+ 低档圆影）
	assert_eq(field.presenter.get_child_count(), 1 + extras + towers + alive, "presenter 子节点 = 场地 + 合批层 + 塔 + 存活单位")
	for u in new_m.battle.arena.get_units():
		if u.is_alive():
			assert_true(field.presenter.actor_for(u) != null, "新局每个单位都有节点")
			break
	_dispose(ns)
