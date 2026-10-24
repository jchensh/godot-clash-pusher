"""王国·弩手营（camp_crossbow）：奶白营房 + 蓝色坡顶 + 屋顶红白箭靶（两侧麦穗饰）+ 两侧箭桶 + 前方矮石围栏。
原画：assets/kingdom_cartoon/camp_crossbow.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B


def build(k):
    kb.base_plate(k, 3.8, 2.9, kb.STONE_D)
    k.box(B, (0, 0.2, 0.85), (2.4, 1.8, 1.4), kb.CREAM, bevel=0.06)
    kb.gable(k, 0, 0.2, 1.55, 2.6, 2.1, 0.85, kb.BLUE, axis="x")
    k.box(B, (0, -0.72, 1.15), (1.2, 0.3, 0.9), kb.CREAM_D, bevel=0.1)
    kb.gable(k, 0, -0.75, 1.55, 0.8, 1.45, 0.55, kb.WOOD, axis="y")
    kb.door(k, 0, -0.88, 0.16, 0.5, 0.75, color=kb.WOOD_D, frame=kb.WOOD)
    # 箭靶
    k.box(B, (0, 0.35, 2.3), (0.08, 0.08, 0.8), kb.WOOD_D, bevel=0.3)
    for r, c in ((0.5, "#ffffff"), (0.38, kb.RED), (0.26, "#ffffff"), (0.14, kb.RED)):
        k.cyl(B, (0, 0.28 - (0.5 - r) * 0.06, 2.75), r, r, 0.06, c, rot=(90, 0, 0), seg=18)
    for x in (-1, 1):
        k.cyl(B, (0.75 * x, 0.3, 2.65), 0.12, 0.0, 0.6, "#f2c84b", rot=(0, -25 * x, 0), seg=6)
    # 箭桶
    for x in (-1.45, 1.45):
        kb.barrel(k, x, -0.75, 0.24, 0.5)
        for dx in (-0.08, 0.06):
            k.tube(B, [(x + dx, -0.75, 0.4), (x + dx * 3, -0.75, 1.05)], 0.025, kb.WOOD)
            k.cyl(B, (x + dx * 3, -0.75, 1.1), 0.07, 0.0, 0.12, kb.RED, seg=4, smooth=False)
    # 矮石围栏
    for x in (-1.6, -1.0, 1.0, 1.6):
        k.box(B, (x, -1.25, 0.18), (0.5, 0.25, 0.3), kb.STONE, bevel=0.3)
    kb.bush(k, 1.2, 1.0, 0.25)
