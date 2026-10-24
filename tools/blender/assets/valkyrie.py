"""双斧火钳（valkyrie_body）：紫色锹甲虫，头顶一对大颚角，分节米色肚皮，双手各持一柄战斧；攻击是原地旋风斩。
原画：testAssets/新风格美术资源0830/动作/双斧火钳/双斧火钳.png；甲壳背面为补全设计。
"""
import motions

SHELL = "#5a4a8c"
SHELL_D = "#3c2f63"
BELLY = "#c9a77e"
BELLY_D = "#9c7c58"
STEEL = "#c9d1d8"
STEEL_D = "#8b959f"
WOOD = "#7a4a26"
EYE = "#ffffff"


def build(k):
    k.bone("body", (0, 0, 0.1), 0.4)
    k.bone("head", (0, -0.05, 0.62), 0.3, "body")
    k.bone("arm.R", (-0.24, 0, 0.5), 0.1, "body")
    k.bone("arm.L", (0.24, 0, 0.5), 0.1, "body")
    k.bone("foot.R", (-0.12, 0, 0.04), 0.1)
    k.bone("foot.L", (0.12, 0, 0.04), 0.1)

    k.sphere("body", (0, 0.04, 0.42), 0.3, SHELL, scale=(1.0, 0.95, 1.1))
    k.sphere("body", (0, -0.14, 0.38), 0.22, BELLY, scale=(0.95, 0.55, 1.1))
    for z in (0.26, 0.38, 0.5):
        k.torus("body", (0, -0.14, z), 0.17 - abs(z - 0.38) * 0.4, 0.018, BELLY_D, rot=(90, 0, 0), seg=14, ring=4,
                scale=(1, 0.35, 1))
    k.box("body", (0, 0.29, 0.45), (0.04, 0.05, 0.5), SHELL_D, bevel=0.3)
    # 头：小圆头 + 白眼黑瞳 + 一对大颚角（弧形向上外张）
    k.sphere("head", (0, -0.1, 0.78), 0.18, SHELL_D)
    for x in (-1, 1):
        k.sphere("head", (0.08 * x, -0.25, 0.8), 0.045, EYE)
        k.sphere("head", (0.08 * x, -0.285, 0.8), 0.022, "#1a1a1a")
        k.tube("head", [(0.08 * x, -0.12, 0.9), (0.2 * x, -0.16, 1.05), (0.28 * x, -0.12, 1.22), (0.24 * x, -0.06, 1.32)],
               0.035, SHELL_D, end_radius=0.015)
        k.cyl("head", (0.22 * x, -0.15, 1.12), 0.035, 0.0, 0.09, SHELL_D, rot=(0, -60 * x, 0), seg=6)
    # 双斧
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.cyl(bone, (0.29 * side, -0.02, 0.42), 0.055, 0.05, 0.2, SHELL, rot=(0, -25 * side, 0), seg=10)
        k.sphere(bone, (0.34 * side, -0.05, 0.32), 0.06, SHELL_D)
        k.tube(bone, [(0.36 * side, -0.07, 0.12), (0.36 * side, -0.07, 0.72)], 0.024, WOOD)
        k.cyl(bone, (0.47 * side, -0.07, 0.62), 0.14, 0.14, 0.04, STEEL, rot=(90, 0, 0), seg=10, scale=(0.75, 1, 1))
        k.box(bone, (0.36 * side, -0.07, 0.62), (0.06, 0.06, 0.16), STEEL_D, bevel=0.2)
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.sphere(bone, (0.12 * side, -0.04, 0.05), 0.07, SHELL_D, scale=(0.9, 1.3, 0.6))

    idle = k.clip("Idle", 60, True)
    motions.idle(idle, extra=[("arm.R", "rot", 0, 4.0, 0.0), ("arm.L", "rot", 0, 4.0, 0.8)])
    walk = k.clip("Walk", 22, True)
    motions.walk(walk, swing=14.0)
    atk = k.clip("Attack", 32, False)   # 旋风斩：双斧外展 + 身体转一整圈
    for f, yaw in ((0, 0), (6, -20), (12, 90), (16, 180), (20, 270), (24, 360), (32, 360)):
        atk.key(f, "body", rot=(0, 0, yaw))
    atk.key(0, "arm.R", rot=(0, 0, 0)).key(8, "arm.R", rot=(0, -60, 0)).key(24, "arm.R", rot=(0, -60, 0))
    atk.key(32, "arm.R", rot=(0, 0, 0))
    atk.key(0, "arm.L", rot=(0, 0, 0)).key(8, "arm.L", rot=(0, 60, 0)).key(24, "arm.L", rot=(0, 60, 0))
    atk.key(32, "arm.L", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, limbs=("arm.L", "arm.R"))
