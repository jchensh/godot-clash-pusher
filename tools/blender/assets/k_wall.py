"""王国·围墙段（4 米长，沿局部 X）：米黄石砌墙身 + 墙顶走道 + 城垛 + 砖缝点缀；运行时首尾相接铺满城墙线。
原画：assets/kingdom_cartoon/wall_a.png / wall_b.png；两端平齐以便拼接。
"""
import kbits as kb

B = kb.B
SAND = "#e8d3a6"
SAND_D = "#cdb486"
SAND_L = "#f2e2bd"


def build(k):
    k.box(B, (0, 0, 0.75), (4.0, 1.0, 1.5), SAND, bevel=0.02, seg=1)
    k.box(B, (0, 0, 0.1), (4.0, 1.12, 0.2), SAND_D, bevel=0.1)
    k.box(B, (0, 0, 1.55), (4.0, 1.15, 0.12), SAND_D, bevel=0.1)
    for x in (-1.5, -0.5, 0.5, 1.5):
        for y in (-0.42, 0.42):
            k.box(B, (x, y, 1.82), (0.55, 0.3, 0.42), SAND_L, bevel=0.15)
    for (x, z, w) in ((-1.4, 0.5, 0.9), (0.3, 0.95, 1.0), (1.3, 0.45, 0.7), (-0.6, 1.15, 0.6)):
        for y in (-0.51, 0.51):
            k.box(B, (x, y, z), (w, 0.04, 0.3), SAND_D, bevel=0.2)
