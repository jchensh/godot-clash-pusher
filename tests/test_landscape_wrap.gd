# L2 LandscapeWrap 适配壳（2026-07-26）：结构（SubViewport=竖版画布）/ scroll 布局与滚动钳制 /
# fit 等比缩放。离线树测几何——_layout 手动驱动（resized 信号无树不发）。
extends "res://tests/test_case.gd"

const Wrap = preload("res://view/ui/landscape_wrap.gd")


func _page() -> Control:
	var p := Control.new()
	p.name = "FakePage"
	return p


func test_structure_subviewport_is_portrait_canvas() -> void:
	var w: Control = Wrap.wrap(_page(), "scroll")
	var vp: SubViewport = w._vp
	assert_not_null(vp, "壳内应有 SubViewport")
	assert_eq(vp.size, Vector2i(720, 1280), "子视口=竖版设计画布 720×1280")
	assert_eq(vp.get_child(0).name, "FakePage", "页面应装进子视口")
	w.free()


func test_scroll_layout_and_clamp() -> void:
	var w: Control = Wrap.wrap(_page(), "scroll")
	w.size = Vector2(1280, 720)
	w._layout()
	assert_eq(w._clip.position, Vector2(280, 0), "立柱居中：clip x=(1280-720)/2")
	assert_eq(w._clip.size, Vector2(720, 720), "clip 尺寸=720 宽×视口高")
	assert_eq(w._max_scroll(), 560.0, "滚动上限=1280-720")
	w._set_scroll(99999.0)
	assert_eq(w._scroll, 560.0, "滚动过冲应钳制到上限")
	assert_eq(w._holder.position.y, -560.0, "holder 随滚动上移")
	w._set_scroll(-50.0)
	assert_eq(w._scroll, 0.0, "负向滚动钳回 0")
	w.free()


func test_fit_scales_and_centers() -> void:
	var w: Control = Wrap.wrap(_page(), "fit")
	w.size = Vector2(1280, 720)
	w._layout()
	var s: float = 720.0 / 1280.0   # min(1280/720, 720/1280)=0.5625
	assert_true(absf(w._holder.scale.x - s) < 0.0001, "fit 按短边等比缩放")
	assert_true(absf(w._holder.position.x - (1280.0 - 720.0 * s) * 0.5) < 0.0001, "fit 水平居中")
	assert_true(absf(w._holder.position.y) < 0.0001, "fit 纵向贴满（720*1.0 撑满高度→y=0）")
	w.free()
