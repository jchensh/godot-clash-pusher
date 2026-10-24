"""王国·粮仓（granary）：石木圆基 + 奶白墙 + 蓝色大圆顶（木脊条）+ 顶上木烟囱 + 拱门 + 两侧木桶/粮袋。
原画：assets/kingdom_cartoon/granary.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B


def build(k):
    kb.base_plate(k, 3.6, 3.3, kb.STONE_D)
    k.cyl(B, (0, 0, 0.45), 1.5, 1.55, 0.6, kb.WOOD, seg=16)
    for i in range(8):
        import math
        a = math.radians(i * 45 + 22.5)
        k.box(B, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0.45), (0.5, 0.5, 0.65), kb.WOOD_D, rot=(0, 0, i * 45 + 22.5),
              bevel=0.25)
    k.cyl(B, (0, 0, 1.15), 1.3, 1.35, 0.9, kb.CREAM, seg=16)
    k.sphere(B, (0, 0, 1.55), 1.42, kb.BLUE, scale=(1.0, 1.0, 0.9), seg=18, rings=10)
    for a in (0, 45, 90, 135):
        kb.dome_rib(k, 0, 0, 1.55, 1.44, 0.9, a, kb.WOOD_D, thick=0.06)
    k.cyl(B, (0, 0, 2.95), 0.3, 0.35, 0.5, kb.WOOD, seg=10)
    k.cyl(B, (0, 0, 3.25), 0.4, 0.4, 0.12, kb.WOOD_D, seg=10)
    # 正面门廊
    k.box(B, (0, -1.25, 0.85), (1.0, 0.4, 1.3), kb.CREAM, bevel=0.1)
    kb.gable(k, 0, -1.25, 1.5, 0.6, 1.25, 0.5, kb.BLUE_D, axis="y")
    kb.door(k, 0, -1.47, 0.18, 0.6, 1.0, color=kb.RED, frame=kb.WOOD_D)
    for (x, y) in ((-1.45, -1.05), (-1.1, -1.35), (1.35, -1.15)):
        kb.barrel(k, x, y)
    kb.sack(k, 1.05, -1.4)
    kb.sack(k, 1.55, -0.75)
