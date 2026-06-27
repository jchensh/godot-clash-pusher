#!/usr/bin/env python3
"""像素 UI 资源生成器（V3 UI/UX 设计系统）。

产出 assets/ui/ 下的 9-slice 按钮/面板贴图（石板 / 烫金 三态）+ 夜色战场主菜单背景。
全部纯像素色块 + 双层立体描边（亮边上左 / 暗边下右），中间纯色填充（9-slice 拉伸无失真）。
色板见 docs/ART_ASSETS.md / HISTORY V3 UI 节。改色板后重跑本脚本即可重生成（产物入 git）。

用法： uv run --with pillow python tools/gen_ui_assets.py
"""
import os
from PIL import Image, ImageDraw

OUT = "assets/ui"
os.makedirs(OUT, exist_ok=True)


def hx(c: str):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)


def slab(name, face, lite, dark, edge, w=32, h=32, e=2, b=3):
    """9-slice 立体面板：外 e px 描边 + 内 b px 斜角(亮上左/暗下右) + 中间 face。
    Godot StyleBoxTexture 的 texture_margin 取 e+b。"""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], fill=hx(face))
    for i in range(e):  # 外描边
        d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=hx(edge))
    for i in range(b):  # 亮斜角：上 + 左
        o = e + i
        d.line([(e, o), (w - 1 - e, o)], fill=hx(lite))
        d.line([(o, e), (o, h - 1 - e)], fill=hx(lite))
    for i in range(b):  # 暗斜角：下 + 右
        o = e + i
        d.line([(e, h - 1 - o), (w - 1 - e, h - 1 - o)], fill=hx(dark))
        d.line([(w - 1 - o, e), (w - 1 - o, h - 1 - e)], fill=hx(dark))
    im.save(f"{OUT}/{name}.png")
    return name


# —— 石板按钮三态（normal/hover/pressed；pressed 斜角反转=凹陷）——
slab("btn_stone_normal", "#3a3552", "#565079", "#211d30", "#100d18")
slab("btn_stone_hover", "#454069", "#6a6494", "#2a2540", "#100d18")
slab("btn_stone_pressed", "#2e2a45", "#211d30", "#565079", "#100d18")
# —— 烫金 CTA 三态 ——
slab("btn_gold_normal", "#cda743", "#f0d480", "#8a6418", "#3a2a08")
slab("btn_gold_hover", "#ddb84e", "#f8e29a", "#9a7420", "#3a2a08")
slab("btn_gold_pressed", "#b8923a", "#8a6418", "#f0d480", "#3a2a08")
# —— 弱化按钮（退出等）三态 ——
slab("btn_dark_normal", "#322e46", "#4a4568", "#1b1828", "#0c0a14")
slab("btn_dark_hover", "#3c3855", "#564f76", "#211d30", "#0c0a14")
slab("btn_dark_pressed", "#272338", "#1b1828", "#4a4568", "#0c0a14")
# —— 通用容器面板（对话框/卡槽，更大边距）——
slab("panel_stone", "#2e2a40", "#45405e", "#1a1726", "#0c0a14", w=40, h=40, e=3, b=4)
slab("panel_inset", "#1b1828", "#15121d", "#322e46", "#0c0a14", w=40, h=40, e=3, b=4)
# 动态语义色卡片/徽章（难度色/relic 稀有度等）改用 StyleBoxFlat 程序化像素方块，
# 不为每种色生成 9-slice 贴图（也避开编辑器开着时新贴图难导入的问题）。见 level_select._sbpixel。


def menu_bg():
    """夜色战场主菜单背景 720×1280（标题/按钮等 UI 由 Godot 叠在其上）。"""
    W, H = 720, 1280
    im = Image.new("RGBA", (W, H), hx("#15111f"))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 360], fill=hx("#1d1733"))      # 高空
    d.rectangle([0, 360, W, 470], fill=hx("#171221"))    # 地平线天
    d.rectangle([0, 470, W, H], fill=hx("#161320"))      # 暗色地表
    # 月
    d.rectangle([602, 54, 654, 106], fill=hx("#e8e0c0"))
    d.rectangle([636, 62, 654, 92], fill=hx("#bdb488"))
    # 星
    for x, y, c in [(70, 72, "#d8cf9e"), (190, 46, "#a79fc0"), (300, 98, "#d8cf9e"),
                    (446, 60, "#cfc79a"), (524, 128, "#a79fc0"), (120, 150, "#cfc79a"),
                    (560, 40, "#d8cf9e"), (360, 28, "#a79fc0")]:
        d.rectangle([x, y, x + 4, y + 4], fill=hx(c))
    # 远景塔剪影（带垛口）
    for x, w, th in [(40, 76, 92), (150, 64, 116), (300, 100, 132), (498, 64, 110), (612, 76, 88)]:
        top = 470 - th
        d.rectangle([x, top, x + w, 470], fill=hx("#2a2440"))
        for bx in range(x, x + w - 7, 18):
            d.rectangle([bx, top - 8, bx + 9, top], fill=hx("#2a2440"))
    # 河 + 波纹
    d.rectangle([0, 430, W, 468], fill=hx("#16314f"))
    for x, y in [(80, 440), (260, 454), (462, 442), (642, 452), (180, 448), (360, 458)]:
        d.rectangle([x, y, x + 12, y + 3], fill=hx("#2d567f"))
    # 双桥（鹅卵石）
    for bx in (128, 532):
        d.rectangle([bx, 430, bx + 60, 468], fill=hx("#4a4036"))
        d.rectangle([bx, 430, bx + 60, 433], fill=hx("#5a4f42"))
    im.save(f"{OUT}/menu_bg.png")


menu_bg()
print("ui assets generated ->", OUT)
for f in sorted(os.listdir(OUT)):
    print("  ", f)
