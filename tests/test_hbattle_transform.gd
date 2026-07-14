# 横版战斗变换层单测（PLAN_V5_HBATTLE H1+H2）。
#
# 覆盖三件事：
# 1. 竖版基准锁定——KAN-107（2026-07-13）起竖版 = 32×32 正方形屏幕格 letterbox 居中（576×1024 @720 基准），
#    用硬编码期望值钉死（取代 H1 时期的 720×1050 满铺基线）；
# 2. 横版投影方向语义——敌右我左（逻辑 y=0 → 屏幕右缘）、tile 方形、letterbox 居中、部署区=左段；
# 3. _t2s/_s2t 互逆 + 方向 API（_fp_screen/_screen_up_tiles/_tile_rect）随版式正确翻转。
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

# 基准值全按 18×32 盘面手算；若 arena 结构变更，此测试提醒重校基准。
func _assert_grid(bs) -> void:
	var a = bs.match_obj.battle.arena
	assert_eq(int(a.grid_w), 18, "基准依赖 grid_w=18")
	assert_eq(int(a.grid_h), 32, "基准依赖 grid_h=32")

func test_portrait_baseline_locked() -> void:
	var bs = _mk(false)
	_assert_grid(bs)
	# field_rect = (72, 67, 576, 1024)：格=floor(min(40,32.8))=32 → 场地 576×1024，zone 内居中
	var fr: Rect2 = bs._field_rect()
	assert_almost_eq(fr.position.x, 72.0, EPS, "竖版场区左（72px 装饰边栏）")
	assert_almost_eq(fr.position.y, 67.0, EPS, "竖版场区顶（26px 余量对半）")
	assert_almost_eq(fr.size.x, 576.0, EPS, "竖版场区宽")
	assert_almost_eq(fr.size.y, 1024.0, EPS, "竖版场区高")
	# 场中心 (9,16) → (360, 579)；原点/对角
	var c: Vector2 = bs._t2s(Vector2(9, 16))
	assert_almost_eq(c.x, 360.0, EPS, "竖版中心 x")
	assert_almost_eq(c.y, 579.0, EPS, "竖版中心 y")
	var o: Vector2 = bs._t2s(Vector2(0, 0))
	assert_almost_eq(o.x, 72.0, EPS, "竖版原点 x（边栏右侧）")
	assert_almost_eq(o.y, 67.0, EPS, "竖版原点 y（敌方在屏上）")
	# tile 尺寸 = (32, 32) 正方形；ur = 均值 = 32
	var tp: Vector2 = bs._tile_px()
	assert_almost_eq(tp.x, 32.0, EPS, "竖版格宽")
	assert_almost_eq(tp.y, 32.0, EPS, "竖版格高（正方形）")
	assert_almost_eq(bs._ur(), 32.0, EPS, "竖版参考半径")
	# footprint / 屏幕向上：竖版恒等语义
	var fp: Vector2 = bs._fp_screen(4.0, 4.0)
	assert_almost_eq(fp.x, 128.0, EPS, "竖版王塔 footprint 宽")
	assert_almost_eq(fp.y, 128.0, EPS, "竖版王塔 footprint 高")
	assert_eq(bs._screen_up_tiles(2.0), Vector2(0.0, -2.0), "竖版屏幕向上=逻辑-y")
	# tile 矩形左上角 = _t2s(tx,ty)
	var r: Rect2 = bs._tile_rect(3, 5)
	assert_almost_eq(r.position.x, bs._t2s(Vector2(3, 5)).x, EPS, "竖版 tile 角 x")
	assert_almost_eq(r.position.y, bs._t2s(Vector2(3, 5)).y, EPS, "竖版 tile 角 y")
	bs.free()

func test_portrait_roundtrip() -> void:
	var bs = _mk(false)
	for p in [Vector2(0, 0), Vector2(17.5, 31.5), Vector2(3.25, 15.0), Vector2(9, 16)]:
		var back: Vector2 = bs._s2t(bs._t2s(p))
		assert_almost_eq(back.x, p.x, EPS, "竖版往返 x @%s" % str(p))
		assert_almost_eq(back.y, p.y, EPS, "竖版往返 y @%s" % str(p))
	bs.free()

func test_landscape_field_rect_letterbox() -> void:
	var bs = _mk(true)
	_assert_grid(bs)
	# 场区 720×1050 内按 32:18 满宽 → 720×405，垂直居中 y=376.5
	var fr: Rect2 = bs._field_rect()
	assert_almost_eq(fr.position.x, 0.0, EPS, "横版场区左")
	assert_almost_eq(fr.position.y, 376.5, EPS, "横版场区顶（letterbox 居中）")
	assert_almost_eq(fr.size.x, 720.0, EPS, "横版场区宽")
	assert_almost_eq(fr.size.y, 405.0, EPS, "横版场区高")
	bs.free()

func test_landscape_projection_direction() -> void:
	var bs = _mk(true)
	# 敌底线 y=0 → 屏幕右缘；我底线 y=32 → 左缘；逻辑 x=0 → 屏幕顶；中心映中心
	assert_almost_eq(bs._t2s(Vector2(0, 0)).x, 720.0, EPS, "敌底线在屏幕右缘")
	assert_almost_eq(bs._t2s(Vector2(0, 32)).x, 0.0, EPS, "我底线在屏幕左缘")
	assert_almost_eq(bs._t2s(Vector2(0, 0)).y, 376.5, EPS, "逻辑 x=0 在场区顶")
	assert_almost_eq(bs._t2s(Vector2(18, 0)).y, 781.5, EPS, "逻辑 x=18 在场区底")
	var c: Vector2 = bs._t2s(Vector2(9, 16))
	assert_almost_eq(c.x, 360.0, EPS, "横版中心 x")
	assert_almost_eq(c.y, 579.0, EPS, "横版中心 y")
	bs.free()

func test_landscape_roundtrip() -> void:
	var bs = _mk(true)
	for p in [Vector2(0, 0), Vector2(17.5, 31.5), Vector2(3.25, 15.0), Vector2(9, 16)]:
		var back: Vector2 = bs._s2t(bs._t2s(p))
		assert_almost_eq(back.x, p.x, EPS, "横版往返 x @%s" % str(p))
		assert_almost_eq(back.y, p.y, EPS, "横版往返 y @%s" % str(p))
	bs.free()

func test_landscape_tile_square_and_rect() -> void:
	var bs = _mk(true)
	# 720/32 = 405/18 = 22.5：横版 tile 恒方形（旋转不变密度）
	var tp: Vector2 = bs._tile_px()
	assert_almost_eq(tp.x, 22.5, EPS, "横版格宽")
	assert_almost_eq(tp.y, 22.5, EPS, "横版格高")
	# tile(0,31)（我方底线角）屏幕左上角 = 场区左上 (0, 376.5)
	var r: Rect2 = bs._tile_rect(0, 31)
	assert_almost_eq(r.position.x, 0.0, EPS, "横版角 tile x")
	assert_almost_eq(r.position.y, 376.5, EPS, "横版角 tile y")
	bs.free()

func test_landscape_direction_apis() -> void:
	var bs = _mk(true)
	# footprint：逻辑纵深(fh)→屏幕横向、逻辑宽(fw)→屏幕纵向
	var fp: Vector2 = bs._fp_screen(3.0, 4.0)
	assert_almost_eq(fp.x, 90.0, EPS, "横版 footprint 屏幕宽 = fh*22.5")
	assert_almost_eq(fp.y, 67.5, EPS, "横版 footprint 屏幕高 = fw*22.5")
	assert_eq(bs._screen_up_tiles(2.0), Vector2(-2.0, 0.0), "横版屏幕向上=逻辑-x")
	bs.free()

func test_deploy_zone_rect_both_layouts() -> void:
	var bs = _mk(false)
	var a = bs.match_obj.battle.arena
	var ymin := float(a.deploy_player_y_min)
	# 竖版：下段矩形，顶边 = 部署线投影 y
	var pr: Rect2 = bs._deploy_zone_rect(a)
	var y0: float = 67.0 + ymin / 32.0 * 1024.0
	assert_almost_eq(pr.position.y, y0, EPS, "竖版部署区顶边")
	assert_almost_eq(pr.end.y, 1091.0, EPS, "竖版部署区到场区底（67+1024）")
	assert_almost_eq(pr.size.x, 576.0, EPS, "竖版部署区全宽（=场地宽）")
	bs.free()
	# 横版：左段矩形，右边 = 部署线投影 x
	var bl = _mk(true)
	var lr: Rect2 = bl._deploy_zone_rect(a)
	var x1: float = (32.0 - ymin) / 32.0 * 720.0
	assert_almost_eq(lr.position.x, 0.0, EPS, "横版部署区从左缘起")
	assert_almost_eq(lr.end.x, x1, EPS, "横版部署区右边=部署线")
	assert_almost_eq(lr.size.y, 405.0, EPS, "横版部署区全高")
	bl.free()
