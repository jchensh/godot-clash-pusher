# HudWidget —— V5-S7a 单个可配置 HUD 组件节点（纯 _draw，0 贴图资源；字体除外）。
#
# 由 view/ui/hud_widgets.gd 的静态工厂创建并 setup(kind, data, size)，本节点只按 data 画。
# 复用 tools/gen_ui_assets.py slab() 的立体描边算法，搬到运行时 _draw（无需烤 PNG、随调色板即时重绘）。
# 数字格式化/阈值判定等纯逻辑在 hud_widgets.gd（可单测）；本节点只接收已算好的显示串/值。
# 不用 class_name（经 preload 引用，避开新脚本 .uid 前的 test runner 预检）。
extends Control

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const FONT := preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")

# 语义色（PixelUI 未涵盖的动态色）
const COL_GREEN := Color("7cc36a")
const COL_RED := Color("e24b4a")
const COL_VIOLET := Color("b48fe0")
const COL_RARE := Color("7c94c8")
# 烫金（gen btn_gold_normal）
const GOLD_FACE := Color("cda743"); const GOLD_LITE := Color("f0d480")
const GOLD_DARK := Color("8a6418"); const GOLD_EDGE := Color("3a2a08")
# 钱包/cost 芯片（暗紫凸块）
const CHIP_FACE := Color("1c1626"); const CHIP_LITE := Color("2a2440")
const CHIP_DARK := Color("100d18"); const CHIP_EDGE := Color("0c0a14")
# 凹槽（数值条）
const GROOVE_FACE := Color("18141f"); const GROOVE_LITE := Color("12101a")
const GROOVE_DARK := Color("3a3450"); const GROOVE_EDGE := Color("0c0a14")

var kind := ""
var data := {}

func setup(k: String, d: Dictionary, sz: Vector2) -> void:
	kind = k
	data = d
	custom_minimum_size = sz
	size = sz
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	match kind:
		"wallet": _draw_wallet()
		"stars": _draw_stars()
		"cost": _draw_cost()
		"pips": _draw_pips()
		"statbar": _draw_statbar()
		"locked": _draw_locked()

# ---------- 各组件 ----------
func _draw_wallet() -> void:
	var gap := 8.0
	var cw := (size.x - gap) / 2.0
	_chip(Rect2(0, 0, cw, size.y), "coin", String(data.get("gold_text", "0")), PixelUI.COL_PARCHMENT)
	_chip(Rect2(cw + gap, 0, cw, size.y), "gem", String(data.get("gems_text", "0")), PixelUI.COL_PARCHMENT)

func _draw_cost() -> void:
	var afford := bool(data.get("affordable", true))
	_bevel_box(Rect2(Vector2.ZERO, size), CHIP_FACE, CHIP_LITE, CHIP_DARK, CHIP_EDGE, 2, 2)
	var icon := String(data.get("icon", "coin"))
	_icon(icon, Vector2(15, size.y / 2.0), 7.0)
	var col: Color = PixelUI.COL_PARCHMENT if afford else COL_RED
	_text(String(data.get("amount_text", "0")), 26, (size.y - 16) / 2.0 - 1.0, 16, col, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30)

func _draw_stars() -> void:
	var cap := int(data.get("cap", 3))
	var n := int(data.get("stars", 0))
	var step := size.x / float(maxi(cap, 1))
	var r := minf(step, size.y) * 0.46
	for i in range(cap):
		var c: Color = PixelUI.COL_GOLD if i < n else PixelUI.COL_OUTLINE
		_star(Vector2(step * (i + 0.5), size.y / 2.0), r, c)

func _draw_pips() -> void:
	var cap := int(data.get("cap", 5))
	var rank := int(data.get("rank", 1))
	var step := size.x / float(maxi(cap, 1))
	var s := minf(step - 4.0, size.y)
	for i in range(cap):
		var on := i < rank
		var br := Rect2(step * i + (step - s) / 2.0, (size.y - s) / 2.0, s, s)
		draw_rect(br, PixelUI.COL_GOLD if on else Color("2a2436"), true)
		_outline(br, PixelUI.COL_GOLD_INK if on else Color("46406a"))

func _draw_statbar() -> void:
	var fill: Color = data.get("fill", PixelUI.COL_GOLD)
	_text(String(data.get("label", "")), 0, 0, 14, PixelUI.COL_MUTED, HORIZONTAL_ALIGNMENT_LEFT, 90)
	_text(String(data.get("value_text", "")), 0, 0, 14, fill.lightened(0.12), HORIZONTAL_ALIGNMENT_RIGHT, size.x)
	var groove := Rect2(0, 22, size.x, maxf(size.y - 22, 8))
	_bevel_box(groove, GROOVE_FACE, GROOVE_LITE, GROOVE_DARK, GROOVE_EDGE, 1, 1)
	var pct := clampf(float(data.get("pct", 0.0)), 0.0, 1.0)
	var iw := (groove.size.x - 4.0) * pct
	if iw > 0.0:
		draw_rect(Rect2(groove.position + Vector2(2, 2), Vector2(iw, groove.size.y - 4.0)), fill, true)
		_hline(2, groove.position.y + 2, iw, fill.lightened(0.25))

func _draw_locked() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.08, 0.66), true)
	var cx := size.x / 2.0
	_lock(Vector2(cx, size.y / 2.0 - 10.0), 18.0)
	_text(String(data.get("hint", "")), 0, size.y / 2.0 + 14.0, 14, PixelUI.COL_HINT, HORIZONTAL_ALIGNMENT_CENTER, size.x)

# ---------- 绘制工具（1px 填充矩形 = 像素锐利；复刻 gen_ui_assets.slab）----------
func _hline(x: float, y: float, w: float, c: Color) -> void:
	draw_rect(Rect2(round(x), round(y), round(w), 1), c, true)

func _vline(x: float, y: float, h: float, c: Color) -> void:
	draw_rect(Rect2(round(x), round(y), 1, round(h)), c, true)

func _bevel_box(r: Rect2, face: Color, lite: Color, dark: Color, edge: Color, e: int, b: int) -> void:
	var x0 := r.position.x; var y0 := r.position.y; var w := r.size.x; var h := r.size.y
	draw_rect(r, face, true)
	for i in range(e):
		_hline(x0 + i, y0 + i, w - 2 * i, edge)
		_hline(x0 + i, y0 + h - 1 - i, w - 2 * i, edge)
		_vline(x0 + i, y0 + i, h - 2 * i, edge)
		_vline(x0 + w - 1 - i, y0 + i, h - 2 * i, edge)
	for i in range(b):
		var o := e + i
		_hline(x0 + e, y0 + o, w - 2 * e, lite)
		_vline(x0 + o, y0 + e, h - 2 * e, lite)
	for i in range(b):
		var o := e + i
		_hline(x0 + e, y0 + h - 1 - o, w - 2 * e, dark)
		_vline(x0 + w - 1 - o, y0 + e, h - 2 * e, dark)

func _outline(r: Rect2, c: Color) -> void:
	_hline(r.position.x, r.position.y, r.size.x, c)
	_hline(r.position.x, r.position.y + r.size.y - 1, r.size.x, c)
	_vline(r.position.x, r.position.y, r.size.y, c)
	_vline(r.position.x + r.size.x - 1, r.position.y, r.size.y, c)

func _chip(rect: Rect2, icon: String, text: String, text_col: Color) -> void:
	_bevel_box(rect, CHIP_FACE, CHIP_LITE, CHIP_DARK, CHIP_EDGE, 2, 2)
	_icon(icon, Vector2(rect.position.x + 17, rect.position.y + rect.size.y / 2.0), 8.0)
	_text(text, rect.position.x + 30, rect.position.y + (rect.size.y - 18) / 2.0 - 1.0, 18,
			text_col, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 34)

func _icon(name: String, center: Vector2, r: float) -> void:
	match name:
		"coin":
			draw_circle(center, r, GOLD_DARK)
			draw_circle(center, r - 2.0, PixelUI.COL_GOLD)
			draw_circle(center - Vector2(r * 0.28, r * 0.28), maxf(r * 0.22, 1.0), GOLD_LITE)
		"gem":
			_diamond(center, r, COL_RARE, Color("d0dcff"))
		"shard":
			_diamond(center, r, COL_VIOLET, Color("e6d4ff"))

func _diamond(center: Vector2, r: float, body: Color, hi: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r * 0.82, 0),
		center + Vector2(0, r), center + Vector2(-r * 0.82, 0)]), body)
	draw_line(center + Vector2(0, -r), center + Vector2(0, r), hi, 1.0)

func _star(center: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rad := r if i % 2 == 0 else r * 0.42
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, c)

func _lock(center: Vector2, s: float) -> void:
	var body := Rect2(center.x - s * 0.6, center.y, s * 1.2, s * 0.9)
	draw_rect(body, PixelUI.COL_HINT, true)
	_outline(body, Color("0c0a14"))
	# 锁梁（方拱）
	var aw := s * 0.7
	_vline(center.x - aw / 2.0, center.y - s * 0.6, s * 0.6, PixelUI.COL_HINT)
	_vline(center.x + aw / 2.0, center.y - s * 0.6, s * 0.6, PixelUI.COL_HINT)
	_hline(center.x - aw / 2.0, center.y - s * 0.6, aw, PixelUI.COL_HINT)
	# 锁孔
	draw_rect(Rect2(center.x - 1.5, center.y + s * 0.28, 3, s * 0.34), Color("0c0a14"), true)

func _text(s: String, x: float, y_top: float, fsize: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(FONT, Vector2(x, y_top + FONT.get_ascent(fsize)), s, align, w, fsize, c)
