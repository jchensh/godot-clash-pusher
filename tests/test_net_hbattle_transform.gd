# H6 联机横版变换单测（KAN-115）：横版投影 × side2 逻辑 180° 翻转的复合。
# 核心不变量：**本方底线恒在屏幕左缘**（side1/side2 皆然）、部署分界线两视角同一屏幕 x、
# _t2s/_s2t 互逆、方向 API（_fp_screen/_screen_up_tiles）随版式+视角正确翻转。
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


func test_landscape_field_rect() -> void:
	var ns = _mk(true, false)
	# zone=1280×(720-54-176=490) → cell=floor(min(1280/32,490/18))=27 → 864×486 @ (208,56)
	var fr: Rect2 = ns._field_rect()
	assert_almost_eq(fr.position.x, 208.0, EPS, "横版场区左")
	assert_almost_eq(fr.position.y, 56.0, EPS, "横版场区顶")
	assert_almost_eq(fr.size.x, 864.0, EPS, "横版场区宽 32×27")
	assert_almost_eq(fr.size.y, 486.0, EPS, "横版场区高 18×27")
	ns.free()


func test_own_baseline_always_left() -> void:
	# side1（不翻转）：我底线=逻辑 y=32 → 屏幕左缘；敌底线 y=0 → 右缘。
	var s1 = _mk(true, false)
	assert_almost_eq(s1._t2s(Vector2(0, 32)).x, 208.0, EPS, "side1 我底线在左")
	assert_almost_eq(s1._t2s(Vector2(0, 0)).x, 1072.0, EPS, "side1 敌底线在右")
	s1.free()
	# side2（_flip）：本方塔在逻辑 y≈0 侧 → 翻转后仍应画在屏幕左缘。
	var s2 = _mk(true, true)
	assert_almost_eq(s2._t2s(Vector2(0, 0)).x, 208.0, EPS, "side2 我底线(逻辑y=0)在左")
	assert_almost_eq(s2._t2s(Vector2(0, 32)).x, 1072.0, EPS, "side2 敌底线(逻辑y=32)在右")
	s2.free()


func test_roundtrip_both_views() -> void:
	for flip in [false, true]:
		var ns = _mk(true, flip)
		for p in [Vector2(0, 0), Vector2(17.5, 31.5), Vector2(3.25, 15.0), Vector2(9, 16)]:
			var back: Vector2 = ns._s2t(ns._t2s(p))
			assert_almost_eq(back.x, p.x, EPS, "横版往返 x flip=%s @%s" % [flip, str(p)])
			assert_almost_eq(back.y, p.y, EPS, "横版往返 y flip=%s @%s" % [flip, str(p)])
		ns.free()


func test_deploy_boundary_same_screen_x_both_views() -> void:
	# 部署分界线：side1 用 deploy_player_y_min、side2 用对称值——两视角应落在同一屏幕 x
	# （本方半场恒为左段 [场区左缘, 分界线]）。
	var s1 = _mk(true, false)
	var a = s1._client.match_obj.battle.arena
	var x1: float = s1._t2s(Vector2(0, s1._deploy_y_min(a))).x
	s1.free()
	var s2 = _mk(true, true)
	var a2 = s2._client.match_obj.battle.arena
	var x2: float = s2._t2s(Vector2(0, s2._deploy_y_min(a2))).x
	s2.free()
	assert_almost_eq(x1, x2, EPS, "部署分界线两视角同一屏幕 x")
	assert_true(x1 > 208.0 and x1 < 1072.0, "分界线在场区内")


func test_direction_apis() -> void:
	var s1 = _mk(true, false)
	var fp: Vector2 = s1._fp_screen(3.0, 4.0)
	assert_almost_eq(fp.x, 108.0, EPS, "横版 footprint 屏幕宽 = fh*27")
	assert_almost_eq(fp.y, 81.0, EPS, "横版 footprint 屏幕高 = fw*27")
	assert_eq(s1._screen_up_tiles(2.0), Vector2(-2.0, 0.0), "side1 横版屏幕向上=逻辑 -x")
	var tp: Vector2 = s1._tile_px()
	assert_almost_eq(tp.x, 27.0, EPS, "横版格宽 27")
	assert_almost_eq(tp.y, 27.0, EPS, "横版格高 27")
	s1.free()
	var s2 = _mk(true, true)
	assert_eq(s2._screen_up_tiles(2.0), Vector2(2.0, 0.0), "side2 横版屏幕向上=逻辑 +x（翻转）")
	s2.free()


func test_portrait_regression_untouched() -> void:
	# 竖版基准零回归：side1 竖版在 1280×720 视口下按原公式（本用例只锁公式分支不受横版影响）。
	var ns = _mk(false, false)
	var fr: Rect2 = ns._field_rect()
	# zone=1280×490 → ts=floor(min(1280/18,490/32))=15 → 270×480
	assert_almost_eq(fr.size.x, 270.0, EPS, "竖版公式不受横版分支影响（宽）")
	assert_almost_eq(fr.size.y, 480.0, EPS, "竖版公式不受横版分支影响（高）")
	var back: Vector2 = ns._s2t(ns._t2s(Vector2(9, 16)))
	assert_almost_eq(back.x, 9.0, EPS, "竖版往返 x")
	assert_almost_eq(back.y, 16.0, EPS, "竖版往返 y")
	ns.free()
