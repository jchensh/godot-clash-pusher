"""鸦王（mega_minion_body，空军）：瘟疫医生乌鸦——紫色兜帽斗篷、粉白长鸟喙面具、白毛领、红色翅膀，手持挂药瓶与骷髅饰的弯杖。
原画：testAssets/新风格美术资源0830/动作/鸦王/鸦王.png；背面翅膀为补全设计。
"""
import motions

CLOAK = "#5b4a8c"
CLOAK_D = "#40336a"
BEAK = "#f3c9d0"
BEAK_D = "#d99aa6"
FUR = "#f4efe6"
WING = "#b8322f"
WING_D = "#7f1f1d"
WOOD = "#7a4a26"
POTION = "#9fe0f2"
BONE = "#efe8d8"
EYE = "#1a1a1a"


def build(k):
    k.bone("body", (0, 0, 0.1), 0.4)
    k.bone("head", (0, 0, 0.62), 0.25, "body")
    k.bone("wing.L", (0.2, 0.12, 0.55), 0.1, "body")
    k.bone("wing.R", (-0.2, 0.12, 0.55), 0.1, "body")
    k.bone("staff", (-0.28, -0.12, 0.4), 0.15, "body")
    # 斗篷身体 + 白毛领 + 骷髅挂饰
    k.cyl("body", (0, 0, 0.32), 0.3, 0.15, 0.5, CLOAK, seg=14)
    k.torus("body", (0, 0, 0.6), 0.15, 0.07, FUR, seg=14, ring=6)
    k.sphere("body", (0.1, -0.2, 0.42), 0.06, BONE)
    for x in (-1, 1):
        k.sphere("body", (0.1 + 0.022 * x, -0.25, 0.43), 0.014, EYE)
    # 头：兜帽 + 乌鸦脸 + 长喙面具
    k.sphere("head", (0, 0, 0.82), 0.23, "#2d2a33")
    k.sphere("head", (0, 0.05, 0.86), 0.26, CLOAK_D, scale=(1.05, 0.9, 1.0))
    k.cyl("head", (0, 0.1, 1.08), 0.14, 0.0, 0.22, CLOAK_D, rot=(-25, 0, 0), seg=8)
    k.cyl("head", (0, -0.32, 0.77), 0.09, 0.02, 0.32, BEAK, rot=(100, 0, 0), seg=10)
    k.torus("head", (0, -0.2, 0.8), 0.09, 0.02, BEAK_D, rot=(100, 0, 0), seg=10, ring=4)
    for x in (-1, 1):
        k.sphere("head", (0.09 * x, -0.19, 0.88), 0.035, "#ffd84d")
        k.sphere("head", (0.09 * x, -0.22, 0.88), 0.018, EYE)
    # 红色翅膀（背后左右）
    for side, bone in ((1, "wing.L"), (-1, "wing.R")):
        k.sphere(bone, (0.32 * side, 0.18, 0.5), 0.3, WING, scale=(0.9, 0.12, 0.7), rot=(0, -side * 30, 0))
        for i in range(3):
            k.cyl(bone, ((0.45 + i * 0.07) * side, 0.18, 0.32 - i * 0.05), 0.05, 0.0, 0.2, WING_D,
                  rot=(180, side * (20 + i * 15), 0), seg=4, smooth=False)
    # 弯杖 + 药瓶 + 小骷髅
    k.tube("staff", [(-0.28, -0.12, 0.08), (-0.28, -0.12, 0.92), (-0.22, -0.14, 1.02), (-0.16, -0.14, 0.97)], 0.022, WOOD)
    k.tube("staff", [(-0.19, -0.14, 0.97), (-0.19, -0.14, 0.86)], 0.006, "#d9cfa6", seg=4)
    k.sphere("staff", (-0.19, -0.14, 0.8), 0.06, POTION)
    k.cyl("staff", (-0.19, -0.14, 0.87), 0.025, 0.025, 0.04, "#8b5a2b", seg=6)
    k.sphere("staff", (-0.26, -0.12, 0.42), 0.06, "#2d2a33")

    idle = k.clip("Idle", 30, True)
    motions.flap(idle, amp=16.0, cycles=1)
    motions.hover(idle, bob=0.05)
    idle.wave("staff", "rot", 1, 4.0, samples=6)
    fly = k.clip("Walk", 18, True)
    motions.flap(fly, amp=26.0, cycles=2)
    motions.hover(fly, bob=0.04, tilt=10.0)
    atk = k.clip("Attack", 28, False)
    motions.flap(atk, amp=20.0, cycles=2)
    motions.swing_attack(atk, "staff", head="head", windup=35.0, strike=-70.0, hit=0.45, lunge=0.05)
    die = k.clip("Death", 18, False)
    motions.death(die, flier=True, fall=60.0, limbs=("wing.L", "wing.R", "staff"))
