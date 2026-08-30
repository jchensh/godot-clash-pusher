#!/usr/bin/env python3
"""王国「未建造空地」卡通版生成器（决策 49 P4 美术欠账 KAN-124，2026-08-30）。

背景：P3 王国换成拼接式卡通城建后，空地仍在用 0726 的 `assets/kingdom/kingdom_plot.png`
（灰石写实工地，粗糙吊臂+碎石），在高饱和粗描边的卡通件里非常突兀。

方案：程序化画一块「围起来的待建工地」——裸土地块 + 四角木桩 + 绳索 + 石料木料堆。
色值全部取自 0830 卡通城建素材本身（黄土路 #d8b460 / 栅栏木 #b46c24·#a86018 / 石灰 #848484），
保证与既有件同族；画法照 gen_ui_assets.py（4× 超采样 + 圆角 + 粗描边）。

⚠️ 高质量占位：美术出正式卡通空地后覆盖同名文件即可，代码零改。

用法： uv run --with pillow python tools/gen_kingdom_plot.py
产物（入 git）： assets/kingdom_cartoon/plot.png
"""
import os
import sys

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

OUT = "assets/kingdom_cartoon"
W, H = 140, 100
SS = 4      # 超采样倍率（圆角/斜线抗锯齿：大画布画完缩回）

# —— 色板：逐个取自 0830 卡通城建素材（见文件头）——
DIRT = (216, 180, 96, 255)          # 黄土（同 road.png 主色）
DIRT_DARK = (194, 156, 78, 255)     # 土色暗斑
LINE = (108, 68, 24, 255)           # 描边深褐（farm 暗木再压暗）
WOOD = (180, 108, 36, 255)          # 木桩（farm 栅栏色 #b46c24）
WOOD_TOP = (208, 146, 74, 255)      # 木桩顶面（受光）
ROPE = (232, 214, 170, 255)         # 麻绳
STONE = (132, 132, 132, 255)        # 石料（quarry 主灰）
STONE_TOP = (166, 166, 166, 255)


def s(v: float) -> int:
    return round(v * SS)


def rrect(d: ImageDraw.ImageDraw, box, r, fill, outline=None, w=0):
    d.rounded_rectangle(
        [s(box[0]), s(box[1]), s(box[2]), s(box[3])],
        radius=s(r), fill=fill, outline=outline, width=s(w) if w else 0,
    )


def ellipse(d: ImageDraw.ImageDraw, box, fill, outline=None, w=0):
    d.ellipse(
        [s(box[0]), s(box[1]), s(box[2]), s(box[3])],
        fill=fill, outline=outline, width=s(w) if w else 0,
    )


def main() -> None:
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # ① 地块：圆角裸土 + 粗描边（贴地椭圆感 → 用大圆角矩形压扁）
    rrect(d, (5, 30, 135, 95), 24, DIRT, LINE, 2.5)
    # ② 土色暗斑（手绘脏点，固定坐标保证确定性）
    for bx in ((26, 52, 60, 66), (74, 44, 112, 56), (48, 74, 90, 86)):
        ellipse(d, bx, DIRT_DARK)

    # ③ 四角木桩（顶面亮、柱身暗，描边同族）
    for px, py in ((14, 36), (118, 36), (10, 72), (122, 72)):
        rrect(d, (px, py - 20, px + 9, py + 4), 3, WOOD, LINE, 2)
        ellipse(d, (px - 0.5, py - 23, px + 9.5, py - 17), WOOD_TOP, LINE, 1.6)

    # ④ 麻绳：桩顶之间的下垂绳段（两段折线近似垂链）
    for a, b, sag in (((18, 17), (122, 17), 7), ((14, 53), (126, 53), 10)):
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5 + sag)
        d.line([s(a[0]), s(a[1]), s(mid[0]), s(mid[1])], fill=ROPE, width=s(2.2))
        d.line([s(mid[0]), s(mid[1]), s(b[0]), s(b[1])], fill=ROPE, width=s(2.2))

    # ⑤ 石料堆（左下）与木料堆（右下）——「材料已备，待开工」
    ellipse(d, (30, 76, 46, 88), STONE, LINE, 1.8)
    ellipse(d, (33, 72, 45, 81), STONE_TOP, LINE, 1.8)
    rrect(d, (92, 78, 118, 85), 3, WOOD, LINE, 1.8)
    rrect(d, (95, 72, 121, 79), 3, WOOD_TOP, LINE, 1.8)

    # ⑥ 零散碎石（打破大片裸土的平板感；固定坐标保确定性）
    for bx in ((58, 84, 64, 88), (70, 66, 75, 69.5), (100, 60, 105, 63.5), (44, 62, 48, 65)):
        ellipse(d, bx, STONE_TOP, LINE, 1.2)

    im = im.resize((W, H), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    dst = os.path.join(OUT, "plot.png")
    im.save(dst)
    opaque = sum(1 for p in im.get_flattened_data() if p[3] > 0)
    assert opaque > W * H * 0.3, f"产出几乎全透明（{opaque}px），画法有误"
    print(f"{dst}  {im.size}  不透明 {opaque} px  卡通版未建造空地")


if __name__ == "__main__":
    main()
