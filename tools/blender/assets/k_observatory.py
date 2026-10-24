"""王国·天文台（stoneworks 槽，顶替科研所）：奶白圆楼（蓝色腰带）+ 蓝色星点圆顶 + 顶上金框罗盘大轮 + 侧边望远镜。
原画：assets/kingdom_cartoon/stoneworks.png；侧背面为补全设计。
"""
import math

import kbits as kb

B = kb.B
NAVY = "#2b4e9c"


def build(k):
    kb.base_plate(k, 3.4, 3.2, kb.STONE_D)
    k.cyl(B, (0, 0.1, 0.8), 1.35, 1.4, 1.3, kb.CREAM, seg=18)
    for z in (0.35, 1.25):
        k.cyl(B, (0, 0.1, z), 1.42, 1.42, 0.16, NAVY, seg=18)
    k.sphere(B, (0, 0.1, 1.45), 1.38, NAVY, scale=(1.0, 1.0, 0.75), seg=18, rings=10)
    for (x, y, z) in ((-0.6, -0.9, 1.9), (0.5, -1.0, 1.8), (0.0, -0.5, 2.35), (-1.0, 0.0, 2.0), (0.95, 0.3, 2.1)):
        kb.star(k, x, y - 0.12, z, 0.14, kb.GOLD)
    # 罗盘大轮：金色外圈 + 白盘 + 四向指针
    cx, cy, cz = -0.2, 0.25, 2.75
    k.torus(B, (cx, cy, cz), 1.05, 0.13, kb.GOLD, rot=(80, 0, 0), seg=28, ring=8)
    k.cyl(B, (cx, cy, cz), 0.95, 0.95, 0.08, "#eef3fb", rot=(80, 0, 0), seg=24)
    k.cyl(B, (cx, cy - 0.02, cz), 0.6, 0.6, 0.1, "#5ca0d8", rot=(80, 0, 0), seg=20)
    for a in (0, 90, 180, 270):
        r = math.radians(a)
        k.cyl(B, (cx + math.sin(r) * 0.42, cy - 0.06, cz + math.cos(r) * 0.42 * 0.98), 0.12, 0.0, 0.85,
              "#c8a46a", rot=(0, a, 0), seg=4, smooth=False, scale=(1.0, 0.35, 1.0))
    k.sphere(B, (cx, cy - 0.1, cz), 0.14, kb.GOLD)
    for side in (-1, 1):
        k.box(B, (cx + side * 1.05, cy, 2.0), (0.12, 0.12, 1.2), kb.GOLD_D, bevel=0.3)
    # 侧边望远镜
    k.cyl(B, (-1.3, -0.4, 1.3), 0.17, 0.24, 0.8, kb.GOLD_D, rot=(70, 0, -30), seg=10)
    k.cyl(B, (-1.45, -0.7, 1.45), 0.2, 0.2, 0.06, "#f0e0a0", rot=(70, 0, -30), seg=10)
    kb.door(k, 0, -1.28, 0.16, 0.6, 0.9, color=kb.WOOD_D, frame=kb.CREAM_D)
    kb.window(k, -0.8, -1.05, 0.85, 0.22, 0.3, glass=NAVY)
    kb.window(k, 0.8, -1.05, 0.85, 0.22, 0.3, glass=NAVY)
    kb.bush(k, 1.35, -1.1, 0.26)
