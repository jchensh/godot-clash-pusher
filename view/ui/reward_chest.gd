# RewardChest —— V5-S7c 领奖开箱动画（决策48，设计 §5；F2 起继承 Modal 走 UI.modal 弹窗层）。
#
# stage_map 在闯关战后（已向服务器上报、拿到实发奖励 delta）UI.modal(本节点) 播放：
#   暗幕 → 宝箱抖动 → 弹开金光 → 星级逐颗点亮 → 奖励数字滚动 → [继续]。
# 点击空白可跳过到末态（不强制看完）。纯 _draw + Tween 派生，0 贴图资源（字体除外）。
# setup(stars, cap, gold, gems, shards, first) 配置；关闭走基类 close()（closed 信号 + queue_free）。
extends "res://view/ui/modal.gd"

const PixelUI := preload("res://view/ui/pixel_ui.gd")
const FONT := preload("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")

const T_OPEN := 0.6     # 抖动→弹开
const T_STARS := 0.85   # 星级开始
const T_REWARD := 1.45  # 奖励滚动开始
const T_BTN := 2.05     # 继续按钮出现

const CHEST_BODY := Color("6b4a2a"); const CHEST_LITE := Color("8a6336")
const CHEST_DARK := Color("3f2c19"); const CHEST_EDGE := Color("1d130a")

var _t := 0.0
var _stars := 0
var _cap := 3
var _gold := 0
var _gems := 0
var _shards := 0
var _first := true
var _btn: Button

func _init() -> void:
	dim_alpha = 0.0   # 暗幕由本类 _draw 画（须垫在自绘宝箱之下；基类 ColorRect 是子节点会盖住 _draw）

func setup(stars: int, cap: int, gold: int, gems: int, shards: int, first: bool) -> void:
	_stars = stars; _cap = cap; _gold = gold; _gems = gems; _shards = shards; _first = first

func _build() -> void:
	_btn = Button.new()
	_btn.text = "继续"
	_btn.size = Vector2(240, 76)
	_btn.position = Vector2((720 - 240) / 2.0, 880)
	_btn.focus_mode = Control.FOCUS_NONE
	PixelUI.style_button(_btn, "gold", 30)
	_btn.visible = false
	_btn.pressed.connect(_close)
	add_child(_btn)
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	if _t >= T_BTN and not _btn.visible:
		_btn.visible = true
	queue_redraw()

func _on_bg_click() -> void:
	if _t < T_BTN:
		_t = T_BTN   # 跳过到末态

func _close() -> void:
	AudioManager.play_sfx("ui_button_press")
	close()

func _draw() -> void:
	var vp := size
	if vp.x < 10.0:
		vp = Vector2(720, 1280)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.03, 0.07, 0.78), true)
	var cx := vp.x / 2.0
	var cy := vp.y * 0.40
	# 标题
	var title := "首通！" if _first else "通关"
	draw_string(FONT, Vector2(0, vp.y * 0.20), title, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 56, PixelUI.COL_GOLD)
	var opened := _t >= T_OPEN
	# 金光（开箱后扩散射线）
	if opened:
		var gp := clampf((_t - T_OPEN) / 0.4, 0.0, 1.0)
		var rays := Color(PixelUI.COL_GOLD.r, PixelUI.COL_GOLD.g, PixelUI.COL_GOLD.b, (1.0 - gp) * 0.5)
		for i in range(12):
			var ang := float(i) / 12.0 * TAU
			var r0 := 40.0 + 30.0 * gp
			var r1 := 60.0 + 120.0 * gp
			draw_line(Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r0,
					Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * r1, rays, 3.0)
	# 宝箱
	var shake := 0.0
	if not opened:
		shake = sin(_t * 40.0) * 4.0 * (_t / T_OPEN)
	var bw := 132.0
	var bh := 76.0
	var bx := cx - bw / 2.0 + shake
	var by := cy - bh / 2.0 + 20.0
	_bevel(Rect2(bx, by, bw, bh), CHEST_BODY, CHEST_LITE, CHEST_DARK, CHEST_EDGE)
	# 箱带 + 锁
	draw_rect(Rect2(cx - 9 + shake, by, 18, bh), PixelUI.COL_GOLD.darkened(0.1), true)
	draw_rect(Rect2(cx - 7 + shake, by + bh / 2.0 - 7, 14, 14), PixelUI.COL_GOLD, true)
	# 箱盖（开箱后上移 + 后翻）
	var lift := 0.0
	if opened:
		lift = clampf((_t - T_OPEN) / 0.25, 0.0, 1.0) * 38.0
	var lid := Rect2(bx - 4, by - 22 - lift, bw + 8, 26)
	_bevel(lid, CHEST_LITE, CHEST_LITE.lightened(0.2), CHEST_DARK, CHEST_EDGE)
	# 星级（开箱后逐颗弹出）
	if _t >= T_STARS:
		var step := 52.0
		var sx := cx - float(_cap - 1) * step / 2.0
		for i in range(_cap):
			var lt := clampf((_t - T_STARS - float(i) * 0.16) / 0.3, 0.0, 1.0)
			if lt <= 0.0:
				continue
			var on := i < _stars
			var rr := 22.0 * (0.4 + 0.6 * _ease_back(lt))
			_star(Vector2(sx + float(i) * step, cy - 88.0), rr, PixelUI.COL_GOLD if on else PixelUI.COL_OUTLINE)
	# 奖励数字（滚动）
	if _t >= T_REWARD:
		var rp := clampf((_t - T_REWARD) / 0.5, 0.0, 1.0)
		var y := cy + 90.0
		_reward_line(cx, y, "coin", "金币 +%d" % int(_gold * rp))
		if _gems > 0:
			y += 40.0
			_reward_line(cx, y, "gem", "宝石 +%d" % int(_gems * rp))
		if _shards > 0:
			y += 40.0
			_reward_line(cx, y, "shard", "碎片 +%d" % int(_shards * rp))

func _reward_line(cx: float, y: float, icon: String, text: String) -> void:
	var col := PixelUI.COL_PARCHMENT
	match icon:
		"coin": draw_circle(Vector2(cx - 90, y + 8), 8, PixelUI.COL_GOLD)
		"gem": _diamond(Vector2(cx - 90, y + 8), 8, Color("7c94c8"))
		"shard": _diamond(Vector2(cx - 90, y + 8), 8, Color("b48fe0"))
	draw_string(FONT, Vector2(cx - 74, y + 14), text, HORIZONTAL_ALIGNMENT_LEFT, 200, 22, col)

func _bevel(r: Rect2, face: Color, lite: Color, dark: Color, edge: Color) -> void:
	draw_rect(r, face, true)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), lite, true)
	draw_rect(Rect2(r.position, Vector2(2, r.size.y)), lite, true)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), dark, true)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), dark, true)
	draw_rect(r, edge, false, 1.0)

func _star(center: Vector2, rad: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rr := rad if i % 2 == 0 else rad * 0.42
		pts.append(center + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, c)

func _diamond(center: Vector2, r: float, body: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r * 0.82, 0),
		center + Vector2(0, r), center + Vector2(-r * 0.82, 0)]), body)

func _ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var x := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x
