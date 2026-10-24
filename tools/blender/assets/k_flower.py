"""王国·小花（点缀）：绿茎 + 两片叶 + 白瓣黄心花头，约 0.6 米高。原画：assets/kingdom_cartoon/flower1/2.png。"""
import math

import kbits as kb

B = kb.B


def build(k):
    k.tube(B, [(0, 0, 0), (0.02, 0, 0.3), (0, 0, 0.55)], 0.025, kb.GREEN_D)
    for s in (-1, 1):
        k.sphere(B, (0.1 * s, 0, 0.2), 0.1, kb.GREEN, scale=(1.4, 0.35, 0.6), rot=(0, 30 * s, 0))
    for i in range(6):
        a = math.radians(i * 60)
        k.sphere(B, (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.58), 0.08, "#fbfbf4", scale=(1.0, 1.0, 0.45))
    k.sphere(B, (0, 0, 0.6), 0.06, "#f6c343")
