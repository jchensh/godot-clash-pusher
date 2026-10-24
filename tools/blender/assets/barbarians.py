"""棒槌史莱姆（barbarian_body）：绿色凶脸史莱姆，右手抡一根带铁刺的木狼牙棒。
原画：testAssets/新风格美术资源0830/动作/棒槌史莱姆/棒槌史莱姆.png；背面为补全设计。
"""
import slimes

GREEN = "#8fdc86"
GREEN_D = "#63b25d"
WOOD = "#7a4a26"
SPIKE = "#b7bec5"


def build(k):
    k.bone("body", (0, 0, 0.05), 0.4)
    k.bone("club", (-0.42, -0.06, 0.3), 0.15, "body")
    slimes.blob(k, 0.42, GREEN, GREEN_D, height=0.75, angry=True)
    k.tube("club", [(-0.43, -0.08, 0.18), (-0.47, -0.06, 0.55)], 0.035, WOOD)
    k.cyl("club", (-0.5, -0.05, 0.75), 0.07, 0.13, 0.42, WOOD, rot=(0, 8, 0), seg=10)
    for i in range(8):
        z = 0.66 + (i % 3) * 0.09
        k.cyl("club", (-0.5, -0.05, z), 0.03, 0.0, 0.32, SPIKE, rot=(90, 0, i * 45), seg=4, smooth=False)
    slimes.anims(k, weapon="club", strike=-100.0)
