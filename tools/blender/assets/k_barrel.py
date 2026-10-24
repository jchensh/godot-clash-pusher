"""王国·木桶（点缀）：木板桶身 + 两道铁箍 + 顶盖，约 0.75 米高。原画：assets/kingdom_cartoon/barrel_wood.png。"""
import kbits as kb

B = kb.B


def build(k):
    k.cyl(B, (0, 0, 0.37), 0.34, 0.34, 0.74, kb.WOOD, seg=14)
    k.cyl(B, (0, 0, 0.37), 0.37, 0.37, 0.3, "#a06b3a", seg=14)
    for z in (0.12, 0.62):
        k.cyl(B, (0, 0, z), 0.375, 0.375, 0.06, "#6d6f75", seg=14)
    k.cyl(B, (0, 0, 0.75), 0.3, 0.3, 0.04, kb.WOOD_D, seg=14)
