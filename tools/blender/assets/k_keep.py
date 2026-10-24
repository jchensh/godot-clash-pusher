"""王国·王城（keep）：奶白宫殿 + 中央蓝色大穹顶 + 金色王冠顶饰 + 左右蓝顶圆塔 + 正面金拱门廊与紫门。
原画：assets/kingdom_cartoon/keep.png（3/4 俯视正面）；侧背面为补全设计。原点在占地底面中心，正面朝 -Y。
"""
import kbits as kb

B = kb.B
PURPLE = "#6a4fb8"


def build(k):
    kb.base_plate(k, 5.4, 3.8, kb.STONE_D, 0.2)
    # 主殿 + 左右翼楼
    k.box(B, (0, 0.1, 1.35), (3.0, 2.6, 2.3), kb.CREAM, bevel=0.06)
    for x in (-1, 1):
        k.box(B, (1.95 * x, 0.3, 0.95), (1.3, 2.0, 1.5), kb.CREAM, bevel=0.08)
        kb.gable(k, 1.95 * x, 0.3, 1.7, 2.2, 1.5, 0.75, kb.BLUE, axis="y")
        kb.window(k, 1.95 * x, -0.7, 1.05, 0.38, 0.55)
    # 中央穹顶：鼓座 + 蓝穹 + 金色肋 + 王冠顶饰
    k.cyl(B, (0, 0.2, 2.75), 1.25, 1.25, 0.5, kb.CREAM_D, seg=18)
    k.cyl(B, (0, 0.2, 3.02), 1.35, 1.35, 0.1, kb.GOLD, seg=18)
    k.sphere(B, (0, 0.2, 3.05), 1.25, kb.BLUE, scale=(1.0, 1.0, 1.05), seg=20, rings=12)
    for a in (0, 60, 120):
        kb.dome_rib(k, 0, 0.2, 3.05, 1.27, 1.05, a, kb.GOLD, thick=0.05)
    k.cyl(B, (0, 0.2, 4.4), 0.32, 0.22, 0.3, kb.GOLD, seg=10)
    for i in range(5):
        import math
        a = math.radians(i * 72)
        k.cyl(B, (math.cos(a) * 0.26, 0.2 + math.sin(a) * 0.26, 4.68), 0.07, 0.0, 0.3, kb.GOLD, seg=6)
    k.sphere(B, (0, 0.2, 4.7), 0.12, "#fff1b0")
    # 正面门廊：金拱 + 紫门 + 星徽
    k.box(B, (0, -1.25, 1.0), (1.5, 0.35, 1.9), kb.CREAM, bevel=0.1)
    k.cyl(B, (0, -1.3, 1.95), 0.75, 0.75, 0.3, kb.GOLD, rot=(90, 0, 0), seg=16)
    k.cyl(B, (0, -1.36, 1.95), 0.55, 0.55, 0.3, kb.CREAM, rot=(90, 0, 0), seg=16)
    kb.door(k, 0, -1.43, 0.2, 0.8, 1.35, color=PURPLE, frame=kb.GOLD)
    kb.star(k, 0, -1.5, 1.98, 0.24, kb.GOLD)
    for x in (-0.85, 0.85):
        k.cyl(B, (x, -1.45, 1.0), 0.13, 0.13, 1.7, kb.CREAM_D, seg=10)
        k.sphere(B, (x, -1.45, 1.9), 0.17, kb.GOLD)
    for x in (-1.1, 1.1):
        kb.window(k, x, -1.2, 1.55, 0.36, 0.6)
    # 角塔
    for x in (-1, 1):
        kb.round_tower(k, 2.45 * x, -0.95, 0.42, 2.1, roof=kb.BLUE, roof_h=1.0)
        kb.window(k, 2.45 * x, -1.37, 1.4, 0.2, 0.32)
    # 台阶
    k.box(B, (0, -1.75, 0.12), (1.3, 0.5, 0.24), kb.STONE, bevel=0.2)
    kb.bush(k, -1.2, -1.75, 0.28)
    kb.bush(k, 1.25, -1.75, 0.28)
