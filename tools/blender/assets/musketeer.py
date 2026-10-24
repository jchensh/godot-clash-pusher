"""鼹鼠火枪手（musketeer_body）：圆胖黑鼹鼠，粉色长鼻，额头黄铜护目镜，双手端黄铜管火枪平举向前。
原画：testAssets/新风格美术资源0830/动作/鼹鼠火枪手/鼹鼠火枪手.png；背面与尾巴为补全设计。
"""
import motions

FUR = "#55505c"
FUR_L = "#7a7484"
NOSE = "#f29bb2"
PAW = "#f1d2b8"
BRASS = "#d9a640"
LENS = "#7fd0e8"
WOOD = "#7a4a26"
EYE = "#111111"


def build(k):
    k.bone("body", (0, 0, 0.06), 0.4)
    k.bone("head", (0, -0.02, 0.6), 0.25, "body")
    k.bone("gun", (0, -0.1, 0.42), 0.2, "body")
    k.bone("foot.R", (-0.13, 0, 0.04), 0.1)
    k.bone("foot.L", (0.13, 0, 0.04), 0.1)

    k.sphere("body", (0, 0, 0.36), 0.3, FUR, scale=(1.0, 0.9, 1.05))
    k.sphere("body", (0, -0.17, 0.33), 0.2, FUR_L, scale=(1.0, 0.5, 1.0))
    k.sphere("body", (0, 0.3, 0.2), 0.06, FUR_L, scale=(0.8, 1.6, 0.8))
    # 头：前探的尖鼻 + 小眼 + 护目镜
    k.sphere("head", (0, -0.08, 0.72), 0.28, FUR, scale=(1.0, 0.95, 0.9))
    k.sphere("head", (0, -0.3, 0.66), 0.11, FUR_L, scale=(0.9, 1.4, 0.8))
    k.sphere("head", (0, -0.45, 0.67), 0.06, NOSE)
    for x in (-1, 1):
        k.sphere("head", (0.075 * x, -0.33, 0.77), 0.03, EYE)
        k.torus("head", (0.1 * x, -0.27, 0.88), 0.065, 0.024, BRASS, rot=(65, 0, 0), seg=12, ring=6)
        k.sphere("head", (0.1 * x, -0.28, 0.88), 0.055, LENS, scale=(1, 0.4, 1))
    # 火枪 + 端枪的双手
    k.cyl("gun", (0, -0.42, 0.42), 0.05, 0.06, 0.62, BRASS, rot=(90, 0, 0), seg=12)
    k.torus("gun", (0, -0.73, 0.42), 0.07, 0.025, BRASS, rot=(90, 0, 0), seg=12, ring=5)
    k.box("gun", (0, 0.0, 0.38), (0.11, 0.38, 0.13), WOOD, rot=(-10, 0, 0), bevel=0.3)
    for x in (-1, 1):
        k.sphere("gun", (0.13 * x, -0.25, 0.4), 0.07, PAW)
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.sphere(bone, (0.13 * side, -0.06, 0.04), 0.08, PAW, scale=(1.0, 1.3, 0.5))

    idle = k.clip("Idle", 60, True)
    motions.idle(idle, extra=[("gun", "rot", 0, 2.0, 0.5)])
    walk = k.clip("Walk", 24, True)
    motions.walk(walk, arms=(None, None), swing=0, stride=0.08, lean=3.0, extra=[("gun", "rot", 0, 3.0, 0.0)])
    atk = k.clip("Attack", 30, False)
    motions.shoot_attack(atk, "gun", aim=-4.0, recoil=-12.0, kick=0.08, hit=0.4)
    die = k.clip("Death", 18, False)
    motions.death(die, limbs=("gun",))
