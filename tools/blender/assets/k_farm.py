"""王国·农田（farm）：木栅栏围起的田块 + 三排麦苗 + 左后小风车 + 右后蓝顶谷仓 + 右前草垛。
原画：assets/kingdom_cartoon/farm.png；侧背面为补全设计。
"""
import kbits as kb

B = kb.B
SOIL = "#c79a52"
SOIL_D = "#a87c3c"
CROP = "#6fb84f"
HAY = "#f2c84b"


def build(k):
    k.box(B, (0, 0, 0.08), (4.4, 3.3, 0.16), kb.GRASS, bevel=0.3)
    k.box(B, (0, 0, 0.2), (4.0, 2.9, 0.12), SOIL, bevel=0.25)
    # 田垄 + 麦苗
    for row in (-0.9, 0.0, 0.9):
        k.box(B, (row - 0.5, -0.3, 0.29), (0.42, 2.0, 0.08), SOIL_D, bevel=0.3)
        for y in (-1.05, -0.55, -0.05, 0.45):
            k.cyl(B, (row - 0.5, y - 0.3, 0.55), 0.13, 0.02, 0.55, CROP, seg=5, smooth=False)
            k.cyl(B, (row - 0.5, y - 0.3, 0.78), 0.07, 0.0, 0.22, "#e2c35a", seg=5, smooth=False)
    kb.fence(k, -2.0, 2.0, -1.45, 1.45, h=0.5, step=0.75, gap=("s", 0.9, 0.7))
    # 风车（左后）
    k.cyl(B, (-1.5, 1.0, 0.95), 0.38, 0.28, 1.5, kb.CREAM, seg=10)
    kb.spire(k, -1.5, 1.0, 1.7, 0.42, 0.55, kb.WOOD_D)
    k.cyl(B, (-1.5, 0.6, 1.6), 0.09, 0.09, 0.2, kb.WOOD_D, rot=(90, 0, 0), seg=8)
    for a in (45, 135):
        k.box(B, (-1.5, 0.5, 1.6), (1.6, 0.05, 0.22), HAY, rot=(0, a, 0), bevel=0.2)
    kb.door(k, -1.5, 0.68, 0.25, 0.3, 0.5)
    # 谷仓（右后）
    k.box(B, (1.25, 0.85, 0.75), (1.2, 1.0, 1.1), kb.CREAM, bevel=0.08)
    kb.gable(k, 1.25, 0.85, 1.3, 1.1, 1.4, 0.65, kb.BLUE, axis="y")
    kb.door(k, 1.25, 0.35, 0.25, 0.45, 0.7, color=kb.WOOD)
    # 草垛（右前）
    k.sphere(B, (1.35, -0.75, 0.45), 0.42, HAY, scale=(1.2, 1.0, 0.75))
    k.sphere(B, (1.0, -0.95, 0.35), 0.3, "#e6b93c", scale=(1.1, 1.0, 0.7))
