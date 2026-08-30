# 决策 49（KAN-121）：单位视觉体型配置化规约——units.json 全单位必有 vis_height_px 正数
# （屏幕身高像素 @25px/格 基准；策划调大小的唯一入口，血条/影子/体型由此派生）。
# 迁移基准锁定：换算公式 半径 = vis_height_px/(2×CARTOON_H_MULT)×(ur/25) 与旧 UNIT_VIS
# 代码表在初值下逐单位恒等（保 0830 验收观感零回归）。
extends "res://tests/test_case.gd"

const ConfigLoaderScript = preload("res://logic/config_loader.gd")
const SpriteDB = preload("res://view/sprite_db.gd")


func test_all_units_have_vis_height() -> void:
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	for uid in loader.units:
		if String(uid).begins_with("_"):
			continue
		var vh := float((loader.units[uid] as Dictionary).get("vis_height_px", 0.0))
		assert_true(vh > 0.0, "单位 %s 缺 vis_height_px（策划体型表必填）" % uid)
		assert_true(vh >= 15.0 and vh <= 200.0, "单位 %s vis_height_px=%d 超合理区间[15,200]" % [uid, int(vh)])


func test_vis_height_matches_legacy_table() -> void:
	# 初值 = UNIT_VIS r × 87.5（换算恒等 → 配置化迁移零观感回归）。策划改值后本用例只查
	# 仍在 ±60% 带内（防手滑填错量纲，如把像素填成格数）。
	var loader = ConfigLoaderScript.new()
	loader.load_all()
	for uid in SpriteDB.UNIT_VIS:
		if not loader.units.has(uid):
			continue
		var vh := float((loader.units[uid] as Dictionary).get("vis_height_px", 0.0))
		var legacy: float = float((SpriteDB.UNIT_VIS[uid] as Dictionary)["r"]) * 87.5
		assert_true(vh > legacy * 0.4 and vh < legacy * 1.6,
				"单位 %s vis_height_px=%d 偏离参考值 %.0f 逾 60%%（疑量纲错误）" % [uid, int(vh), legacy])
