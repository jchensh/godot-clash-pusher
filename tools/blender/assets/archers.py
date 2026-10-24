"""兔射手（archer_body）：白兔戴绿色兜帽斗篷，长耳从兜帽探出；右手持木弓，背后箭袋。
原画：testAssets/新风格美术资源0830/动作/兔子/兔射手.png；背面箭袋与尾巴为补全设计。
"""
import math

import motions

FUR = "#fbf3f2"
PINK = "#f6b3c4"
HOOD = "#7fa060"
HOOD_D = "#5c7d44"
WOOD = "#8b5a2b"
STRING = "#efe6d0"
EYE = "#2b2422"
RED = "#d9534f"


def build(k):
    k.bone("body", (0, 0, 0.08), 0.4)
    k.bone("head", (0, 0, 0.58), 0.3, "body")
    k.bone("ear.L", (0.08, 0.02, 1.0), 0.2, "head")
    k.bone("ear.R", (-0.08, 0.02, 1.0), 0.2, "head")
    k.bone("arm.R", (-0.19, 0, 0.52), 0.1, "body")
    k.bone("arm.L", (0.19, 0, 0.52), 0.1, "body")
    k.bone("bow", (-0.27, -0.12, 0.42), 0.2, "arm.R")
    k.bone("foot.R", (-0.09, 0, 0.04), 0.1)
    k.bone("foot.L", (0.09, 0, 0.04), 0.1)

    # 斗篷身体 + 肚皮 + 尾巴 + 箭袋
    k.cyl("body", (0, 0, 0.32), 0.3, 0.17, 0.5, HOOD, seg=16)
    k.sphere("body", (0, -0.2, 0.3), 0.14, FUR, scale=(1.0, 0.45, 1.1))
    k.sphere("body", (0, 0.27, 0.2), 0.08, FUR)
    k.cyl("body", (0.1, 0.22, 0.58), 0.08, 0.09, 0.42, WOOD, rot=(-20, 15, 0), seg=10)
    for i, x in enumerate((0.06, 0.12, 0.16)):
        k.tube("body", [(x, 0.28, 0.78), (x + 0.02, 0.32, 0.92)], 0.012, WOOD)
        k.cyl("body", (x + 0.02, 0.32, 0.95), 0.035, 0.0, 0.08, RED if i % 2 == 0 else STRING, seg=4, smooth=False)

    # 头：脸 + 兜帽（后罩）+ 兜帽沿 + 五官
    k.sphere("head", (0, 0, 0.8), 0.25, FUR)
    k.sphere("head", (0, 0.06, 0.84), 0.28, HOOD, scale=(1.05, 0.82, 0.98))
    k.torus("head", (0, -0.13, 0.8), 0.2, 0.045, HOOD_D, rot=(75, 0, 0), seg=16, ring=6)
    for x in (-1, 1):
        k.sphere("head", (0.09 * x, -0.22, 0.81), 0.045, EYE, scale=(0.8, 0.5, 1.2))
        k.sphere("head", (0.1 * x - 0.01, -0.245, 0.835), 0.014, "#ffffff")
        k.sphere("head", (0.16 * x, -0.19, 0.74), 0.04, PINK, scale=(1.0, 0.3, 0.6))
    k.sphere("head", (0, -0.25, 0.75), 0.025, PINK, scale=(1.2, 0.6, 0.8))
    for side, bone in ((1, "ear.L"), (-1, "ear.R")):
        k.sphere(bone, (0.09 * side, 0.02, 1.16), 0.1, FUR, scale=(0.45, 0.3, 1.7), rot=(0, -side * 12, 0))
        k.sphere(bone, (0.09 * side, -0.01, 1.16), 0.07, PINK, scale=(0.35, 0.2, 1.5), rot=(0, -side * 12, 0))

    # 手臂（绿袖 + 白爪）
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.cyl(bone, (0.22 * side, -0.02, 0.44), 0.055, 0.05, 0.18, HOOD, rot=(0, -15 * side, 0), seg=10)
        k.sphere(bone, (0.25 * side, -0.05, 0.35), 0.055, FUR)

    # 木弓（右手，竖持于身前右侧）+ 弓弦
    pts = []
    for i in range(7):
        t = -1 + i / 3
        pts.append((-0.27, -0.12 - 0.12 * math.cos(t * math.pi / 2), 0.42 + t * 0.32))
    k.tube("bow", pts, 0.022, WOOD)
    k.tube("bow", [(-0.27, -0.12, 0.1), (-0.27, -0.12, 0.74)], 0.006, STRING, seg=4)

    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.sphere(bone, (0.09 * side, -0.04, 0.035), 0.065, FUR, scale=(0.9, 1.3, 0.6))

    idle = k.clip("Idle", 60, True)
    motions.idle(idle, extra=[("ear.L", "rot", 1, -5.0, 0.0), ("ear.R", "rot", 1, 5.0, 0.6), ("bow", "rot", 0, 3.0, 0.3)])
    walk = k.clip("Walk", 22, True)
    motions.walk(walk, extra=[("ear.L", "rot", 0, -8.0, 1.5), ("ear.R", "rot", 0, -8.0, 1.5)])
    atk = k.clip("Attack", 30, False)
    motions.shoot_attack(atk, "arm.R", aim=-75.0, recoil=6.0, kick=0.03)
    atk.key(0, "arm.L", rot=(0, 0, 0)).key(8, "arm.L", rot=(-70, 0, -25)).key(12, "arm.L", rot=(-60, 0, 10))
    atk.key(14, "arm.L", rot=(-75, 0, -30)).key(30, "arm.L", rot=(0, 0, 0))
    atk.key(13, "ear.L", rot=(-15, 0, 0)).key(13, "ear.R", rot=(-15, 0, 0)).key(30, "ear.L", rot=(0, 0, 0))
    atk.key(30, "ear.R", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, limbs=("arm.L", "arm.R", "ear.L", "ear.R"))
