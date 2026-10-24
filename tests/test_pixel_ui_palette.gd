# UI 偏离修复 ①：PixelUI 夜色残留替换令牌的可读性守门。
# 主文字 COL_PARCHMENT 压在每个新底色上的 WCAG 对比度须 ≥ 4.5:1（正文 AA），改色读不清时此测先红。
# 观感本身走真人验收，不在 headless 单测范围。
extends "res://tests/test_case.gd"

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const MIN_TEXT_CONTRAST := 4.5

static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)

static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)

static func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func test_contrast_helper_matches_wcag() -> void:
	assert_almost_eq(_contrast(Color.BLACK, Color.WHITE), 21.0, 0.01, "黑白=21:1")
	assert_almost_eq(_contrast(PixelUI.COL_PARCHMENT, Color.WHITE), 7.25, 0.01, "主文字压白=7.25:1")

func test_text_readable_on_new_backgrounds() -> void:
	var bgs := {
		"NODE_DONE": PixelUI.COL_NODE_DONE_BG, "NODE_CURRENT": PixelUI.COL_NODE_CURRENT_BG,
		"NODE_FUTURE": PixelUI.COL_NODE_FUTURE_BG, "NODE_BOSS": PixelUI.COL_NODE_BOSS_BG,
		"TROOP": PixelUI.COL_TROOP_BG, "SPELL": PixelUI.COL_SPELL_BG,
		"SLOT_FILLED": PixelUI.COL_SLOT_FILLED_BG, "SLOT_EMPTY": PixelUI.COL_SLOT_EMPTY_BG,
		"DISABLED": PixelUI.COL_DISABLED_BG,
	}
	for name in bgs:
		var r := _contrast(PixelUI.COL_PARCHMENT, bgs[name])
		assert_true(r >= MIN_TEXT_CONTRAST, "COL_%s_BG 上主文字对比度 %.2f < %.1f" % [name, r, MIN_TEXT_CONTRAST])

func test_backgrounds_are_light_skin() -> void:
	# 防夜色回流：新底色亮度须高于 0.6（夜色旧底均 < 0.05）。
	for bg in [PixelUI.COL_NODE_DONE_BG, PixelUI.COL_NODE_CURRENT_BG, PixelUI.COL_NODE_FUTURE_BG,
			PixelUI.COL_NODE_BOSS_BG, PixelUI.COL_TROOP_BG, PixelUI.COL_SPELL_BG,
			PixelUI.COL_SLOT_FILLED_BG, PixelUI.COL_SLOT_EMPTY_BG, PixelUI.COL_DISABLED_BG]:
		assert_true(_luminance(bg) > 0.6, "底色 %s 过暗（夜色残留？）" % bg.to_html(false))

func test_border_darker_than_background() -> void:
	# 描边要比底色深，卡片/行的轮廓才分得出来。
	var pairs := [
		[PixelUI.COL_NODE_DONE_BG, PixelUI.COL_NODE_DONE_BD], [PixelUI.COL_NODE_CURRENT_BG, PixelUI.COL_NODE_CURRENT_BD],
		[PixelUI.COL_NODE_FUTURE_BG, PixelUI.COL_NODE_FUTURE_BD], [PixelUI.COL_NODE_BOSS_BG, PixelUI.COL_NODE_BOSS_BD],
		[PixelUI.COL_TROOP_BG, PixelUI.COL_TROOP_BD], [PixelUI.COL_SPELL_BG, PixelUI.COL_SPELL_BD],
		[PixelUI.COL_SLOT_FILLED_BG, PixelUI.COL_SLOT_FILLED_BD], [PixelUI.COL_SLOT_EMPTY_BG, PixelUI.COL_SLOT_EMPTY_BD],
		[PixelUI.COL_DISABLED_BG, PixelUI.COL_DISABLED_BD],
	]
	for p in pairs:
		assert_true(_luminance(p[1]) < _luminance(p[0]), "描边 %s 不比底 %s 深" % [p[1].to_html(false), p[0].to_html(false)])

func test_dim_is_lighter_than_night() -> void:
	# 暗幕换成深青蓝半透：不透明度须低于夜色旧值 0.72，且色相偏蓝（b > r）。
	assert_true(PixelUI.DIM_ALPHA > 0.0 and PixelUI.DIM_ALPHA < 0.72, "DIM_ALPHA=%.2f 应在 (0, 0.72)" % PixelUI.DIM_ALPHA)
	assert_true(PixelUI.COL_DIM.b > PixelUI.COL_DIM.r, "暗幕应偏青蓝")
