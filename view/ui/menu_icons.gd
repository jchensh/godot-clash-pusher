# MenuIcons —— 主界面入口按钮的程序化像素 icon（0718 CR 改版配套）。
#
# 占位性质：正式卡通手绘 icon 素材到位后整体换 TextureRect，本组件退役。
# 用法：ic = MenuIcons.new(); ic.kind = "battle"; ic.icon_color = ...; ic.size = Vector2(56, 56)。
# 绘制坐标统一 16 单位网格（u = size.x / 16），全部 draw_* 原语、零贴图资源（仿 hud_widget 思路）。
extends Control

var kind := ""
var icon_color := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var u: float = size.x / 16.0
	match kind:
		"shop": _draw_shop(u)
		"cards": _draw_cards(u)
		"kingdom": _draw_kingdom(u)
		"court": _draw_court(u)
		"diplomacy": _draw_diplomacy(u)
		"formation": _draw_formation(u)
		"journey": _draw_journey(u)
		"battle": _draw_battle(u)

func _r(x: float, y: float, w: float, h: float, u: float, col: Color) -> void:
	draw_rect(Rect2(x * u, y * u, w * u, h * u), col)

# 商店：钱袋（束口 + 圆袋身 + 竖缝）
func _draw_shop(u: float) -> void:
	_r(6.0, 2.5, 4.0, 2.0, u, icon_color)
	draw_circle(Vector2(8.0 * u, 9.5 * u), 4.6 * u, icon_color)
	_r(7.5, 7.5, 1.0, 4.0, u, Color(0, 0, 0, 0.35))

# 卡牌：两张错位叠放的卡
func _draw_cards(u: float) -> void:
	var back := icon_color
	back.a *= 0.55
	_r(3.0, 2.5, 6.5, 9.5, u, back)
	_r(6.5, 4.0, 6.5, 9.5, u, icon_color)
	_r(7.5, 5.0, 4.5, 3.0, u, Color(0, 0, 0, 0.3))

# 王国：城堡（三垛口 + 主体 + 城门）
func _draw_kingdom(u: float) -> void:
	_r(3.0, 4.5, 2.4, 2.5, u, icon_color)
	_r(6.8, 4.5, 2.4, 2.5, u, icon_color)
	_r(10.6, 4.5, 2.4, 2.5, u, icon_color)
	_r(3.0, 6.5, 10.0, 7.0, u, icon_color)
	_r(6.9, 9.5, 2.2, 4.0, u, Color(0, 0, 0, 0.4))

# 宫廷：王冠（三尖 + 底带）
func _draw_court(u: float) -> void:
	var pts := PackedVector2Array([
		Vector2(3.0, 11.5), Vector2(3.0, 5.5), Vector2(6.0, 8.5), Vector2(8.0, 3.5),
		Vector2(10.0, 8.5), Vector2(13.0, 5.5), Vector2(13.0, 11.5),
	])
	for i in pts.size():
		pts[i] *= u
	draw_colored_polygon(pts, icon_color)
	_r(3.0, 11.5, 10.0, 2.0, u, icon_color)

# 外交：卷轴国书（上下卷筒 + 纸面 + 两行字）
func _draw_diplomacy(u: float) -> void:
	_r(3.2, 3.0, 9.6, 2.2, u, icon_color)
	_r(4.4, 5.2, 7.2, 5.6, u, icon_color)
	_r(3.2, 10.8, 9.6, 2.2, u, icon_color)
	_r(5.5, 6.6, 5.0, 0.9, u, Color(0, 0, 0, 0.35))
	_r(5.5, 8.4, 5.0, 0.9, u, Color(0, 0, 0, 0.35))

# 布阵：3×3 阵型点
func _draw_formation(u: float) -> void:
	for gx in [3.0, 7.0, 11.0]:
		for gy in [3.5, 7.5, 11.5]:
			_r(gx - 1.1, gy - 1.1, 2.4, 2.4, u, icon_color)

# 国王征途：旗杆 + 三角军旗
func _draw_journey(u: float) -> void:
	_r(4.6, 2.5, 1.3, 11.0, u, icon_color)
	var pts := PackedVector2Array([Vector2(6.2, 3.0), Vector2(13.2, 5.2), Vector2(6.2, 7.6)])
	for i in pts.size():
		pts[i] *= u
	draw_colored_polygon(pts, icon_color)
	_r(3.6, 13.0, 3.4, 1.0, u, icon_color)

# 对战：交叉双剑（剑刃 + 短护手）
func _draw_battle(u: float) -> void:
	var w: float = 1.6 * u
	draw_line(Vector2(3.5, 12.5) * u, Vector2(12.5, 3.5) * u, icon_color, w)
	draw_line(Vector2(12.5, 12.5) * u, Vector2(3.5, 3.5) * u, icon_color, w)
	draw_line(Vector2(4.2, 9.8) * u, Vector2(6.2, 11.8) * u, icon_color, w * 0.8)
	draw_line(Vector2(11.8, 9.8) * u, Vector2(9.8, 11.8) * u, icon_color, w * 0.8)
