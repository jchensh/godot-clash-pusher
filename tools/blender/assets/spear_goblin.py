"""蟑螂恶霸（spear_goblin_body，蟑螂恶霸帮的远程形象）：壮硕大蟑螂，白毛肩甲，凶脸，右手扛狼牙棒。
原画：testAssets/新风格美术资源0830/动作/蟑螂恶霸/蟑螂恶霸.png；背面翅鞘为补全设计。
"""
import motions

BROWN = "#7e4f2f"
BROWN_D = "#4f301b"
BELLY = "#b88f63"
FLUFF = "#f4efe6"
WOOD = "#6b3f22"
SPIKE = "#b7bec5"
EYE = "#1a1210"


def build(k):
    k.bone("body", (0, 0, 0.08), 0.4)
    k.bone("head", (0, -0.04, 0.58), 0.22, "body")
    k.bone("ant.L", (0.07, -0.14, 0.84), 0.1, "head")
    k.bone("ant.R", (-0.07, -0.14, 0.84), 0.1, "head")
    k.bone("arm.R", (-0.25, 0, 0.52), 0.1, "body")
    k.bone("arm.L", (0.25, 0, 0.52), 0.1, "body")
    k.bone("foot.R", (-0.12, 0, 0.04), 0.1)
    k.bone("foot.L", (0.12, 0, 0.04), 0.1)

    k.sphere("body", (0, 0.03, 0.38), 0.29, BROWN, scale=(1.05, 0.95, 1.05))
    k.sphere("body", (0, -0.15, 0.34), 0.2, BELLY, scale=(1.0, 0.5, 1.0))
    for z in (0.24, 0.34, 0.44):
        k.box("body", (0, -0.24, z), (0.26 - abs(z - 0.34) * 0.6, 0.02, 0.022), BROWN_D, bevel=0.3)
    for x in (-1, 1):
        k.sphere("body", (0.22 * x, -0.02, 0.58), 0.13, FLUFF, scale=(1.1, 1.0, 0.8))
        k.sphere("body", (0.12 * x, -0.12, 0.62), 0.09, FLUFF)
    # 头
    k.sphere("head", (0, -0.08, 0.72), 0.2, BROWN)
    for x in (-1, 1):
        k.sphere("head", (0.075 * x, -0.25, 0.74), 0.045, "#ffffff")
        k.sphere("head", (0.075 * x, -0.285, 0.73), 0.024, EYE)
        k.box("head", (0.08 * x, -0.25, 0.81), (0.1, 0.025, 0.03), EYE, rot=(0, -30 * x, 0), bevel=0.3)
    k.box("head", (0, -0.27, 0.64), (0.09, 0.02, 0.025), EYE, rot=(0, 0, 8), bevel=0.3)
    for side, bone in ((1, "ant.L"), (-1, "ant.R")):
        k.tube(bone, [(0.06 * side, -0.15, 0.84), (0.14 * side, -0.2, 1.0), (0.24 * side, -0.14, 1.1)], 0.014, BROWN_D)
    # 手臂 + 狼牙棒（右手扛肩）
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.cyl(bone, (0.29 * side, -0.02, 0.42), 0.065, 0.055, 0.22, BROWN, rot=(0, -20 * side, 0), seg=10)
        k.sphere(bone, (0.32 * side, -0.05, 0.31), 0.07, BROWN_D)
    k.tube("arm.R", [(-0.33, -0.08, 0.25), (-0.36, -0.02, 0.62)], 0.04, WOOD)
    k.cyl("arm.R", (-0.38, 0.03, 0.8), 0.07, 0.13, 0.38, WOOD, rot=(-8, 4, 0), seg=10)
    for i in range(8):
        a = i * 45
        z = 0.74 + (i % 3) * 0.08
        k.cyl("arm.R", (-0.38, 0.03, z), 0.03, 0.0, 0.32, SPIKE, rot=(90, 0, a), seg=4, smooth=False)
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.sphere(bone, (0.12 * side, -0.05, 0.05), 0.08, BROWN_D, scale=(1, 1.3, 0.6))

    idle = k.clip("Idle", 50, True)
    motions.idle(idle, extra=[("ant.L", "rot", 1, -8.0, 0.0), ("ant.R", "rot", 1, 8.0, 0.5), ("arm.R", "rot", 0, 3.0, 0.3)])
    walk = k.clip("Walk", 20, True)
    motions.walk(walk, arms=("arm.L", None), lean=6.0, extra=[("ant.L", "rot", 0, -10.0, 0.0), ("ant.R", "rot", 0, -10.0, 0.0)])
    atk = k.clip("Attack", 28, False)
    motions.swing_attack(atk, "arm.R", windup=30.0, strike=-85.0, hit=0.5)
    die = k.clip("Death", 18, False)
    motions.death(die, limbs=("arm.L", "arm.R", "ant.L", "ant.R"))
