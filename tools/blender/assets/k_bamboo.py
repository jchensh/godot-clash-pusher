"""王国·竹丛（点缀）：三根带节的嫩绿竹竿 + 少量竹叶，约 1.4 米高。原画：assets/kingdom_cartoon/bamboo.png。"""
import kbits as kb

B = kb.B
STALK = "#a8d35a"
NODE = "#7fae3e"


def build(k):
    for (x, y, h) in ((0.0, 0.0, 1.4), (0.22, 0.1, 1.1), (-0.18, 0.12, 0.95)):
        k.cyl(B, (x, y, h * 0.5), 0.07, 0.06, h, STALK, seg=8)
        z = 0.3
        while z < h:
            k.cyl(B, (x, y, z), 0.085, 0.085, 0.05, NODE, seg=8)
            z += 0.32
        k.sphere(B, (x + 0.12, y, h - 0.05), 0.1, kb.GREEN, scale=(1.6, 0.4, 0.5), rot=(0, -25, 0))
