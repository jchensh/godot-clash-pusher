# FxDraw —— 程序化命中/落地 FX 绘制助手（2026-07-15 自 battle_scene 原样抽出：文件顶 1500 行 lint 上限，
# 为 Y-sort 伪深度腾空间）。纯静态无状态，canvas 由调用方传入（battle_scene._draw_fx 按 kind 分派）。
# 参数约定：c=屏幕中心（px）、size/r=屏幕尺寸（px）、p=动画进度 0~1。
extends RefCounted


# sheet 横向序列帧：按进度 p 取帧画到 center（边长 size），modulate 染色。
static func seq(cv: CanvasItem, tex: Texture2D, fpx: int, n: int, c: Vector2, size: float, p: float, mod: Color) -> void:
	var fi: int = mini(n - 1, int(p * n))
	cv.draw_texture_rect_region(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), Rect2(fi * fpx, 0, fpx, fpx), mod)


# 程序化尘土环（召唤落地 / 滚石）：扩散 + 淡出。
static func dust(cv: CanvasItem, c: Vector2, r: float, p: float, col: Color) -> void:
	var rr: float = r * (0.35 + 1.0 * p)
	var a: float = (1.0 - p) * 0.6
	cv.draw_circle(c, rr * 0.85, Color(col.r, col.g, col.b, a * 0.35))
	cv.draw_arc(c, rr, 0.0, TAU, 26, Color(col.r, col.g, col.b, a), 3.0)


# 程序化箭雨：数支箭错峰斜插入 AOE 区淡出。
static func arrows(cv: CanvasItem, c: Vector2, r: float, p: float) -> void:
	var col := Color(0.92, 0.86, 0.6)
	for i in 8:
		var lt: float = clampf((p - float(i) * 0.03) / 0.45, 0.0, 1.0)
		if lt <= 0.0:
			continue
		var ox: float = (float(i) / 7.0 - 0.5) * 1.6 * r
		var tip: Vector2 = c + Vector2(ox, -r * 0.4 + r * 1.3 * lt)
		col.a = 1.0 - lt
		cv.draw_line(tip + Vector2(-7, -18), tip, col, 2.0)
		cv.draw_line(tip, tip + Vector2(-3, -5), col, 1.5)
		cv.draw_line(tip, tip + Vector2(4, -5), col, 1.5)


# 程序化治疗：绿色扩散环 + 上浮十字。
static func heal(cv: CanvasItem, c: Vector2, r: float, p: float) -> void:
	cv.draw_arc(c, r * (0.4 + 0.8 * p), 0.0, TAU, 28, Color(0.4, 1.0, 0.5, (1.0 - p) * 0.7), 2.5)
	for i in 5:
		var ang: float = float(i) / 5.0 * TAU
		var pp: Vector2 = c + Vector2(cos(ang), sin(ang)) * r * 0.45 - Vector2(0, r * 0.7 * p)
		var pa: float = 1.0 - p
		cv.draw_line(pp - Vector2(3, 0), pp + Vector2(3, 0), Color(0.5, 1, 0.6, pa), 2.0)
		cv.draw_line(pp - Vector2(0, 3), pp + Vector2(0, 3), Color(0.5, 1, 0.6, pa), 2.0)
