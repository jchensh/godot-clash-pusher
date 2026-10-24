"""蝴蝶仙子（ice_wizard_body）：浅棕发髻小仙女，绿叶裙，背后两对粉蓝渐变蝴蝶翅，头顶触角，手持紫花魔杖。
原画：testAssets/新风格美术资源0830/动作/蝴蝶仙子/蝴蝶仙子.png；背面发髻为补全设计。地面单位，翅膀只做轻扇装饰。
"""
import math

import motions

SKIN = "#ffe3cf"
HAIR = "#c99a64"
LEAF = "#8cc66a"
LEAF_D = "#5e9a48"
WING_A = "#f7b9d8"
WING_B = "#b7d8f7"
WING_EDGE = "#8f7fd0"
FLOWER = "#b98ae0"
STEM = "#6aa54f"
EYE = "#3b2a26"


def build(k):
    k.bone("body", (0, 0, 0.06), 0.4)
    k.bone("head", (0, 0, 0.52), 0.3, "body")
    k.bone("wing.L", (0.06, 0.12, 0.48), 0.1, "body")
    k.bone("wing.R", (-0.06, 0.12, 0.48), 0.1, "body")
    k.bone("arm.R", (-0.14, 0, 0.47), 0.08, "body")
    k.bone("arm.L", (0.14, 0, 0.47), 0.08, "body")
    k.bone("foot.R", (-0.07, 0, 0.04), 0.08)
    k.bone("foot.L", (0.07, 0, 0.04), 0.08)

    # 叶子裙 + 上身
    k.cyl("body", (0, 0, 0.26), 0.25, 0.1, 0.4, LEAF, seg=10, smooth=False)
    for i in range(5):
        a = i * 72
        k.sphere("body", (0.19 * math.cos(math.radians(a)), 0.19 * math.sin(math.radians(a)), 0.1), 0.09, LEAF_D,
                 scale=(1.0, 1.0, 0.45))
    k.sphere("body", (0, 0, 0.5), 0.11, LEAF, scale=(1.0, 0.85, 1.1))
    # 头：脸 + 发髻 + 刘海 + 触角 + 五官
    k.sphere("head", (0, 0, 0.74), 0.21, SKIN)
    k.sphere("head", (0, 0.05, 0.79), 0.22, HAIR, scale=(1.02, 0.92, 0.95))
    k.sphere("head", (0, -0.09, 0.9), 0.15, HAIR, scale=(1.2, 0.55, 0.5))
    k.sphere("head", (0, 0.13, 0.98), 0.1, HAIR)
    for x in (-1, 1):
        k.sphere("head", (0.075 * x, -0.19, 0.74), 0.038, EYE, scale=(0.8, 0.5, 1.2))
        k.sphere("head", (0.085 * x - 0.008, -0.21, 0.765), 0.012, "#ffffff")
        k.sphere("head", (0.13 * x, -0.17, 0.68), 0.035, "#ffa7bd", scale=(1, 0.3, 0.6))
        k.tube("head", [(0.05 * x, -0.06, 0.95), (0.1 * x, -0.1, 1.08)], 0.008, "#5a4a3a")
        k.sphere("head", (0.1 * x, -0.1, 1.09), 0.025, FLOWER)
    # 蝴蝶翅：上大下小两对，扁椭球
    for side, bone in ((1, "wing.L"), (-1, "wing.R")):
        k.sphere(bone, (0.2 * side, 0.15, 0.68), 0.2, WING_A, scale=(1.0, 0.12, 1.15), rot=(0, -side * 30, 0))
        k.sphere(bone, (0.17 * side, 0.15, 0.36), 0.13, WING_B, scale=(1.0, 0.12, 1.2), rot=(0, side * 30, 0))
        k.sphere(bone, (0.26 * side, 0.155, 0.75), 0.05, WING_EDGE, scale=(1, 0.3, 1))
    # 手臂 + 魔杖（右手）
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.cyl(bone, (0.17 * side, -0.02, 0.4), 0.035, 0.03, 0.15, SKIN, rot=(0, -20 * side, 0), seg=8)
        k.sphere(bone, (0.2 * side, -0.04, 0.33), 0.04, SKIN)
    k.tube("arm.R", [(-0.21, -0.05, 0.25), (-0.21, -0.08, 0.72)], 0.014, STEM)
    for i in range(5):
        a = i * 72
        k.sphere("arm.R", (-0.21 + 0.045 * math.cos(math.radians(a)), -0.08, 0.76 + 0.045 * math.sin(math.radians(a))),
                 0.035, FLOWER, scale=(1, 0.5, 1))
    k.sphere("arm.R", (-0.21, -0.1, 0.76), 0.025, "#fff27a")
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.sphere(bone, (0.07 * side, -0.03, 0.03), 0.045, LEAF_D, scale=(0.9, 1.4, 0.6))

    idle = k.clip("Idle", 40, True)
    motions.idle(idle)
    motions.flap(idle, amp=12.0, cycles=2)
    walk = k.clip("Walk", 20, True)
    motions.walk(walk, stride=0.06, lift=0.05, swing=14.0)
    motions.flap(walk, amp=16.0, cycles=2)
    atk = k.clip("Attack", 30, False)
    motions.shoot_attack(atk, "arm.R", aim=-85.0, recoil=-20.0, kick=0.0, hit=0.45)
    motions.flap(atk, amp=22.0, cycles=3)
    die = k.clip("Death", 18, False)
    motions.death(die, limbs=("arm.L", "arm.R", "wing.L", "wing.R"))
