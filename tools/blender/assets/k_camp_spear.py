"""王国·长枪营（camp_spear）：奶白营房 + 蓝色四坡顶（金饰 + 蓝旗）+ 金边盾徽 + 四角长枪 + 门口两具盔甲架。
原画：assets/kingdom_cartoon/camp_spear.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B
STEEL = "#aab6c8"
STEEL_D = "#7d8ba0"


def build(k):
    kb.base_plate(k, 3.6, 3.0, kb.STONE_D)
    k.box(B, (0, 0.2, 0.95), (2.4, 2.0, 1.6), kb.CREAM, bevel=0.06)
    k.box(B, (0, 0.2, 1.8), (2.7, 2.3, 0.14), kb.GOLD_D, bevel=0.2)
    k.cyl(B, (0, 0.2, 2.45), 1.95, 0.0, 1.3, kb.BLUE, rot=(0, 0, 45), seg=4, smooth=False)
    k.cyl(B, (0, -0.55, 2.2), 0.3, 0.0, 0.45, kb.GOLD, seg=6)
    kb.flag(k, 0, 0.2, 3.05, 0.8, color=kb.BLUE)
    kb.shield(k, 0, -0.81, 1.25, 0.65, field="#7ec4f0", emblem="#eef8ff")
    kb.door(k, 0, -0.82, 0.16, 0.55, 0.62, color=kb.WOOD_D, frame=kb.WOOD)
    # 四角长枪
    for (x, y) in ((-1.45, -0.95), (1.45, -0.95), (-1.45, 1.2), (1.45, 1.2)):
        k.tube(B, [(x, y, 0.15), (x, y, 2.4)], 0.04, kb.WOOD_D)
        k.cyl(B, (x, y, 2.55), 0.1, 0.0, 0.35, STEEL, seg=4, smooth=False)
    # 盔甲架（门口两侧）
    for x in (-0.95, 0.95):
        k.cyl(B, (x, -1.1, 0.25), 0.22, 0.25, 0.12, kb.WOOD_D, seg=10)
        k.box(B, (x, -1.1, 0.75), (0.45, 0.3, 0.6), STEEL, bevel=0.35)
        k.box(B, (x, -1.1, 0.8), (0.1, 0.32, 0.5), kb.WOOD, bevel=0.3)
        k.sphere(B, (x, -1.1, 1.22), 0.2, STEEL_D)
        k.box(B, (x, -1.25, 1.2), (0.22, 0.05, 0.06), "#2b2f36", bevel=0.3)
