"""王国·药剂坊（mint 槽，卖药剂产金币）：奶白小屋 + 绿色圆顶 + 背后巨型药瓶（青绿药水）+ 侧边烧瓶与导管 + 绿灌木。
原画：assets/kingdom_cartoon/mint.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B
GLASS_W = "#cfeee8"
POTION = "#3fae9a"
DOME = "#7fc458"


def build(k):
    kb.base_plate(k, 4.2, 3.0, kb.STONE_D)
    # 背后大药瓶
    k.sphere(B, (0, 0.55, 1.5), 1.2, GLASS_W, scale=(1.0, 1.0, 1.0), seg=18, rings=10)
    k.sphere(B, (0, 0.55, 1.25), 1.05, POTION, scale=(1.0, 1.0, 0.75), seg=16, rings=8)
    k.cyl(B, (0, 0.55, 2.85), 0.42, 0.42, 0.7, GLASS_W, seg=14)
    k.cyl(B, (0, 0.55, 3.25), 0.5, 0.5, 0.16, kb.STONE, seg=14)
    # 侧边烧瓶 + 导管
    k.cyl(B, (1.55, 0.6, 1.1), 0.5, 0.2, 1.6, GLASS_W, seg=12)
    k.cyl(B, (1.55, 0.6, 0.7), 0.45, 0.3, 0.6, POTION, seg=12)
    k.cyl(B, (1.55, 0.6, 2.0), 0.24, 0.24, 0.2, kb.STONE, seg=10)
    k.tube(B, [(-1.0, 0.5, 2.2), (-1.5, 0.4, 2.4), (-1.75, 0.2, 1.6)], 0.09, "#b9a8d6")
    k.tube(B, [(1.0, 0.55, 2.3), (1.4, 0.6, 2.4)], 0.08, "#b9a8d6")
    # 前屋：奶白墙 + 绿圆顶 + 拱门
    k.box(B, (0, -0.55, 0.75), (2.0, 1.4, 1.2), kb.CREAM, bevel=0.1)
    k.sphere(B, (0, -0.55, 1.35), 1.1, DOME, scale=(1.0, 0.7, 0.55), seg=16, rings=8)
    k.box(B, (0, -0.6, 1.85), (0.16, 0.16, 0.25), kb.GOLD, bevel=0.3)
    k.sphere(B, (0, -0.6, 2.05), 0.14, kb.GOLD)
    kb.door(k, 0, -1.25, 0.16, 0.6, 0.9, color=kb.RED, frame=kb.CREAM_D)
    kb.window(k, -0.65, -1.25, 0.95, 0.26, 0.3)
    kb.window(k, 0.65, -1.25, 0.95, 0.26, 0.3)
    # 灌木 + 木桶
    for (x, y, r) in ((-1.6, -0.6, 0.45), (-1.35, -1.15, 0.32), (1.5, -0.95, 0.38)):
        kb.bush(k, x, y, r, color=DOME)
    kb.barrel(k, -1.0, -1.25, 0.18, 0.36)
