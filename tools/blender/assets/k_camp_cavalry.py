"""王国·骑兵营（camp_cavalry）：奶白营房 + 蓝色四坡顶（紫顶小尖塔 + 红旗）+ 盾徽 + 门口两匹披挂战马。
原画：assets/kingdom_cartoon/camp_cavalry.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B
HORSE = "#a8693e"
HORSE_D = "#7a4a2a"
CLOTH = "#e6e9f0"


def _horse(k, x, y, facing):
    k.box(B, (x, y, 0.62), (0.4, 0.75, 0.42), HORSE, bevel=0.4)
    k.box(B, (x, y, 0.62), (0.44, 0.6, 0.3), CLOTH, bevel=0.3)
    k.box(B, (x, y - 0.4 * facing, 0.95), (0.26, 0.28, 0.45), HORSE, rot=(-20 * facing, 0, 0), bevel=0.35)
    k.box(B, (x, y - 0.55 * facing, 1.15), (0.24, 0.35, 0.22), HORSE, bevel=0.35)
    k.box(B, (x, y - 0.33 * facing, 1.12), (0.06, 0.25, 0.25), HORSE_D, bevel=0.3)
    for dx in (-0.12, 0.12):
        k.cyl(B, (x + dx, y - 0.45 * facing, 1.32), 0.04, 0.0, 0.14, HORSE_D, seg=5)
    for (dx, dy) in ((-0.13, -0.25), (0.13, -0.25), (-0.13, 0.25), (0.13, 0.25)):
        k.cyl(B, (x + dx, y + dy, 0.22), 0.06, 0.05, 0.42, HORSE_D, seg=6)


def build(k):
    kb.base_plate(k, 3.6, 3.0, kb.STONE_D)
    k.box(B, (0, 0.3, 0.95), (2.2, 1.8, 1.6), kb.CREAM, bevel=0.06)
    k.box(B, (0, 0.3, 1.8), (2.5, 2.1, 0.14), kb.GOLD_D, bevel=0.2)
    k.cyl(B, (0, 0.3, 2.4), 1.8, 0.0, 1.2, kb.BLUE, rot=(0, 0, 45), seg=4, smooth=False)
    for x in (-1.2, 1.2):
        kb.spire(k, x, -0.5, 1.75, 0.16, 0.6, "#7b5ad0")
    kb.flag(k, 0, 0.3, 2.95, 0.85, color=kb.RED)
    kb.shield(k, 0, -0.61, 1.3, 0.62, field="#7ec4f0", emblem="#eef8ff")
    kb.door(k, 0, -0.62, 0.16, 0.55, 0.62, color=kb.WOOD_D, frame=kb.WOOD)
    _horse(k, -1.15, -0.85, 1)
    _horse(k, 1.15, -0.85, 1)
