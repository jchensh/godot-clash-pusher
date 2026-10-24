"""王国·魔法工坊（workshop 槽，顶替产木料）：橙砖圆屋 + 紫色大蘑菇伞盖（黄斑点、粉色伞褶）+ 圆窗 + 绿门 + 小蘑菇。
原画：assets/kingdom_cartoon/magic_lab.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B
BRICK = "#d9824a"
BRICK_D = "#b4633a"
CAP = "#8d6fd8"
CAP_L = "#b39af0"
PINK = "#f3a6c4"
SPOT = "#f5d77a"


def build(k):
    kb.base_plate(k, 3.2, 3.0, kb.STONE_D)
    k.cyl(B, (0, 0, 1.0), 1.05, 1.15, 1.7, BRICK, seg=16)
    k.cyl(B, (0, 0, 0.3), 1.2, 1.2, 0.35, BRICK_D, seg=16)
    k.cyl(B, (0, 0, 1.9), 1.15, 1.05, 0.25, kb.WOOD, seg=16)
    # 蘑菇伞盖：粉色伞褶 + 紫盖 + 斑点 + 顶上小芽
    k.cyl(B, (0, 0, 2.1), 1.55, 1.2, 0.18, PINK, seg=18)
    k.sphere(B, (0, 0, 2.2), 1.6, CAP, scale=(1.0, 1.0, 0.62), seg=20, rings=10)
    k.sphere(B, (-0.2, -0.1, 2.85), 0.75, CAP_L, scale=(1.0, 1.0, 0.5))
    for (x, y, r) in ((-0.8, -0.85, 0.2), (0.65, -0.95, 0.22), (0.25, -0.35, 0.17), (-1.2, 0.15, 0.17),
                      (1.15, 0.35, 0.19), (0.0, 0.95, 0.2), (-0.55, 0.5, 0.15)):
        k.sphere(B, (x, y, kb.on_dome(0, 0, 2.2, 1.6, 0.62, x, y, -0.02)), r, SPOT, scale=(1.0, 1.0, 0.5))
    k.tube(B, [(0.6, -0.2, 3.0), (0.95, -0.35, 3.45)], 0.05, kb.GREEN_D)
    k.sphere(B, (1.0, -0.37, 3.5), 0.12, PINK)
    # 正面：圆窗 + 绿门 + 两侧小方窗
    kb.round_window(k, 0, -1.08, 1.45, 0.32, glass="#7fe0e0", frame=kb.WOOD_D)
    kb.door(k, 0, -1.12, 0.2, 0.55, 0.85, color="#8fd68a", frame=kb.WOOD)
    for x in (-0.75, 0.75):
        kb.window(k, x, -0.82, 0.9, 0.24, 0.3, glass="#3b5fa6", frame=kb.RED)
    # 小蘑菇
    for (x, y, s) in ((-1.25, -0.9, 0.35), (1.3, -0.8, 0.3), (1.35, 0.6, 0.25)):
        k.cyl(B, (x, y, s * 0.5), s * 0.35, s * 0.3, s, kb.CREAM, seg=8)
        k.sphere(B, (x, y, s), s * 0.75, CAP, scale=(1.0, 1.0, 0.6))
    kb.bush(k, -0.6, -1.35, 0.22, color=kb.GREEN)
