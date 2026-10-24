"""王国·城墙角楼：米黄石砌方塔 + 城垛 + 正面绿色长旗（金横杆）。原画：assets/kingdom_cartoon/wall_d.png。"""
import kbits as kb

B = kb.B
SAND = "#e8d3a6"
SAND_D = "#cdb486"
SAND_L = "#f2e2bd"
BANNER = "#5fb24a"


def build(k):
    k.box(B, (0, 0, 0.15), (1.9, 1.9, 0.3), SAND_D, bevel=0.2)
    k.box(B, (0, 0, 1.25), (1.6, 1.6, 2.3), SAND, bevel=0.05)
    k.box(B, (0, 0, 2.45), (1.85, 1.85, 0.16), SAND_D, bevel=0.15)
    for x in (-0.6, 0.6):
        for y in (-0.6, 0.6):
            k.box(B, (x, y, 2.75), (0.5, 0.5, 0.45), SAND_L, bevel=0.15)
    for y in (-0.83, 0.83):
        k.box(B, (0, y, 2.05), (0.9, 0.06, 0.1), kb.GOLD_D, bevel=0.3)
        k.box(B, (0, y * 1.02, 1.5), (0.75, 0.05, 1.05), BANNER, bevel=0.1)
        k.cyl(B, (0, y * 1.02, 0.95), 0.38, 0.0, 0.32, BANNER, rot=(90 if y < 0 else -90, 0, 0), seg=3,
              smooth=False, scale=(1.0, 0.25, 1.0))
