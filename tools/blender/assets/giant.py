"""大块头（giant_body，锁定卡单位·自行设计，大型肉盾，只打建筑）：棕色大熊穿蓝色背带裤（金纽扣），圆耳、浅色口鼻，一双大拳头。
无原画：按 0830 卡通风格自行设计（体型参照岩石史莱姆的大型档）。
"""
import motions

FUR = "#9a6b45"
FUR_D = "#6e4a2e"
MUZZLE = "#e9cfa8"
DENIM = "#4f7fc4"
DENIM_D = "#3a5f96"
GOLD = "#f2c14e"
EYE = "#1d1612"


def build(k):
    k.bone("body", (0, 0, 0.12), 0.5)
    k.bone("head", (0, -0.02, 0.98), 0.3, "body")
    k.bone("arm.R", (-0.42, 0, 0.9), 0.12, "body")
    k.bone("arm.L", (0.42, 0, 0.9), 0.12, "body")
    k.bone("foot.R", (-0.2, 0, 0.05), 0.1)
    k.bone("foot.L", (0.2, 0, 0.05), 0.1)

    # 大肚身体 + 背带裤
    k.sphere("body", (0, 0, 0.7), 0.48, FUR, scale=(1.0, 0.85, 1.0))
    k.sphere("body", (0, -0.04, 0.5), 0.47, DENIM, scale=(1.02, 0.88, 0.62))
    k.box("body", (0, -0.36, 0.72), (0.42, 0.06, 0.3), DENIM, bevel=0.2)
    for x in (-1, 1):
        k.box("body", (0.2 * x, -0.3, 0.98), (0.09, 0.06, 0.42), DENIM_D, rot=(18, 0, -14 * x), bevel=0.2)
        k.sphere("body", (0.17 * x, -0.4, 0.84), 0.04, GOLD)
    k.box("body", (0, -0.4, 0.68), (0.18, 0.02, 0.12), DENIM_D, bevel=0.3)
    # 头：大圆脑袋 + 圆耳 + 口鼻 + 眼
    k.sphere("head", (0, -0.03, 1.22), 0.3, FUR)
    for x in (-1, 1):
        k.sphere("head", (0.24 * x, 0.0, 1.46), 0.1, FUR_D, scale=(1, 0.6, 1))
        k.sphere("head", (0.24 * x, -0.03, 1.46), 0.06, MUZZLE, scale=(1, 0.4, 1))
        k.sphere("head", (0.11 * x, -0.29, 1.27), 0.04, EYE)
        k.box("head", (0.11 * x, -0.28, 1.34), (0.1, 0.03, 0.03), FUR_D, rot=(0, -15 * x, 0), bevel=0.3)
    k.sphere("head", (0, -0.27, 1.14), 0.13, MUZZLE, scale=(1.2, 0.7, 0.8))
    k.sphere("head", (0, -0.36, 1.18), 0.045, EYE, scale=(1.3, 0.8, 0.8))
    # 粗壮手臂 + 大拳头
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.cyl(bone, (0.48 * side, -0.04, 0.72), 0.13, 0.12, 0.38, FUR, rot=(0, -12 * side, 0), seg=12)
        k.sphere(bone, (0.52 * side, -0.08, 0.5), 0.17, FUR_D)
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.cyl(bone, (0.2 * side, 0.0, 0.15), 0.13, 0.13, 0.2, DENIM_D, seg=10)
        k.sphere(bone, (0.2 * side, -0.06, 0.06), 0.15, FUR_D, scale=(1, 1.3, 0.55))

    idle = k.clip("Idle", 60, True)
    motions.idle(idle, bob=0.02, extra=[("arm.R", "rot", 1, 4.0, 0.0), ("arm.L", "rot", 1, -4.0, 0.0)])
    walk = k.clip("Walk", 30, True)
    motions.walk(walk, stride=0.12, lift=0.08, swing=16.0, lean=5.0, bob=0.05)
    atk = k.clip("Attack", 36, False)   # 双拳过顶猛砸
    for arm in ("arm.R", "arm.L"):
        atk.key(0, arm, rot=(0, 0, 0)).key(14, arm, rot=(-150, 0, 0)).key(19, arm, rot=(-40, 0, 0))
        atk.key(26, arm, rot=(-45, 0, 0)).key(36, arm, rot=(0, 0, 0))
    atk.key(0, "body", rot=(0, 0, 0)).key(14, "body", rot=(-12, 0, 0)).key(19, "body", rot=(16, 0, 0))
    atk.key(36, "body", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, fall=80.0, drop=-0.1, limbs=("arm.L", "arm.R"))
