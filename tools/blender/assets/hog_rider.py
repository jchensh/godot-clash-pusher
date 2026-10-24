"""猪猪配香菇（hog_rider_body）：深灰野猪（粉鼻、獠牙）背上骑着紫帽白点的蘑菇小骑士，蘑菇手持长矛；冲锋小跑。
原画：testAssets/新风格美术资源0830/动作/猪猪配香菇/猪猪配香菇.png；猪尾与背面为补全设计。
"""
import motions

HOG = "#5b585e"
HOG_D = "#3f3d42"
SNOUT = "#f0a1b0"
TUSK = "#f6f1e3"
CAP = "#9a6cc0"
DOT = "#f6f1ea"
FACE = "#f6e3c8"
WOOD = "#7a4a26"
STEEL = "#c9d1d8"
EYE = "#1a1a1a"


def build(k):
    k.bone("body", (0, 0.05, 0.25), 0.3)
    k.bone("head", (0, -0.32, 0.4), 0.2, "body")
    k.bone("leg.FL", (0.17, -0.22, 0.25), 0.1, "body")
    k.bone("leg.FR", (-0.17, -0.22, 0.25), 0.1, "body")
    k.bone("leg.BL", (0.17, 0.3, 0.25), 0.1, "body")
    k.bone("leg.BR", (-0.17, 0.3, 0.25), 0.1, "body")
    k.bone("rider", (0, 0.1, 0.62), 0.2, "body")
    k.bone("spear", (-0.2, -0.02, 0.75), 0.15, "rider")

    # 野猪：桶状身 + 鬃毛 + 尾巴
    k.sphere("body", (0, 0.05, 0.42), 0.34, HOG, scale=(0.85, 1.25, 0.85))
    for i in range(4):
        k.cyl("body", (0, -0.12 + i * 0.12, 0.7), 0.05, 0.0, 0.12, HOG_D, rot=(-20, 0, 0), seg=5)
    k.tube("body", [(0, 0.47, 0.45), (0.04, 0.55, 0.52), (0.0, 0.58, 0.58)], 0.02, HOG_D)
    # 猪头：大鼻子 + 獠牙 + 耳朵 + 眼
    k.sphere("head", (0, -0.42, 0.44), 0.22, HOG, scale=(1.0, 1.0, 0.95))
    k.cyl("head", (0, -0.62, 0.4), 0.1, 0.11, 0.1, SNOUT, rot=(90, 0, 0), seg=12)
    for x in (-1, 1):
        k.sphere("head", (0.04 * x, -0.675, 0.41), 0.022, "#a85a6c")
        k.cyl("head", (0.1 * x, -0.6, 0.36), 0.025, 0.0, 0.1, TUSK, rot=(-30, 0, 15 * x), seg=6)
        k.cyl("head", (0.15 * x, -0.36, 0.63), 0.07, 0.0, 0.12, HOG_D, rot=(15, 30 * x, 0), seg=5)
        k.sphere("head", (0.09 * x, -0.58, 0.52), 0.03, EYE)
    # 四条腿（蹄）
    for name, (x, y) in (("leg.FL", (0.17, -0.22)), ("leg.FR", (-0.17, -0.22)), ("leg.BL", (0.17, 0.3)),
                         ("leg.BR", (-0.17, 0.3))):
        k.cyl(name, (x, y, 0.15), 0.07, 0.06, 0.22, HOG_D, seg=8)
        k.sphere(name, (x, y - 0.02, 0.04), 0.065, "#2c2a2e", scale=(1, 1.2, 0.6))
    # 蘑菇骑士：身体 + 大紫帽（白点）+ 脸 + 长矛
    k.sphere("rider", (0, 0.1, 0.8), 0.17, FACE, scale=(1.0, 0.9, 1.1))
    k.sphere("rider", (0, 0.08, 1.06), 0.28, CAP, scale=(1.0, 1.0, 0.6))
    for x, y in ((0.15, -0.08), (-0.13, -0.02), (0.0, 0.27), (0.19, 0.17), (-0.19, 0.2), (0.02, -0.18)):
        k.sphere("rider", (x, y, 1.15), 0.05, DOT, scale=(1, 1, 0.4))
    for x in (-1, 1):
        k.sphere("rider", (0.06 * x, -0.05, 0.84), 0.028, EYE)
        k.sphere("rider", (0.1 * x, -0.04, 0.77), 0.025, "#ffa7bd", scale=(1, 0.4, 0.6))
    k.sphere("rider", (0.17, 0.05, 0.72), 0.05, FACE)
    k.tube("spear", [(-0.22, 0.12, 0.45), (-0.22, -0.25, 1.3)], 0.022, WOOD)
    k.cyl("spear", (-0.22, -0.29, 1.4), 0.045, 0.0, 0.18, STEEL, rot=(-24, 0, 0), seg=4, smooth=False)
    k.sphere("spear", (-0.2, 0.0, 0.74), 0.05, FACE)

    idle = k.clip("Idle", 40, True)
    motions.idle(idle, extra=[("rider", "rot", 1, 3.0, 0.5), ("spear", "rot", 0, 3.0, 0.2)])
    run = k.clip("Walk", 14, True)   # 小跑：前后腿对角交替 + 身体起伏，骑士颠动
    for f, s in ((0, 1), (7, -1), (14, 1)):
        run.key(f, "leg.FL", rot=(-30 * s, 0, 0)).key(f, "leg.BR", rot=(-30 * s, 0, 0))
        run.key(f, "leg.FR", rot=(30 * s, 0, 0)).key(f, "leg.BL", rot=(30 * s, 0, 0))
        run.key(f, "body", rot=(4 * s, 0, 0), loc=(0, 0, 0))
        run.key(f, "rider", rot=(-6 * s, 0, 0))
    for f in (3, 10):
        run.key(f, "body", loc=(0, 0, 0.07))
    atk = k.clip("Attack", 26, False)   # 野猪顶撞 + 骑士刺矛
    motions.lunge_attack(atk, dist=0.25, pitch=18.0)
    atk.key(0, "spear", rot=(0, 0, 0)).key(8, "spear", rot=(-20, 0, 0)).key(12, "spear", rot=(45, 0, 0))
    atk.key(26, "spear", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, fall=70.0, limbs=("rider", "leg.FL", "leg.FR", "leg.BL", "leg.BR"))
