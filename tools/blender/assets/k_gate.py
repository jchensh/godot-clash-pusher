"""王国·城门（wall 槽）：两座奶白圆塔（蓝锥顶 + 蓝旗）夹石砌门楼，拱门木门 + 金边蓝盾徽，城垛。
原画：assets/kingdom_cartoon/gate.png；侧背面为补全设计。骑在南墙中央，左右与墙段衔接。
"""
import kbits as kb

B = kb.B
STONE_B = "#8d97ad"


def build(k):
    # 门楼
    k.box(B, (0, 0, 1.2), (3.2, 1.4, 2.4), kb.STONE, bevel=0.06)
    k.box(B, (0, 0, 2.5), (3.4, 1.55, 0.25), kb.STONE_D, bevel=0.2)
    for x in (-1.3, -0.45, 0.45, 1.3):
        k.box(B, (x, -0.55, 2.82), (0.45, 0.35, 0.4), kb.STONE, bevel=0.15)
        k.box(B, (x, 0.55, 2.82), (0.45, 0.35, 0.4), kb.STONE, bevel=0.15)
    # 门洞：石拱 + 木门
    k.cyl(B, (0, -0.72, 1.3), 0.95, 0.95, 0.12, STONE_B, rot=(90, 0, 0), seg=16)
    k.box(B, (0, -0.72, 0.65), (1.9, 0.12, 1.3), STONE_B, bevel=0.1)
    kb.door(k, 0, -0.78, 0.05, 1.45, 1.95, color=kb.WOOD, frame=STONE_B)
    for x in (-0.36, 0.36):
        k.box(B, (x, -0.92, 0.75), (0.05, 0.03, 1.3), kb.WOOD_D, bevel=0)
    kb.shield(k, 0, -0.8, 2.15, 0.62)
    # 两侧圆塔
    for x in (-1, 1):
        kb.round_tower(k, 2.05 * x, 0, 0.75, 2.9, roof=kb.BLUE, roof_h=1.35)
        kb.window(k, 2.05 * x, -0.74, 1.9, 0.26, 0.42, glass=kb.BLUE_D, frame=kb.STONE_D)
        kb.window(k, 2.05 * x, -0.74, 0.9, 0.26, 0.42, glass=kb.BLUE_D, frame=kb.STONE_D)
        kb.flag(k, 2.05 * x, 0, 4.35, 0.9, color=kb.BLUE)
    kb.bush(k, -2.9, -0.6, 0.3)
    kb.bush(k, 2.85, -0.55, 0.3)
