# V5-S7a：HudWidgets 纯逻辑助手单测（格式化/战力档/足额/星级填充）+ 工厂结构 smoke。
# 绘制本身（_draw 观感）走真人/截图验收，不在 headless 单测范围。
extends "res://tests/test_case.gd"

const HudWidgets := preload("res://view/ui/hud_widgets.gd")

func test_format_int() -> void:
	assert_eq(HudWidgets.format_int(0), "0")
	assert_eq(HudWidgets.format_int(7), "7")
	assert_eq(HudWidgets.format_int(850), "850")
	assert_eq(HudWidgets.format_int(1000), "1,000")
	assert_eq(HudWidgets.format_int(12480), "12,480")
	assert_eq(HudWidgets.format_int(1234567), "1,234,567")
	assert_eq(HudWidgets.format_int(-5000), "-5,000")

func test_power_tier() -> void:
	assert_eq(HudWidgets.power_tier(1200, 1000), HudWidgets.POWER_OK, "高于推荐=达标")
	assert_eq(HudWidgets.power_tier(1000, 1000), HudWidgets.POWER_OK, "等于推荐=达标")
	assert_eq(HudWidgets.power_tier(900, 1000), HudWidgets.POWER_LOW, "900≥800=略低")
	assert_eq(HudWidgets.power_tier(800, 1000), HudWidgets.POWER_LOW, "边界 0.8×=略低")
	assert_eq(HudWidgets.power_tier(799, 1000), HudWidgets.POWER_UNDER, "<0.8×=偏低")
	assert_eq(HudWidgets.power_tier(100, 0), HudWidgets.POWER_OK, "无推荐上下文=达标")

func test_affordable() -> void:
	assert_true(HudWidgets.affordable(10, 5))
	assert_true(HudWidgets.affordable(5, 5), "恰好够")
	assert_false(HudWidgets.affordable(4, 5))

func test_star_fill() -> void:
	assert_eq(HudWidgets.star_fill(2, 3), 2)
	assert_eq(HudWidgets.star_fill(3, 3), 3)
	assert_eq(HudWidgets.star_fill(5, 3), 3, "超上限钳到 cap")
	assert_eq(HudWidgets.star_fill(-1, 3), 0, "负数钳到 0")
	assert_eq(HudWidgets.star_fill(0, 0), 0)

# 工厂结构 smoke：返回非空 Control、尺寸已设；建后即 free（headless 不渲染，仅验构造不报错）。
func test_factories_construct() -> void:
	var widgets := [
		HudWidgets.wallet_bar(12480, 36),
		HudWidgets.stars_row(2, 3),
		HudWidgets.cost_pill("coin", 850, true),
		HudWidgets.rank_pips(3, 5),
		HudWidgets.stat_bar("战力", "1,180", 0.72, Color("ecb94e")),
		HudWidgets.locked_overlay("通关 2-6 解锁", 200, 60),
	]
	for w in widgets:
		assert_not_null(w, "工厂应返回节点")
		assert_true(w is Control, "应为 Control")
		assert_true(w.size.x > 0.0 and w.size.y > 0.0, "尺寸应已设")
		w.free()
