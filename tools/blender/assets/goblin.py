"""蟑螂（goblin_body，蟑螂小队/蟑螂空投/蟑螂恶霸帮共用）：棕色小蟑螂，长触须、凶眉，右手握小匕首，快速碎步。
原画：testAssets/新风格美术资源0830/动作/蟑螂/蟑螂.png；背面翅鞘为补全设计。
"""
import motions

BROWN = "#8a5a36"
BROWN_D = "#5e3a20"
BELLY = "#c49a6c"
STEEL = "#cfd6dc"
WOOD = "#5b3a24"
EYE = "#1a1210"


def build(k):
    k.bone("body", (0, 0, 0.08), 0.3)
    k.bone("head", (0, -0.03, 0.46), 0.2, "body")
    k.bone("ant.L", (0.06, -0.12, 0.7), 0.1, "head")
    k.bone("ant.R", (-0.06, -0.12, 0.7), 0.1, "head")
    k.bone("arm.R", (-0.17, 0, 0.4), 0.08, "body")
    k.bone("arm.L", (0.17, 0, 0.4), 0.08, "body")
    k.bone("foot.R", (-0.09, 0, 0.04), 0.08)
    k.bone("foot.L", (0.09, 0, 0.04), 0.08)

    k.sphere("body", (0, 0.03, 0.3), 0.21, BROWN, scale=(1.0, 1.0, 1.05))
    k.sphere("body", (0, -0.1, 0.28), 0.15, BELLY, scale=(0.95, 0.5, 1.0))
    for z in (0.2, 0.28, 0.36):
        k.box("body", (0, -0.165, z), (0.2 - abs(z - 0.28) * 0.6, 0.02, 0.018), BROWN_D, bevel=0.3)
    k.box("body", (0, 0.22, 0.32), (0.03, 0.05, 0.3), BROWN_D, bevel=0.3)
    # 头 + 凶眉 + 大眼 + 触须
    k.sphere("head", (0, -0.06, 0.58), 0.17, BROWN)
    for x in (-1, 1):
        k.sphere("head", (0.065 * x, -0.2, 0.6), 0.04, "#ffffff")
        k.sphere("head", (0.065 * x, -0.232, 0.6), 0.022, EYE)
        k.box("head", (0.07 * x, -0.21, 0.66), (0.08, 0.02, 0.025), EYE, rot=(0, -28 * x, 0), bevel=0.3)
    k.box("head", (0, -0.22, 0.52), (0.07, 0.015, 0.02), EYE, bevel=0.3)
    for side, bone in ((1, "ant.L"), (-1, "ant.R")):
        k.tube(bone, [(0.05 * side, -0.14, 0.7), (0.12 * side, -0.18, 0.85), (0.2 * side, -0.12, 0.95)], 0.012, BROWN_D)
    # 手臂（细爪）+ 右手匕首；中间一对小腿
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.tube(bone, [(0.17 * side, 0, 0.4), (0.23 * side, -0.05, 0.3)], 0.025, BROWN_D)
        k.sphere(bone, (0.24 * side, -0.07, 0.28), 0.035, BROWN_D)
    k.box("arm.R", (-0.24, -0.08, 0.35), (0.03, 0.03, 0.08), WOOD, bevel=0.3)
    k.cyl("arm.R", (-0.24, -0.08, 0.47), 0.035, 0.0, 0.18, STEEL, seg=4, smooth=False, scale=(1.0, 0.35, 1.0))
    for x in (-1, 1):
        k.tube("body", [(0.17 * x, 0.04, 0.25), (0.24 * x, 0.06, 0.16)], 0.02, BROWN_D)
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.tube(bone, [(0.07 * side, 0, 0.14), (0.09 * side, -0.02, 0.03)], 0.025, BROWN_D)
        k.sphere(bone, (0.09 * side, -0.05, 0.03), 0.04, BROWN_D, scale=(1, 1.4, 0.6))

    idle = k.clip("Idle", 40, True)
    motions.idle(idle, extra=[("ant.L", "rot", 1, -8.0, 0.0), ("ant.R", "rot", 1, 8.0, 0.5)])
    walk = k.clip("Walk", 14, True)
    motions.walk(walk, stride=0.07, lift=0.05, swing=22.0, lean=8.0,
                 extra=[("ant.L", "rot", 0, -10.0, 0.0), ("ant.R", "rot", 0, -10.0, 0.0)])
    atk = k.clip("Attack", 20, False)
    motions.swing_attack(atk, "arm.R", windup=30.0, strike=-70.0, hit=0.45)
    die = k.clip("Death", 18, False)
    motions.death(die, limbs=("arm.L", "arm.R", "ant.L", "ant.R"))
