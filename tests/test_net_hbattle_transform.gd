# H6 联机横版变换单测（KAN-115；决策 49 起改为相对断言版）。
# 核心不变量：**本方底线恒在屏幕左缘**（side1/side2 皆然）、部署分界线两视角同一屏幕 x、
# _t2s/_s2t 互逆、方向 API（_fp_screen/_screen_up_tiles）随版式+视角正确翻转。
# 决策 49 期间盘面/视口连续变更 → 期望值一律从 _field_rect() 与 grid 推导，不硬编码像素。
# net_battle_scene 用 new() 裸实例 + StubClient 注入 match（不进树零副作用），用毕 free。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const NetSceneScript = preload("res://view/net_battle_scene.gd")

const EPS := 0.001


class StubClient:
	var match_obj


func _mk(landscape: bool, flip: bool):
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var m = MatchScript.new(loader)
	m.setup("level_01", [])
	var ns = NetSceneScript.new()
	var c := StubClient.new()
	c.match_obj = m
	ns._client = c
	ns._vw = 1280.0
	ns._vh = 720.0
	ns._landscape = landscape
	ns._flip = flip
	return ns


func _arena(ns):
	return ns._client.match_obj.battle.arena


func test_landscape_field_rect() -> void:
	var ns = _mk(true, false)
	var a = _arena(ns)
	var fr: Rect2 = ns._field_rect()
	assert_true(fr.size.x > 0.0 and fr.size.y > 0.0, "横版场区非空")
	assert_true(fr.position.x >= -EPS and fr.end.x <= ns._vw + EPS, "横版场区横向在视口内")
	assert_almost_eq(fr.size.x / float(a.grid_h), fr.size.y / float(a.grid_w), EPS,
			"横版 tile 方形（旋转不变密度）")
	ns.free()


func test_own_baseline_always_left() -> void:
	# side1（不翻转）：我底线=逻辑 y=grid_h → 屏幕左缘；敌底线 y=0 → 右缘。
	var s1 = _mk(true, false)
	var gh := float(_arena(s1).grid_h)
	var fr1: Rect2 = s1._field_rect()
	assert_almost_eq(s1._t2s(Vector2(0, gh)).x, fr1.position.x, EPS, "side1 我底线在左")
	assert_almost_eq(s1._t2s(Vector2(0, 0)).x, fr1.end.x, EPS, "side1 敌底线在右")
	s1.free()
	# side2（_flip）：本方塔在逻辑 y≈0 侧 → 翻转后仍应画在屏幕左缘。
	var s2 = _mk(true, true)
	var fr2: Rect2 = s2._field_rect()
	assert_almost_eq(s2._t2s(Vector2(0, 0)).x, fr2.position.x, EPS, "side2 我底线(逻辑y=0)在左")
	assert_almost_eq(s2._t2s(Vector2(0, gh)).x, fr2.end.x, EPS, "side2 敌底线(逻辑y=grid_h)在右")
	s2.free()


func test_roundtrip_both_views() -> void:
	for flip in [false, true]:
		var ns = _mk(true, flip)
		var a = _arena(ns)
		var pts := [Vector2(0, 0), Vector2(a.grid_w - 0.5, a.grid_h - 0.5),
				Vector2(3.25, 15.0), Vector2(a.grid_w / 2.0, a.grid_h / 2.0)]
		for p in pts:
			var back: Vector2 = ns._s2t(ns._t2s(p))
			assert_almost_eq(back.x, p.x, EPS, "横版往返 x flip=%s @%s" % [flip, str(p)])
			assert_almost_eq(back.y, p.y, EPS, "横版往返 y flip=%s @%s" % [flip, str(p)])
		ns.free()


func test_deploy_boundary_same_screen_x_both_views() -> void:
	# 部署分界线：side1 用 deploy_player_y_min、side2 用对称值——两视角应落在同一屏幕 x
	# （本方半场恒为左段 [场区左缘, 分界线]）。
	var s1 = _mk(true, false)
	var a = _arena(s1)
	var fr: Rect2 = s1._field_rect()
	var x1: float = s1._t2s(Vector2(0, s1._deploy_y_min(a))).x
	s1.free()
	var s2 = _mk(true, true)
	var a2 = _arena(s2)
	var x2: float = s2._t2s(Vector2(0, s2._deploy_y_min(a2))).x
	s2.free()
	assert_almost_eq(x1, x2, EPS, "部署分界线两视角同一屏幕 x")
	assert_true(x1 > fr.position.x and x1 < fr.end.x, "分界线在场区内")


func test_direction_apis() -> void:
	var s1 = _mk(true, false)
	var tp: Vector2 = s1._tile_px()
	assert_almost_eq(tp.x, tp.y, EPS, "横版 tile 方形")
	var fp: Vector2 = s1._fp_screen(3.0, 4.0)
	assert_almost_eq(fp.x, 4.0 * tp.x, EPS, "横版 footprint 屏幕宽 = fh*格")
	assert_almost_eq(fp.y, 3.0 * tp.y, EPS, "横版 footprint 屏幕高 = fw*格")
	assert_eq(s1._screen_up_tiles(2.0), Vector2(-2.0, 0.0), "side1 横版屏幕向上=逻辑 -x")
	s1.free()
	var s2 = _mk(true, true)
	assert_eq(s2._screen_up_tiles(2.0), Vector2(2.0, 0.0), "side2 横版屏幕向上=逻辑 +x（翻转）")
	s2.free()


func test_portrait_regression_untouched() -> void:
	# 竖版分支自洽零回归：场区非空 + tile 方形 + 往返互逆（公式分支不受横版影响）。
	var ns = _mk(false, false)
	var a = _arena(ns)
	var fr: Rect2 = ns._field_rect()
	assert_true(fr.size.x > 0.0 and fr.size.y > 0.0, "竖版场区非空")
	assert_almost_eq(fr.size.x / float(a.grid_w), fr.size.y / float(a.grid_h), EPS,
			"竖版 tile 方形")
	var c := Vector2(a.grid_w / 2.0, a.grid_h / 2.0)
	var back: Vector2 = ns._s2t(ns._t2s(c))
	assert_almost_eq(back.x, c.x, EPS, "竖版往返 x")
	assert_almost_eq(back.y, c.y, EPS, "竖版往返 y")
	ns.free()
