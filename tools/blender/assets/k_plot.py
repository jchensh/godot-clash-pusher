"""王国·空地（未建造槽位）：圆角沙土地块 + 四角木桩 + 拉绳 + 几块石头与木板。
原画：assets/kingdom_cartoon/plot.png；尺寸按通用槽位（运行时按槽缩放）。
"""
import kbits as kb

B = kb.B
SAND = "#e2bd6c"
SAND_D = "#c9a157"
ROPE = "#f3ead2"


def build(k):
    k.box(B, (0, 0, 0.07), (3.4, 2.4, 0.14), SAND_D, bevel=0.45)
    k.box(B, (0, 0, 0.12), (3.2, 2.2, 0.1), SAND, bevel=0.45)
    for (x, y, r) in ((-0.8, -0.3, 0.35), (0.6, 0.4, 0.45), (0.2, -0.6, 0.25)):
        k.sphere(B, (x, y, 0.17), r, SAND_D, scale=(1.0, 0.7, 0.08))
    pts = [(-1.45, -0.95), (1.45, -0.95), (1.45, 0.95), (-1.45, 0.95)]
    for (x, y) in pts:
        k.box(B, (x, y, 0.45), (0.14, 0.14, 0.75), kb.WOOD, bevel=0.25)
        k.box(B, (x, y, 0.84), (0.18, 0.18, 0.06), kb.WOOD_D, bevel=0.3)
    for i in range(4):
        a, b = pts[i], pts[(i + 1) % 4]
        k.tube(B, [(a[0], a[1], 0.7), ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, 0.6), (b[0], b[1], 0.7)], 0.02, ROPE)
    k.box(B, (0.9, -0.55, 0.22), (0.7, 0.18, 0.08), kb.WOOD, rot=(0, 0, 8), bevel=0.3)
    k.box(B, (0.95, -0.35, 0.22), (0.6, 0.16, 0.08), kb.WOOD_D, rot=(0, 0, -6), bevel=0.3)
    k.sphere(B, (-0.9, -0.5, 0.22), 0.14, kb.STONE_D, scale=(1.2, 1.0, 0.7))
    k.sphere(B, (-0.65, -0.62, 0.2), 0.1, kb.STONE, scale=(1.2, 1.0, 0.7))
