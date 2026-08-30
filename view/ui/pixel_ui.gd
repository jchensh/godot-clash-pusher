# PixelUI —— UI 设计系统：色板常量 + 9-slice 按钮/面板样式工厂。
# 决策 49 UI 换肤（2026-08-30 用户拍板方案 B「天空牧场」）：夜色像素系 → 淡色卡通系
# （淡天蓝底/白卡面板/暖黄 CTA/圆角立体边；设计稿 artifact a5e00b52 方案 B 同色值）。
# 文件名沿用 pixel_ui（引用面 20+ 文件不动）；"像素"仅是历史名。
#
# 用 assets/ui/ 的 9-slice 贴图（tools/gen_ui_assets.py 生成）建 StyleBoxTexture。
# 各场景 `const PixelUI := preload(".../pixel_ui.gd")` 后调 PixelUI.style_button(btn, kind)
# 复用统一像素风（主菜单标杆 → 选关/组卡/设置/run/结算/战斗 HUD 全复用同一套）。
# 不用 class_name（经 preload 调静态方法/常量，避开全局注册预检）。
#
# ⚠️ UI 层级规约（PLAN_V5_UIFRAME F3，KAN-97——本文件只管「好看」，「谁在上面/谁收点击」归 UI 层级骨架）：
# 1. 覆盖类 UI（弹窗/确认框/结算/教程覆盖）一律继承 view/ui/modal.gd 并经 `UI.modal()` 推入——
#    禁止手搓全屏 Control 靠「后 add_child 的兄弟在上」树序潜规则压层（KAN-98 教训）。
# 2. 提示/跳字走 `UI.toast()`（TOAST 层恒最顶且 IGNORE 不挡手），别在场景里手写 Label+tween。
# 3. z_index 只影响绘制不影响 Control 点击命中——想挡输入必须配 mouse_filter，别指望 z_index。
# 4. 想绕 GUI 做前置 `Node._input` 拦截（DragScroll 类）：必须先查 `UI.modal_open()` 让路弹窗层。
# 5. 想铺满（全屏根/暗幕/幕布）必须 `set_anchors_and_offsets_preset`——裸 set_anchors_preset 只改
#    锚点且保留当前矩形（新节点=0×0 隐形不拦输入，2026-07-06 P0 教训），view 层已单测封禁。
extends RefCounted

# —— 色板（天空牧场淡色卡通，权威常量；改色重跑 gen_ui_assets.py）——
const COL_PARCHMENT := Color("3a5a74")   # 主文字（深青蓝；浅底深字，常量名沿用）
const COL_MUTED := Color("7f9cb3")       # 次文字
const COL_GOLD := Color("3d9be0")        # 标题/强调（天空蓝；常量名沿用）
const COL_GOLD_INK := Color("5c430e")    # 黄 CTA 按钮上的深字
const COL_HINT := Color("9ab4c8")        # 脚注/弱提示
const COL_OUTLINE := Color("1f5c8c")     # 标题描边深蓝
const COL_PANEL_BG := Color("ffffff")    # 白卡面板底（换肤新增：散装深底的替代语义）
const COL_INSET_BG := Color("ddeefb")    # 凹槽/列表底

const _BTN_MARGIN := 14   # 按钮 9-slice 边距 = 圆角半径 12 + 2（圆角区不拉伸）
const _PANEL_MARGIN := 18  # 面板 9-slice 边距 = 圆角半径 16 + 2

static func _btn_box(path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.set_texture_margin_all(_BTN_MARGIN)
	sb.set_content_margin_all(10.0)
	sb.set_content_margin(SIDE_LEFT, 20.0)
	sb.set_content_margin(SIDE_RIGHT, 20.0)
	return sb

# 给按钮套 9-slice 三态 + 字色。kind = "stone" | "gold" | "dark"。
static func style_button(btn: Button, kind: String = "stone", font_size: int = 34) -> void:
	var base := "res://assets/ui/btn_%s_" % kind
	btn.add_theme_stylebox_override("normal", _btn_box(base + "normal.png"))
	btn.add_theme_stylebox_override("hover", _btn_box(base + "hover.png"))
	btn.add_theme_stylebox_override("pressed", _btn_box(base + "pressed.png"))
	btn.add_theme_stylebox_override("focus", _btn_box(base + "normal.png"))
	btn.add_theme_stylebox_override("disabled", _btn_box(base + "normal.png"))
	btn.add_theme_font_size_override("font_size", font_size)
	var fc: Color = COL_GOLD_INK if kind == "gold" else COL_PARCHMENT
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_hover_color", fc)
	btn.add_theme_color_override("font_pressed_color", fc)
	btn.add_theme_color_override("font_focus_color", fc)
	# 决策 49 换肤修复：disabled 字色显式定义（引擎默认半透明白在淡底上不可见）
	btn.add_theme_color_override("font_disabled_color", Color(fc.r, fc.g, fc.b, 0.45))

# 容器面板 StyleBox（对话框/卡槽）。kind = "stone"(凸) | "inset"(凹槽)。
static func panel_box(kind: String = "stone") -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/panel_%s.png" % kind)
	sb.set_texture_margin_all(_PANEL_MARGIN)
	sb.set_content_margin_all(16.0)
	return sb

# 动态语义色（难度/relic 稀有度/阵营色）用 StyleBoxFlat 程序化像素方块（无圆角+边框），
# 不为每种色生成 9-slice 贴图。固定中性样式（按钮/面板）才用上面的 9-slice。
static func sbpixel(bg: Color, border_w: int = 3, border_col: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)   # 决策 49 换肤：圆角卡通（原像素方块 0）
	sb.set_border_width_all(border_w)
	sb.border_color = border_col if border_col.a > 0.0 else bg.darkened(0.18)
	return sb

# 给场景铺夜色战场背景（已加为 parent 第一个 child，返回该 TextureRect）。
static func add_background(parent: Control) -> TextureRect:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/menu_bg.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg
