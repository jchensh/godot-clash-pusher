# HudWidgets —— V5-S7a 共享 HUD 组件工厂 + 纯逻辑助手（决策48 瘦客户端 UI 整合）。
#
# 三个 S7 场景（基地/闯关地图/养成）复用同一套观感：钱包条/星级/cost 药丸/阶 pip/数值条/锁罩。
# 工厂返回已配置的 HudWidget（纯 _draw 节点，0 贴图资源），场景只管定位。
# 纯逻辑助手（format_int/power_tier/affordable/star_fill）可 headless 单测，见 tests/test_hud_widgets.gd。
# 不用 class_name（仿 pixel_ui.gd，经 preload 调静态方法/常量，避开新脚本预检）。
extends RefCounted

const HudWidget := preload("res://view/ui/hud_widget.gd")
const PixelUI := preload("res://view/ui/pixel_ui.gd")
const SpriteDB := preload("res://view/sprite_db.gd")

# 战力达标档（deck builder / 养成战力提示用）
const POWER_OK := 0      # ≥ 推荐
const POWER_LOW := 1     # ≥ 0.8×推荐（略低，操作可弥补窗口）
const POWER_UNDER := 2   # < 0.8×推荐（偏低，建议先养成）

# —— 纯逻辑助手（可单测）——

# 千分位整数格式化："12480" → "12,480"；负数保留符号。
static func format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if n < 0 else out

# 战力达标档：推荐≤0（无关卡上下文）→ OK；否则按 1.0 / 0.8 阈值分三档。
static func power_tier(power: int, recommended: int) -> int:
	if recommended <= 0 or power >= recommended:
		return POWER_OK
	if float(power) >= float(recommended) * 0.8:
		return POWER_LOW
	return POWER_UNDER

static func power_tier_color(tier: int) -> Color:
	match tier:
		POWER_OK: return Color("7cc36a")
		POWER_LOW: return PixelUI.COL_GOLD
		_: return Color("e24b4a")

static func affordable(have: int, need: int) -> bool:
	return have >= need

# 星级填充数（钳到 [0, cap]）。
static func star_fill(stars: int, cap: int) -> int:
	return clampi(stars, 0, maxi(cap, 0))

# —— 组件工厂（返回 HudWidget 节点）——

static func wallet_bar(gold: int, gems: int, width: float = 320.0) -> Control:
	var w := HudWidget.new()
	w.setup("wallet", {"gold_text": format_int(gold), "gems_text": format_int(gems)}, Vector2(width, 44))
	return w

static func stars_row(stars: int, cap: int, px: float = 22.0) -> Control:
	var w := HudWidget.new()
	w.setup("stars", {"stars": star_fill(stars, cap), "cap": cap}, Vector2(px * cap, px))
	return w

# icon = "coin" | "shard" | "gem"
static func cost_pill(icon: String, amount: int, can_afford: bool, width: float = 116.0) -> Control:
	var w := HudWidget.new()
	w.setup("cost", {"icon": icon, "amount_text": format_int(amount), "affordable": can_afford}, Vector2(width, 30))
	return w

static func rank_pips(rank: int, cap: int, px: float = 18.0) -> Control:
	var w := HudWidget.new()
	w.setup("pips", {"rank": rank, "cap": cap}, Vector2(px * cap, px))
	return w

static func stat_bar(label: String, value_text: String, pct: float, fill: Color, width: float = 260.0) -> Control:
	var w := HudWidget.new()
	w.setup("statbar", {"label": label, "value_text": value_text, "pct": pct, "fill": fill}, Vector2(width, 38))
	return w

static func locked_overlay(hint: String, w_px: float, h_px: float) -> Control:
	var w := HudWidget.new()
	w.setup("locked", {"hint": hint}, Vector2(w_px, h_px))
	return w

# —— V5-S9 玩家名片（怪物头像 9-slice 框 + 昵称 + 可选杯数）——
# avatar_card_id = 怪物卡 id（走 SpriteDB 立绘）；loader = ConfigLoader；trophies<0 隐藏杯数。
# align_left=true 头像在左、文字左对齐；false（PVP 对手）头像在右、文字右对齐。
static func nameplate(nickname: String, avatar_card_id: String, loader, trophies: int = -1, align_left: bool = true) -> Control:
	var av := 64.0
	var pad := 12.0
	var name_w := 232.0
	var total_w: float = av + pad + name_w
	var root := Control.new()
	root.custom_minimum_size = Vector2(total_w, av)
	root.size = Vector2(total_w, av)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fx: float = 0.0 if align_left else (total_w - av)
	var tx: float = (av + pad) if align_left else 0.0
	var halign := HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_RIGHT
	# 头像框
	var frame := Panel.new()
	frame.position = Vector2(fx, 0)
	frame.size = Vector2(av, av)
	frame.add_theme_stylebox_override("panel", PixelUI.sbpixel(Color("1c1626"), 2, PixelUI.COL_GOLD))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var tex := SpriteDB.card_portrait_tex(avatar_card_id, loader)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.modulate = SpriteDB.card_portrait_tint(avatar_card_id, loader)
		pic.position = Vector2(fx + 7, 7)
		pic.size = Vector2(av - 14, av - 14)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pic)
	# 昵称
	var nl := Label.new()
	nl.text = nickname if nickname.strip_edges() != "" else "勇者"
	nl.position = Vector2(tx, 2)
	nl.size = Vector2(name_w, 36)
	nl.horizontal_alignment = halign
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 26)
	nl.add_theme_color_override("font_color", PixelUI.COL_GOLD)
	nl.add_theme_color_override("font_outline_color", PixelUI.COL_OUTLINE)
	nl.add_theme_constant_override("outline_size", 4)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nl)
	# 杯数（可选）
	if trophies >= 0:
		var tl := Label.new()
		tl.text = "杯 %s" % format_int(trophies)
		tl.position = Vector2(tx, 38)
		tl.size = Vector2(name_w, 24)
		tl.horizontal_alignment = halign
		tl.add_theme_font_size_override("font_size", 18)
		tl.add_theme_color_override("font_color", PixelUI.COL_MUTED)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tl)
	return root
