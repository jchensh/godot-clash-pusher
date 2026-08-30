#!/usr/bin/env python3
"""卡通 UI 资源生成器（决策 49 UI 换肤·方案 B「天空牧场」，2026-08-30 用户拍板；
旧版=V3 夜色像素系，git 历史可回溯）。

产出 assets/ui/ 下的 9-slice 按钮/面板贴图 + 天空渐变主菜单背景。
风格 = 淡色卡通：圆角矩形 + 外描边 + 内部上亮/下暗立体边（与设计稿
https://claude.ai/code/artifact/a5e00b52-1eaf-435c-bec7-2c8f47ead0c3 方案 B 同色值）。
色板权威常量在 view/ui/pixel_ui.gd；改色后重跑本脚本重生成（产物入 git）。

用法： uv run --with pillow python tools/gen_ui_assets.py
"""
import os
from PIL import Image, ImageDraw

OUT = "assets/ui"
os.makedirs(OUT, exist_ok=True)

SS = 4  # 超采样倍率（圆角抗锯齿：大画布画完缩回）


def hx(c: str):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)


def rounded(name, face, lite, dark, edge, w=48, h=48, r=12, e=2, b=3):
    """卡通圆角 9-slice：外 e px 描边圆角框 + 内上亮/下暗 b px 立体带 + face 填充。
    Godot StyleBoxTexture 的 texture_margin 取 r+2（圆角区不拉伸）。"""
    W, H, R, E, B = w * SS, h * SS, r * SS, e * SS, b * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=R, fill=hx(edge))
    d.rounded_rectangle([E, E, W - 1 - E, H - 1 - E], radius=R - E, fill=hx(lite))
    d.rounded_rectangle([E, E + B, W - 1 - E, H - 1 - E], radius=R - E, fill=hx(dark))
    d.rounded_rectangle([E, E + B, W - 1 - E, H - 1 - E - B], radius=R - E, fill=hx(face))
    im = im.resize((w, h), Image.LANCZOS)
    im.save(f"{OUT}/{name}.png")


# —— 天空牧场色板（=pixel_ui.gd / 设计稿方案 B）——
# 普通按钮（淡蓝）三态：pressed 亮暗反转=按下凹陷
rounded("btn_stone_normal", "#dceefc", "#f2faff", "#bcd9ef", "#7fb4d9")
rounded("btn_stone_hover", "#e6f4fe", "#f8fcff", "#c8e2f4", "#7fb4d9")
rounded("btn_stone_pressed", "#cfe6f8", "#bcd9ef", "#f2faff", "#7fb4d9")
# CTA 按钮（暖黄）三态
rounded("btn_gold_normal", "#ffcc4d", "#ffe08a", "#e9b23a", "#a87b1a")
rounded("btn_gold_hover", "#ffd766", "#ffe9a5", "#f0bd48", "#a87b1a")
rounded("btn_gold_pressed", "#f5c043", "#e9b23a", "#ffe08a", "#a87b1a")
# 弱化按钮（灰蓝）三态
rounded("btn_dark_normal", "#cfdde9", "#e2edf5", "#b7c9d9", "#8aa4ba")
rounded("btn_dark_hover", "#d9e6f0", "#ecf4fa", "#c2d3e2", "#8aa4ba")
rounded("btn_dark_pressed", "#c3d3e1", "#b7c9d9", "#e2edf5", "#8aa4ba")
# 容器面板（白卡）/ 凹槽面板
rounded("panel_stone", "#ffffff", "#ffffff", "#eef6fc", "#a9d3ee", w=64, h=64, r=16, e=2, b=2)
rounded("panel_inset", "#ddeefb", "#d2e6f6", "#eaf5fd", "#a9d3ee", w=64, h=64, r=16, e=2, b=2)

# —— 主菜单背景：天空 → 草地渐变 + 淡云（750×1334 竖屏基准）——
W, H = 750, 1334
bg = Image.new("RGBA", (W, H))
top, mid, bot = hx("#bfe3fb"), hx("#eaf6ff"), hx("#d6efc9")
for y in range(H):
    t = y / (H - 1)
    if t < 0.62:
        k = t / 0.62
        c = tuple(int(top[i] + (mid[i] - top[i]) * k) for i in range(3))
    else:
        k = (t - 0.62) / 0.38
        c = tuple(int(mid[i] + (bot[i] - mid[i]) * k) for i in range(3))
    ImageDraw.Draw(bg).line([(0, y), (W, y)], fill=c + (255,))
d = ImageDraw.Draw(bg)
for cx, cy, s in [(140, 180, 70), (560, 120, 55), (380, 300, 45), (650, 420, 60), (90, 480, 50)]:
    for ox, oy, rr in [(0, 0, s), (int(s * 0.8), int(s * 0.25), int(s * 0.75)),
                       (-int(s * 0.7), int(s * 0.3), int(s * 0.65))]:
        d.ellipse([cx + ox - rr, cy + oy - rr // 2, cx + ox + rr, cy + oy + rr // 2],
                  fill=(255, 255, 255, 200))
bg.save(f"{OUT}/menu_bg.png")
print("assets/ui regenerated (Sky Meadow rounded set + gradient bg)")
