# 横版战斗变换层单测（PLAN_V5_HBATTLE H1+H2；决策 49 起改为相对断言版）。
#
# 决策 49 卡通改版期间盘面（26×30）与壳（viewport 750×1334 / 场区公式）连续变更，
# 故本文件锁的是**对任意盘面/视口都必须成立的方向语义与几何自洽性**：
# 1. 竖版语义——敌上我下、原点/对角/中心映射到场区角与中心、tile 方形、fp/方向 API 恒等；
# 2. 横版投影方向——敌右我左（逻辑 y=0 → 场区右缘）、逻辑 x → 屏幕纵向、fp 转置；
# 3. _t2s/_s2t 互逆 + _tile_rect 对齐 + 部署区矩形贴场区边。
# 期望值一律从 _field_rect() 与 arena.grid_w/grid_h 推导，不硬编码像素；
# P1-4 场区定稿（750×650@25px）后如需防回归可另补具体基准锁定用例。
# battle_scene 用 new() 裸实例（不进树：_ready/@onready 不触发，无音频/网络副作用），用毕 free。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const MatchScript = preload("res://logic/match.gd")
const BattleSceneScript = preload("res://view/battle_scene.gd")

const EPS := 0.001

func _mk(landscape: bool):
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	var m = MatchScript.new(loader)
	m.setup("level_01", [])
	var bs = BattleSceneScript.new()
	bs.match_obj = m
	bs._vw = 720.0
	bs._vh = 1280.0
	bs._landscape = landscape
	return bs

func _arena(bs):
	return bs.match_obj.battle.arena

# 决策 49 盘面基准：26×30（变更时此测试提醒重校本文件语义假设）。
func _assert_grid(bs) -> void:
	var a = _arena(bs)
	assert_eq(int(a.grid_w), 26, "基准依赖 grid_w=26")
	assert_eq(int(a.grid_h), 30, "基准依赖 grid_h=30")

func test_portrait_semantics() -> void:
	var bs = _mk(false)
	_assert_grid(bs)
	var a = _arena(bs)
	var gw := float(a.grid_w)
	var gh := float(a.grid_h)
	var fr: Rect2 = bs._field_rect()
	assert_true(fr.size.x > 0.0 and fr.size.y > 0.0, "竖版场区非空")
	assert_true(fr.position.x >= 0.0 and fr.end.x <= bs._vw + EPS, "竖版场区横向在视口内")
	# tile 方形：宽高同缩放
	var tp: Vector2 = bs._tile_px()
	assert_almost_eq(tp.x, fr.size.x / gw, EPS, "竖版格宽 = 场宽/grid_w")
	assert_almost_eq(tp.y, fr.size.y / gh, EPS, "竖版格高 = 场高/grid_h")
	assert_almost_eq(tp.x, tp.y, EPS, "竖版 tile 方形")
	assert_almost_eq(bs._ur(), tp.x, EPS, "竖版参考半径=格边")
	# 原点（敌方左上）/对角/中心映射
	var o: Vector2 = bs._t2s(Vector2(0, 0))
	assert_almost_eq(o.x, fr.position.x, EPS, "竖版原点 x=场区左（敌方在屏上）")
	assert_almost_eq(o.y, fr.position.y, EPS, "竖版原点 y=场区顶")
	var d: Vector2 = bs._t2s(Vector2(gw, gh))
	assert_almost_eq(d.x, fr.end.x, EPS, "竖版对角 x=场区右")
	assert_almost_eq(d.y, fr.end.y, EPS, "竖版对角 y=场区底")
	var c: Vector2 = bs._t2s(Vector2(gw / 2.0, gh / 2.0))
	assert_almost_eq(c.x, fr.get_center().x, EPS, "竖版中心映中心 x")
	assert_almost_eq(c.y, fr.get_center().y, EPS, "竖版中心映中心 y")
	# footprint / 屏幕向上：竖版恒等语义
	var fp: Vector2 = bs._fp_screen(4.0, 4.0)
	assert_almost_eq(fp.x, 4.0 * tp.x, EPS, "竖版王塔 footprint 宽")
	assert_almost_eq(fp.y, 4.0 * tp.y, EPS, "竖版王塔 footprint 高")
	assert_eq(bs._screen_up_tiles(2.0), Vector2(0.0, -2.0), "竖版屏幕向上=逻辑-y")
	# tile 矩形左上角 = _t2s(tx,ty)
	var r: Rect2 = bs._tile_rect(3, 5)
	assert_almost_eq(r.position.x, bs._t2s(Vector2(3, 5)).x, EPS, "竖版 tile 角 x")
	assert_almost_eq(r.position.y, bs._t2s(Vector2(3, 5)).y, EPS, "竖版 tile 角 y")
	bs.free()

func test_portrait_roundtrip() -> void:
	var bs = _mk(false)
	var a = _arena(bs)
	var pts := [Vector2(0, 0), Vector2(a.grid_w - 0.5, a.grid_h - 0.5),
			Vector2(3.25, 15.0), Vector2(a.grid_w / 2.0, a.grid_h / 2.0)]
	for p in pts:
		var back: Vector2 = bs._s2t(bs._t2s(p))
		assert_almost_eq(back.x, p.x, EPS, "竖版往返 x @%s" % str(p))
		assert_almost_eq(back.y, p.y, EPS, "竖版往返 y @%s" % str(p))
	bs.free()

func test_landscape_field_rect_valid() -> void:
	var bs = _mk(true)
	_assert_grid(bs)
	var a = _arena(bs)
	var fr: Rect2 = bs._field_rect()
	assert_true(fr.size.x > 0.0 and fr.size.y > 0.0, "横版场区非空")
	assert_true(fr.position.x >= -EPS and fr.end.x <= bs._vw + EPS, "横版场区横向在视口内")
	# 横版：屏幕横向 = 逻辑纵深 grid_h、屏幕纵向 = 逻辑宽 grid_w，tile 方形
	assert_almost_eq(fr.size.x / float(a.grid_h), fr.size.y / float(a.grid_w), EPS,
			"横版 tile 方形（旋转不变密度）")
	bs.free()

func test_landscape_projection_direction() -> void:
	var bs = _mk(true)
	var a = _arena(bs)
	var gw := float(a.grid_w)
	var gh := float(a.grid_h)
	var fr: Rect2 = bs._field_rect()
	# 敌底线 y=0 → 场区右缘；我底线 y=grid_h → 左缘；逻辑 x=0 → 场区顶；x=grid_w → 底
	assert_almost_eq(bs._t2s(Vector2(0, 0)).x, fr.end.x, EPS, "敌底线在场区右缘")
	assert_almost_eq(bs._t2s(Vector2(0, gh)).x, fr.position.x, EPS, "我底线在场区左缘")
	assert_almost_eq(bs._t2s(Vector2(0, 0)).y, fr.position.y, EPS, "逻辑 x=0 在场区顶")
	assert_almost_eq(bs._t2s(Vector2(gw, 0)).y, fr.end.y, EPS, "逻辑 x=grid_w 在场区底")
	var c: Vector2 = bs._t2s(Vector2(gw / 2.0, gh / 2.0))
	assert_almost_eq(c.x, fr.get_center().x, EPS, "横版中心映中心 x")
	assert_almost_eq(c.y, fr.get_center().y, EPS, "横版中心映中心 y")
	bs.free()

func test_landscape_roundtrip() -> void:
	var bs = _mk(true)
	var a = _arena(bs)
	var pts := [Vector2(0, 0), Vector2(a.grid_w - 0.5, a.grid_h - 0.5),
			Vector2(3.25, 15.0), Vector2(a.grid_w / 2.0, a.grid_h / 2.0)]
	for p in pts:
		var back: Vector2 = bs._s2t(bs._t2s(p))
		assert_almost_eq(back.x, p.x, EPS, "横版往返 x @%s" % str(p))
		assert_almost_eq(back.y, p.y, EPS, "横版往返 y @%s" % str(p))
	bs.free()

func test_landscape_tile_square_and_rect() -> void:
	var bs = _mk(true)
	var a = _arena(bs)
	var fr: Rect2 = bs._field_rect()
	var tp: Vector2 = bs._tile_px()
	assert_almost_eq(tp.x, fr.size.x / float(a.grid_h), EPS, "横版格宽 = 场宽/grid_h")
	assert_almost_eq(tp.y, fr.size.y / float(a.grid_w), EPS, "横版格高 = 场高/grid_w")
	assert_almost_eq(tp.x, tp.y, EPS, "横版 tile 方形")
	# 我方底线角 tile(0, grid_h-1) 屏幕左上角 = 场区左上
	var r: Rect2 = bs._tile_rect(0, a.grid_h - 1)
	assert_almost_eq(r.position.x, fr.position.x, EPS, "横版角 tile x")
	assert_almost_eq(r.position.y, fr.position.y, EPS, "横版角 tile y")
	bs.free()

func test_landscape_direction_apis() -> void:
	var bs = _mk(true)
	var tp: Vector2 = bs._tile_px()
	# footprint：逻辑纵深(fh)→屏幕横向、逻辑宽(fw)→屏幕纵向
	var fp: Vector2 = bs._fp_screen(3.0, 4.0)
	assert_almost_eq(fp.x, 4.0 * tp.x, EPS, "横版 footprint 屏幕宽 = fh*格")
	assert_almost_eq(fp.y, 3.0 * tp.y, EPS, "横版 footprint 屏幕高 = fw*格")
	assert_eq(bs._screen_up_tiles(2.0), Vector2(-2.0, 0.0), "横版屏幕向上=逻辑-x")
	bs.free()

func test_deploy_zone_rect_both_layouts() -> void:
	var bs = _mk(false)
	var a = _arena(bs)
	var ymin := float(a.deploy_player_y_min)
	# 竖版：下段矩形，顶边 = 部署线投影 y、底边 = 场区底、全宽
	var frp: Rect2 = bs._field_rect()
	var pr: Rect2 = bs._deploy_zone_rect(a)
	assert_almost_eq(pr.position.y, bs._t2s(Vector2(0, ymin)).y, EPS, "竖版部署区顶边=部署线")
	assert_almost_eq(pr.end.y, frp.end.y, EPS, "竖版部署区到场区底")
	assert_almost_eq(pr.size.x, frp.size.x, EPS, "竖版部署区全宽（=场地宽）")
	bs.free()
	# 横版：左段矩形，左边 = 场区左缘、右边 = 部署线投影 x、全高
	var bl = _mk(true)
	var frl: Rect2 = bl._field_rect()
	var lr: Rect2 = bl._deploy_zone_rect(a)
	assert_almost_eq(lr.position.x, frl.position.x, EPS, "横版部署区从场区左缘起")
	assert_almost_eq(lr.end.x, bl._t2s(Vector2(0, ymin)).x, EPS, "横版部署区右边=部署线")
	assert_almost_eq(lr.size.y, frl.size.y, EPS, "横版部署区全高")
	bl.free()
