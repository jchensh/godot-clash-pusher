"""王国·魔法书院（camp_infantry 槽，顶替法师营）：高大奶白楼（蓝色包边）+ 正面蓝顶小门廊 + 左侧木梯 + 右侧挂灯 + 盆栽。
原画：assets/kingdom_cartoon/camp_infantry.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B


def build(k):
    kb.base_plate(k, 3.6, 2.8, kb.STONE_D)
    k.box(B, (0, 0.25, 1.35), (3.0, 1.8, 2.5), kb.CREAM, bevel=0.05)
    # 蓝色包边：顶沿 + 四角
    k.box(B, (0, 0.25, 2.65), (3.2, 2.0, 0.22), kb.BLUE, bevel=0.2)
    kb.gable(k, 0, 0.25, 2.74, 3.0, 1.9, 0.55, kb.BLUE_L, axis="x")
    for x in (-1.5, 1.5):
        for y in (-0.65, 1.15):
            k.box(B, (x, y, 1.35), (0.2, 0.2, 2.6), kb.BLUE, bevel=0.2)
    for x in (-1.2, -0.4, 0.4, 1.2):
        k.box(B, (x, -0.66, 2.6), (0.22, 0.12, 0.22), kb.GOLD_D, bevel=0.3)
    # 门廊
    k.box(B, (0.2, -0.9, 0.65), (1.2, 0.6, 1.0), kb.CREAM_D, bevel=0.1)
    kb.gable(k, 0.2, -0.9, 1.12, 0.9, 1.5, 0.6, kb.BLUE, axis="y")
    kb.door(k, 0.2, -1.21, 0.16, 0.55, 0.8, color=kb.WOOD_D, frame=kb.WOOD)
    # 木梯（左）
    for x in (-1.15, -0.8):
        k.box(B, (x, -0.72, 1.3), (0.08, 0.08, 2.4), kb.WOOD, rot=(-8, 0, 0), bevel=0.3)
    for z in (0.4, 0.8, 1.2, 1.6, 2.0):
        k.box(B, (-0.975, -0.72 - (z - 1.3) * 0.14, z), (0.4, 0.06, 0.06), kb.WOOD_D, bevel=0.3)
    # 挂灯（右）
    k.box(B, (1.55, -0.85, 1.2), (0.08, 0.08, 1.9), kb.WOOD_D, bevel=0.3)
    k.box(B, (1.38, -0.85, 2.1), (0.4, 0.06, 0.06), kb.WOOD_D, bevel=0.3)
    k.cyl(B, (1.22, -0.85, 1.85), 0.12, 0.14, 0.3, "#f6c65b", seg=8)
    k.cyl(B, (1.22, -0.85, 2.03), 0.16, 0.0, 0.12, kb.WOOD_D, seg=8)
    # 盆栽 + 箱子
    for (x, c) in ((-1.4, "#c58ae6"), (1.25, kb.GREEN)):
        k.cyl(B, (x, -1.1, 0.25), 0.2, 0.16, 0.3, "#c77d4a", seg=10)
        k.sphere(B, (x, -1.1, 0.5), 0.24, c)
    k.box(B, (-0.6, -1.15, 0.28), (0.45, 0.35, 0.32), "#8aa0b8", bevel=0.25)
