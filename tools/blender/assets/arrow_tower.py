"""箭塔 / 公主塔（3×3 格占位）：石砌底座 + 木构瞭望层（四角立柱 + 栏杆）+ 四坡尖顶；阵营色部件 = 屋顶与檐口。
原画：testAssets/新风格美术资源0830/战斗/箭塔.png（红顶为敌方配色，蓝顶由运行时染色）；背面为补全设计。
"""

STONE = "#ddd5c4"
STONE_D = "#bdb3a0"
STONE_DD = "#9c927f"
WOOD = "#c08a52"
WOOD_D = "#7d5230"
DARK = "#4a3423"
TEAM = "#ffffff"


def build(k):
    b = "root"
    k.box(b, (0, 0, 0.12), (2.9, 2.9, 0.24), STONE_DD, bevel=0.3)
    k.box(b, (0, 0, 0.85), (2.5, 2.5, 1.3), STONE, bevel=0.08)
    for x in (-1, 1):
        for y in (-1, 1):
            k.box(b, (1.15 * x, 1.15 * y, 0.95), (0.5, 0.5, 1.5), STONE_D, bevel=0.15)
    for face in ((0, -1.26), (0, 1.26), (-1.26, 0), (1.26, 0)):
        sx, sy = (0.7, 0.1) if face[0] == 0 else (0.1, 0.7)
        k.box(b, (face[0], face[1], 0.75), (sx, sy, 0.3), STONE_D, bevel=0.2)
    # 木构瞭望层：地板 + 四角立柱 + 栏杆 + 正面箭窗
    k.box(b, (0, 0, 1.6), (2.6, 2.6, 0.16), WOOD, bevel=0.2)
    for x in (-1, 1):
        for y in (-1, 1):
            k.box(b, (1.05 * x, 1.05 * y, 2.15), (0.24, 0.24, 1.0), WOOD_D, bevel=0.15)
    for z in (1.85, 2.15):
        for y in (-1.08, 1.08):
            k.box(b, (0, y, z), (2.1, 0.1, 0.1), WOOD, bevel=0.2)
        for x in (-1.08, 1.08):
            k.box(b, (x, 0, z), (0.1, 2.1, 0.1), WOOD, bevel=0.2)
    k.box(b, (0, 0, 2.05), (1.7, 1.7, 0.75), "#e7d8b8", bevel=0.05)
    k.box(b, (0, -0.86, 2.1), (0.4, 0.05, 0.4), DARK, bevel=0.1)
    # 屋顶（阵营色）：檐口 + 四坡尖顶 + 顶尖
    k.box(b, (0, 0, 2.72), (2.9, 2.9, 0.16), TEAM, bevel=0.25, tag="team")
    k.cyl(b, (0, 0, 3.35), 2.05, 0.0, 1.15, TEAM, rot=(0, 0, 45), seg=4, smooth=False, tag="team")
    k.sphere(b, (0, 0, 3.98), 0.1, "#f6c343")
