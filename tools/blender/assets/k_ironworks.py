"""王国·铁匠铺（ironworks）：红墙工坊 + 灰石板厚屋顶 + 高烟囱（金色箍）+ 正面熔炉口（火光）+ 铁砧与工具桶。
原画：assets/kingdom_cartoon/ironworks.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B
REDW = "#d64a3a"
SLATE = "#7f8aa3"
SLATE_D = "#636d85"
FIRE = "#ffb02e"
FIRE_D = "#ff6a1f"
IRON = "#5d6470"


def build(k):
    kb.base_plate(k, 3.3, 3.0, kb.STONE_D)
    k.box(B, (0, 0.1, 0.95), (2.4, 2.0, 1.6), REDW, bevel=0.06)
    k.box(B, (0, 0.1, 1.95), (2.7, 2.3, 0.45), SLATE, bevel=0.15)
    k.box(B, (0, 0.1, 2.3), (2.2, 1.8, 0.35), SLATE_D, bevel=0.2)
    k.box(B, (0.0, -0.95, 2.05), (0.6, 0.15, 0.25), "#e7e2d6", bevel=0.3)
    # 烟囱
    k.cyl(B, (0.6, 0.4, 3.0), 0.32, 0.36, 1.6, IRON, seg=12)
    k.cyl(B, (0.6, 0.4, 3.0), 0.39, 0.39, 0.2, kb.GOLD, seg=12)
    k.cyl(B, (0.6, 0.4, 3.85), 0.42, 0.42, 0.14, SLATE_D, seg=12)
    # 熔炉：石拱 + 火光
    k.box(B, (0, -0.95, 0.6), (1.2, 0.3, 1.0), "#b4aea2", bevel=0.15)
    k.cyl(B, (0, -1.12, 0.65), 0.38, 0.38, 0.06, kb.DARK, rot=(90, 0, 0), seg=14)
    k.cyl(B, (0, -1.14, 0.6), 0.3, 0.3, 0.06, FIRE_D, rot=(90, 0, 0), seg=14)
    k.sphere(B, (0, -1.16, 0.52), 0.2, FIRE, scale=(1.0, 0.3, 1.2))
    # 铁砧 + 工具桶 + 水桶
    k.box(B, (-1.25, -1.1, 0.25), (0.35, 0.3, 0.35), IRON, bevel=0.2)
    k.box(B, (-1.25, -1.1, 0.5), (0.6, 0.3, 0.18), IRON, bevel=0.2)
    kb.barrel(k, 1.3, -1.15, 0.2, 0.4)
    k.box(B, (1.3, -1.15, 0.6), (0.06, 0.06, 0.5), kb.WOOD, rot=(0, 15, 0), bevel=0.2)
    k.box(B, (1.38, -1.1, 0.75), (0.25, 0.1, 0.12), IRON, rot=(0, 15, 0), bevel=0.2)
    k.cyl(B, (-1.35, -0.4, 0.25), 0.28, 0.24, 0.42, "#6e85a8", seg=12)
    kb.window(k, -0.8, -0.95, 1.25, 0.3, 0.3, glass="#f6d36b")
    kb.window(k, 0.8, -0.95, 1.25, 0.3, 0.3, glass="#f6d36b")
