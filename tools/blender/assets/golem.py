"""岩石史莱姆（golem_body，大型）：灰色石质圆顶史莱姆，头顶几簇石刺，右持短剑、左持木圆盾；死亡裂成小岩史莱姆（逻辑层）。
原画：testAssets/新风格美术资源0830/动作/岩石史莱姆/岩石史莱姆.png；背面石刺为补全设计。
"""
import slimes

STONE = "#9aa1a8"
STONE_D = "#737a82"
SPIKE = "#5f656c"
STEEL = "#d3d9de"
WOOD = "#9a6a3c"
RIM = "#7c838a"


def build(k):
    k.bone("body", (0, 0, 0.05), 0.5)
    k.bone("sword", (-0.6, -0.1, 0.35), 0.15, "body")
    k.bone("shield", (0.6, -0.1, 0.35), 0.15, "body")
    slimes.blob(k, 0.55, STONE, STONE_D, height=0.78)
    for x, y, z, r, tilt in ((-0.15, 0.05, 0.84, 0.13, -15), (0.12, 0.12, 0.86, 0.15, 12), (0.3, -0.02, 0.74, 0.1, 30),
                             (-0.32, 0.1, 0.74, 0.1, -30), (0.0, 0.3, 0.72, 0.12, 0)):
        k.cyl("body", (x, y, z), r, 0.0, r * 2.2, SPIKE, rot=(tilt * 0.3, tilt, 0), seg=5, smooth=False)
    for x, y, z in ((0.32, -0.38, 0.5), (-0.38, -0.3, 0.3), (0.2, 0.42, 0.45)):
        k.sphere("body", (x, y, z), 0.07, STONE_D, scale=(1, 0.4, 0.7))
    # 短剑（右）
    k.box("sword", (-0.62, -0.12, 0.62), (0.07, 0.03, 0.46), STEEL, bevel=0.3)
    k.cyl("sword", (-0.62, -0.12, 0.88), 0.035, 0.0, 0.08, STEEL, seg=4, smooth=False, scale=(1, 0.4, 1))
    k.box("sword", (-0.62, -0.12, 0.38), (0.2, 0.05, 0.05), "#c9a24a", bevel=0.3)
    k.box("sword", (-0.62, -0.12, 0.3), (0.05, 0.05, 0.13), "#5b3a24", bevel=0.3)
    # 木圆盾（左）
    k.cyl("shield", (0.6, -0.16, 0.42), 0.26, 0.26, 0.06, WOOD, rot=(90, 0, 20), seg=16)
    k.torus("shield", (0.6, -0.16, 0.42), 0.25, 0.025, RIM, rot=(90, 0, 20), seg=18, ring=4)
    k.sphere("shield", (0.585, -0.2, 0.42), 0.06, RIM)
    slimes.anims(k, weapon="sword", shield="shield", slow=1.3)
