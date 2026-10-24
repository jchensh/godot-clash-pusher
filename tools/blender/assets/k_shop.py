"""王国·晶石商店（shop）：粉白蛋形小屋（粉色波纹）+ 顶上大青晶与紫粉小晶簇 + 拱门 + 门口纸杯蛋糕摊。
原画：assets/kingdom_cartoon/shop.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B
SHELL = "#fbeff2"
PINK = "#f39abb"
PINK_D = "#e0789f"
CYAN = "#6fe0ef"
VIOLET = "#a993ef"


def build(k):
    kb.base_plate(k, 3.5, 3.0, "#e9c97d")
    k.sphere(B, (0, 0.1, 1.2), 1.35, SHELL, scale=(1.0, 0.95, 1.05), seg=18, rings=12)
    for z, s in ((0.85, 1.36), (1.55, 1.25)):
        k.torus(B, (0, 0.1, z), s, 0.05, PINK, rot=(0, 0, 0), seg=24, ring=6)
    for (x, y, z, r) in ((-0.7, -0.95, 1.9, 0.2), (0.75, -0.9, 1.7, 0.18), (-1.0, 0.3, 1.5, 0.2)):
        k.sphere(B, (x, y, z), r, PINK_D, scale=(1.0, 0.5, 1.0))
    # 晶簇
    k.cyl(B, (0, 0.1, 3.0), 0.42, 0.0, 1.5, CYAN, seg=6, smooth=False)
    k.cyl(B, (0, 0.1, 2.35), 0.3, 0.42, 0.3, CYAN, seg=6, smooth=False)
    for (x, y, a, c, h) in ((-0.45, 0.0, -25, VIOLET, 0.9), (0.45, 0.15, 25, PINK, 0.85), (0.1, 0.55, 10, VIOLET, 0.7),
                            (-0.2, -0.35, -10, PINK, 0.6)):
        k.cyl(B, (x, y, 2.55), 0.18, 0.0, h, c, rot=(0, a, 0), seg=5, smooth=False)
    # 门 + 窗
    kb.door(k, 0, -1.2, 0.2, 0.6, 0.95, color=PINK_D, frame=kb.CREAM_D)
    kb.round_window(k, -0.75, -1.0, 1.1, 0.18, glass="#3b5fa6", frame=PINK)
    kb.round_window(k, 0.75, -1.0, 1.1, 0.18, glass="#3b5fa6", frame=PINK)
    # 纸杯蛋糕摊
    for (x, y, c) in ((-1.3, -1.0, PINK), (1.35, -0.95, VIOLET), (-1.5, 0.15, PINK)):
        k.cyl(B, (x, y, 0.32), 0.24, 0.18, 0.32, kb.WOOD, seg=10)
        k.sphere(B, (x, y, 0.55), 0.24, c, scale=(1.0, 1.0, 0.8))
        k.sphere(B, (x, y, 0.75), 0.07, kb.RED)
