"""飞斧汪（axe_thrower_body）：棕色虎斑狗头凶脸，白毛围领，红披风，骷髅扣皮带，右手高举大斧。
原画：testAssets/新风格美术资源0830/动作/飞斧汪/飞斧汪.png；背面披风为补全设计。
"""
import motions

FUR = "#a8673e"
FUR_D = "#6e3f24"
CREAM = "#f6e6cf"
RED = "#b8322f"
LEATHER = "#5b3a24"
STEEL = "#c9d1d8"
STEEL_D = "#8b959f"
WOOD = "#7a4a26"
EYE = "#1d1612"


def build(k):
    k.bone("body", (0, 0, 0.1), 0.4)
    k.bone("head", (0, 0, 0.64), 0.3, "body")
    k.bone("arm.R", (-0.22, 0, 0.6), 0.1, "body")
    k.bone("arm.L", (0.22, 0, 0.6), 0.1, "body")
    k.bone("cape", (0, 0.15, 0.68), 0.1, "body")
    k.bone("foot.R", (-0.11, 0, 0.04), 0.1)
    k.bone("foot.L", (0.11, 0, 0.04), 0.1)

    k.sphere("body", (0, 0, 0.42), 0.27, FUR, scale=(1.0, 0.85, 1.1))
    k.sphere("body", (0, -0.17, 0.4), 0.17, CREAM, scale=(1.0, 0.45, 1.0))
    k.torus("body", (0, 0, 0.27), 0.25, 0.04, LEATHER, seg=16, ring=6)
    k.sphere("body", (0, -0.25, 0.27), 0.05, "#f2efe6", scale=(1, 0.5, 1))
    k.torus("body", (0, 0, 0.66), 0.17, 0.08, CREAM, seg=14, ring=6)
    k.sphere("cape", (0, 0.2, 0.42), 0.28, RED, scale=(1.0, 0.25, 1.2))
    # 头：大脑袋 + 尖耳 + 条纹 + 白口鼻 + 凶眉 + 獠牙
    k.sphere("head", (0, 0, 0.9), 0.27, FUR, scale=(1.05, 0.95, 0.95))
    for x in (-1, 1):
        k.cyl("head", (0.18 * x, 0.02, 1.15), 0.09, 0.0, 0.2, FUR, rot=(0, 20 * x, 0), seg=6)
        k.cyl("head", (0.18 * x, -0.01, 1.14), 0.05, 0.0, 0.13, "#f0b7a4", rot=(0, 20 * x, 0), seg=6)
        k.box("head", (0.1 * x, -0.22, 0.98), (0.11, 0.03, 0.035), EYE, rot=(0, -25 * x, 0), bevel=0.3)
        k.sphere("head", (0.09 * x, -0.23, 0.92), 0.035, EYE, scale=(0.9, 0.5, 1.0))
        k.cyl("head", (0.05 * x, -0.29, 0.76), 0.018, 0.0, 0.06, "#ffffff", rot=(180, 0, 0), seg=5)
    for z in (1.08, 1.0):
        k.box("head", (0, -0.12, z + 0.06), (0.05, 0.2, 0.025), FUR_D, rot=(30, 0, 0), bevel=0.3)
    k.sphere("head", (0, -0.22, 0.82), 0.13, CREAM, scale=(1.2, 0.7, 0.75))
    k.sphere("head", (0, -0.31, 0.86), 0.04, EYE, scale=(1.3, 0.8, 0.8))
    # 手臂 + 右手大斧（高举）
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.cyl(bone, (0.26 * side, -0.02, 0.5), 0.06, 0.055, 0.22, FUR, rot=(0, -20 * side, 0), seg=10)
        k.sphere(bone, (0.3 * side, -0.05, 0.39), 0.065, CREAM)
    k.tube("arm.R", [(-0.31, -0.06, 0.25), (-0.31, -0.06, 1.15)], 0.03, WOOD)
    k.box("arm.R", (-0.31, -0.06, 1.02), (0.06, 0.06, 0.24), STEEL_D, bevel=0.2)
    k.cyl("arm.R", (-0.47, -0.06, 1.02), 0.2, 0.2, 0.05, STEEL, rot=(90, 0, 0), seg=10, scale=(0.75, 1.0, 1.0))
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.sphere(bone, (0.11 * side, -0.05, 0.04), 0.075, FUR_D, scale=(0.9, 1.3, 0.55))

    idle = k.clip("Idle", 60, True)
    motions.idle(idle, extra=[("cape", "rot", 0, -4.0, 0.7), ("arm.R", "rot", 0, 3.0, 0.2)])
    walk = k.clip("Walk", 22, True)
    motions.walk(walk, arms=("arm.L", None), extra=[("cape", "rot", 0, -10.0, 1.2)])
    atk = k.clip("Attack", 30, False)
    motions.swing_attack(atk, "arm.R", windup=40.0, strike=-95.0, hit=0.45)
    atk.key(14, "cape", rot=(-15, 0, 0)).key(30, "cape", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, limbs=("arm.L", "arm.R"))
