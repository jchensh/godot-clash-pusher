"""幺蛾子（lava_hound_body，大型空军；幼蛾子复用）：奶油色毛绒大蛾子，四片灰褐花纹翅，羽状触角，腰系麻绳，手持长矛。
原画：testAssets/新风格美术资源0830/动作/幺蛾子/幺蛾子.png；翅膀背面花纹为补全设计。
"""
import motions

FLUFF = "#f4e6cf"
FLUFF_D = "#dcc7a6"
WING = "#a99a8a"
WING_D = "#6f6255"
WING_L = "#d9cdbd"
ROPE = "#b48a56"
WOOD = "#7a4a26"
STEEL = "#c9d1d8"
EYE = "#1d1612"


def build(k):
    k.bone("body", (0, 0, 0.1), 0.5)
    k.bone("head", (0, -0.02, 0.85), 0.3, "body")
    k.bone("wing.L", (0.25, 0.15, 0.85), 0.15, "body")
    k.bone("wing.R", (-0.25, 0.15, 0.85), 0.15, "body")
    k.bone("spear", (-0.38, -0.15, 0.55), 0.2, "body")
    # 毛绒身体：几团重叠的绒球 + 麻绳腰带 + 小脚
    k.sphere("body", (0, 0, 0.55), 0.38, FLUFF, scale=(1.0, 0.9, 1.1))
    for x, z, r in ((-0.22, 0.75, 0.16), (0.22, 0.75, 0.16), (0, 0.28, 0.24), (-0.18, 0.4, 0.15), (0.18, 0.4, 0.15)):
        k.sphere("body", (x, -0.05, z), r, FLUFF_D if z < 0.5 else FLUFF)
    k.torus("body", (0, 0, 0.45), 0.33, 0.03, ROPE, seg=18, ring=5, scale=(1, 0.92, 1))
    k.sphere("body", (0.12, -0.31, 0.43), 0.05, ROPE)
    for x in (-1, 1):
        k.sphere("body", (0.12 * x, -0.1, 0.12), 0.08, FLUFF_D, scale=(1, 1.2, 0.7))
    # 头：大绒头 + 黑眼 + 腮红 + 羽状触角
    k.sphere("head", (0, -0.05, 1.05), 0.3, FLUFF)
    for x in (-1, 1):
        k.sphere("head", (0.11 * x, -0.31, 1.06), 0.05, EYE, scale=(0.8, 0.5, 1.2))
        k.sphere("head", (0.125 * x - 0.012, -0.34, 1.09), 0.016, "#ffffff")
        k.sphere("head", (0.19 * x, -0.27, 0.97), 0.045, "#ffa7bd", scale=(1, 0.3, 0.6))
        k.tube("head", [(0.1 * x, -0.1, 1.3), (0.22 * x, -0.15, 1.5), (0.3 * x, -0.12, 1.62)], 0.02, FLUFF_D)
        for i in range(4):
            t = 0.25 + i * 0.22
            k.sphere("head", (0.1 * x + 0.2 * x * t, -0.1 - 0.05 * t, 1.3 + 0.3 * t), 0.05, FLUFF_D,
                     scale=(1.4, 0.4, 0.5), rot=(0, -40 * x, 0))
    k.sphere("head", (0, -0.335, 0.98), 0.02, EYE, scale=(1.4, 0.5, 0.6))
    # 四片翅：上大下小，扁椭球 + 深色圆斑
    for side, bone in ((1, "wing.L"), (-1, "wing.R")):
        k.sphere(bone, (0.55 * side, 0.2, 1.05), 0.42, WING, scale=(1.0, 0.08, 0.75), rot=(0, -side * 22, 0))
        k.sphere(bone, (0.45 * side, 0.2, 0.62), 0.3, WING_L, scale=(1.0, 0.08, 0.8), rot=(0, side * 25, 0))
        k.sphere(bone, (0.62 * side, 0.18, 1.1), 0.09, WING_D, scale=(1, 0.3, 1))
        k.sphere(bone, (0.42 * side, 0.18, 0.95), 0.06, WING_D, scale=(1, 0.3, 1))
        k.sphere(bone, (0.48 * side, 0.18, 0.58), 0.06, WING_D, scale=(1, 0.3, 1))
    # 长矛（右手竖持）+ 握矛的小手
    k.tube("spear", [(-0.38, -0.15, 0.1), (-0.38, -0.15, 1.55)], 0.025, WOOD)
    k.cyl("spear", (-0.38, -0.15, 1.65), 0.05, 0.0, 0.2, STEEL, seg=4, smooth=False)
    k.sphere("spear", (-0.36, -0.15, 0.62), 0.07, FLUFF_D)

    idle = k.clip("Idle", 40, True)
    motions.flap(idle, amp=14.0, cycles=1)
    motions.hover(idle, bob=0.06)
    idle.wave("head", "rot", 1, 4.0, samples=6)
    fly = k.clip("Walk", 30, True)
    motions.flap(fly, amp=22.0, cycles=2)
    motions.hover(fly, bob=0.05, tilt=8.0)
    atk = k.clip("Attack", 30, False)
    motions.flap(atk, amp=18.0, cycles=2)
    atk.key(0, "spear", rot=(0, 0, 0), loc=(0, 0, 0)).key(10, "spear", rot=(-10, 0, 0), loc=(0, 0.1, 0.05))
    atk.key(14, "spear", rot=(40, 0, 0), loc=(0, -0.2, -0.1)).key(30, "spear", rot=(0, 0, 0), loc=(0, 0, 0))
    atk.key(0, "body", rot=(0, 0, 0)).key(14, "body", rot=(12, 0, 0)).key(30, "body", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, flier=True, fall=60.0, limbs=("wing.L", "wing.R"))
