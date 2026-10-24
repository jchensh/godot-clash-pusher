"""猫炮手（bomber_body）：黑白奶牛猫戴护目镜，坐在木推车后操控一挺多管机炮；移动时车轮滚动，攻击时炮管旋转连射。
原画：testAssets/新风格美术资源0830/动作/猫炮手/猫炮手.png；车尾与猫背面为补全设计。
"""
import math

import motions

BLACK = "#2b2a2f"
WHITE = "#f4f1ea"
PINK = "#f2a3b5"
BRASS = "#d9a640"
LENS = "#7fd0e8"
WOOD = "#9a6a3c"
WOOD_D = "#6b4527"
IRON = "#5d646d"
IRON_D = "#3a3f46"
EYE = "#111111"


def build(k):
    k.bone("body", (0, 0, 0.05), 0.3)            # 推车
    k.bone("cat", (0, 0.18, 0.38), 0.3, "body")
    k.bone("head", (0, 0.16, 0.66), 0.2, "cat")
    k.bone("gun", (0, -0.12, 0.5), 0.15, "body")
    k.bone("wheel.L", (0.3, 0.0, 0.16), 0.1, "body")
    k.bone("wheel.R", (-0.3, 0.0, 0.16), 0.1, "body")

    # 推车：车板 + 两侧车轮
    k.box("body", (0, 0.02, 0.3), (0.5, 0.75, 0.14), WOOD, bevel=0.2)
    k.box("body", (0, 0.02, 0.24), (0.42, 0.68, 0.04), WOOD_D, bevel=0.2)
    for side, bone in ((1, "wheel.L"), (-1, "wheel.R")):
        k.cyl(bone, (0.3 * side, 0.0, 0.16), 0.16, 0.16, 0.07, WOOD_D, rot=(0, 90, 0), seg=14)
        k.cyl(bone, (0.335 * side, 0.0, 0.16), 0.05, 0.05, 0.03, IRON, rot=(0, 90, 0), seg=8)
        for a in (0, 60, 120):
            k.box(bone, (0.33 * side, 0.0, 0.16), (0.02, 0.27, 0.03), WOOD, rot=(a, 0, 0), bevel=0)
    # 机炮：炮座 + 6 管
    k.box("gun", (0, -0.05, 0.44), (0.18, 0.22, 0.14), IRON_D, bevel=0.2)
    for i in range(6):
        a = math.radians(i * 60)
        k.cyl("gun", (0.06 * math.cos(a), -0.36, 0.5 + 0.06 * math.sin(a)), 0.025, 0.025, 0.5, IRON,
              rot=(90, 0, 0), seg=8)
    k.torus("gun", (0, -0.55, 0.5), 0.085, 0.02, IRON_D, rot=(90, 0, 0), seg=12, ring=4)
    k.torus("gun", (0, -0.25, 0.5), 0.09, 0.025, BRASS, rot=(90, 0, 0), seg=12, ring=4)
    # 猫：圆身（黑背白肚）+ 头（白脸黑头顶、尖耳、护目镜）+ 扶炮的白爪
    k.sphere("cat", (0, 0.2, 0.5), 0.2, BLACK, scale=(1.0, 0.9, 1.0))
    k.sphere("cat", (0, 0.06, 0.48), 0.14, WHITE, scale=(1.0, 0.5, 1.0))
    for x in (-1, 1):
        k.sphere("cat", (0.12 * x, -0.05, 0.47), 0.05, WHITE)
    k.sphere("cat", (0.15, 0.36, 0.42), 0.04, BLACK, scale=(0.8, 2.0, 0.8))
    k.sphere("head", (0, 0.12, 0.78), 0.19, BLACK)
    k.sphere("head", (0, 0.0, 0.75), 0.14, WHITE, scale=(1.1, 0.6, 0.85))
    for x in (-1, 1):
        k.cyl("head", (0.12 * x, 0.14, 0.95), 0.07, 0.0, 0.13, BLACK, rot=(0, 20 * x, 0), seg=6)
        k.sphere("head", (0.06 * x, -0.07, 0.79), 0.028, EYE)
        k.torus("head", (0.07 * x, -0.0, 0.89), 0.045, 0.016, BRASS, rot=(70, 0, 0), seg=10, ring=4)
        k.sphere("head", (0.07 * x, -0.01, 0.89), 0.04, LENS, scale=(1, 0.4, 1))
    k.sphere("head", (0, -0.08, 0.73), 0.018, PINK)

    idle = k.clip("Idle", 50, True)
    motions.idle(idle, body="cat", extra=[("gun", "rot", 0, 1.5, 0.4)])
    walk = k.clip("Walk", 20, True)
    for f, a in ((0, 0), (5, -90), (10, -180), (15, -270), (20, -360)):
        walk.key(f, "wheel.L", rot=(a, 0, 0)).key(f, "wheel.R", rot=(a, 0, 0))
    walk.wave("body", "loc", 2, 0.015, period=10, samples=8)
    walk.wave("cat", "rot", 0, 4.0, samples=8)
    atk = k.clip("Attack", 24, False)   # 炮管连转 + 小幅后坐抖动
    for f, a in ((0, 0), (4, 60), (8, 180), (12, 300), (16, 420), (20, 480), (24, 480)):
        atk.key(f, "gun", rot=(0, a, 0), loc=(0, 0.025 if f in (8, 16) else 0.0, 0))
    atk.key(0, "cat", rot=(0, 0, 0)).key(8, "cat", rot=(-6, 0, 0)).key(24, "cat", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, body="body", head="head", fall=40.0, limbs=("cat",))
