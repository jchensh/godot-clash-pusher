"""王国·南瓜居民屋（大型装饰，无槽位）：橙色瓣状南瓜屋 + 绿藤柄 + 灰烟囱 + 双圆窗 + 木门 + 小南瓜。
原画：assets/kingdom_cartoon/resident.png；侧背面为补全设计。
"""
import math

import kbits as kb

B = kb.B
ORANGE = "#f08a2c"
ORANGE_D = "#d86f1c"


def build(k):
    k.box(B, (0, 0, 0.06), (3.3, 2.8, 0.12), kb.GRASS, bevel=0.35)
    for i in range(8):
        a = math.radians(i * 45)
        k.sphere(B, (math.cos(a) * 0.55, math.sin(a) * 0.5, 1.05), 0.95, ORANGE if i % 2 else ORANGE_D,
                 scale=(0.75, 0.75, 1.0), seg=14, rings=8)
    k.sphere(B, (0, 0, 1.1), 1.3, ORANGE, scale=(1.0, 0.95, 0.85), seg=18, rings=10)
    k.tube(B, [(0, 0, 2.05), (0.15, 0.05, 2.4), (0.4, 0.1, 2.55)], 0.12, "#6c8f3a", end_radius=0.07)
    k.sphere(B, (-0.45, 0.25, 2.1), 0.22, kb.GREEN, scale=(1.4, 0.8, 0.4))
    k.cyl(B, (0.8, 0.35, 2.05), 0.2, 0.2, 0.8, "#7b818c", seg=10)
    k.cyl(B, (0.8, 0.35, 2.47), 0.26, 0.26, 0.12, "#5f646d", seg=10)
    for x in (-0.6, 0.6):
        kb.round_window(k, x, -1.1, 1.2, 0.24, glass="#f6e3a0", frame=kb.WOOD_D)
        k.box(B, (x, -1.2, 1.2), (0.04, 0.03, 0.45), kb.WOOD_D, bevel=0)
    kb.door(k, 0, -1.2, 0.12, 0.55, 0.85, color=kb.WOOD, frame=kb.WOOD_D)
    for (x, y, r) in ((-1.3, -0.95, 0.24), (1.3, -0.9, 0.2), (1.4, 0.4, 0.18), (-1.45, 0.3, 0.2)):
        k.sphere(B, (x, y, r * 0.8), r, ORANGE, scale=(1.1, 1.1, 0.85))
        k.cyl(B, (x, y, r * 1.6), 0.03, 0.03, 0.12, "#6c8f3a", seg=6)
