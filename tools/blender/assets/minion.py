"""小乌鸦（minion_body，锁定卡单位·自行设计，空军小兵；小蝙蝠借用）：圆滚滚深蓝黑色小乌鸦，橙色小喙，凶眉，短翅扑腾。
无原画：按 0830 卡通风格（Q 版圆身、粗描边、腮红）自行设计，同族参考鸦王的乌鸦脸。
"""
import motions

BODY = "#2f3550"
BODY_L = "#4a5272"
BEAK = "#ffb03b"
EYE = "#ffffff"
PUPIL = "#141414"


def build(k):
    k.bone("body", (0, 0, 0.08), 0.3)
    k.bone("wing.L", (0.2, 0.05, 0.36), 0.08, "body")
    k.bone("wing.R", (-0.2, 0.05, 0.36), 0.08, "body")
    k.bone("tail", (0, 0.2, 0.25), 0.08, "body")
    k.sphere("body", (0, 0, 0.33), 0.25, BODY)
    k.sphere("body", (0, -0.12, 0.27), 0.16, BODY_L, scale=(1.0, 0.55, 1.0))
    k.cyl("body", (0, 0.0, 0.62), 0.05, 0.0, 0.1, BODY, rot=(-20, 0, 0), seg=5)
    k.cyl("body", (0.05, 0.02, 0.6), 0.04, 0.0, 0.09, BODY, rot=(-10, 20, 0), seg=5)
    k.cyl("body", (0, -0.29, 0.31), 0.06, 0.0, 0.13, BEAK, rot=(90, 0, 0), seg=8)
    for x in (-1, 1):
        k.sphere("body", (0.085 * x, -0.21, 0.4), 0.045, EYE)
        k.sphere("body", (0.085 * x, -0.245, 0.4), 0.025, PUPIL)
        k.box("body", (0.09 * x, -0.22, 0.46), (0.09, 0.02, 0.025), PUPIL, rot=(0, -25 * x, 0), bevel=0.3)
        k.cyl("body", (0.07 * x, -0.03, 0.08), 0.02, 0.015, 0.1, BEAK, seg=5)
    for side, bone in ((1, "wing.L"), (-1, "wing.R")):
        k.sphere(bone, (0.3 * side, 0.06, 0.38), 0.16, BODY, scale=(1.0, 0.25, 0.6), rot=(0, -side * 25, 0))
        k.sphere(bone, (0.38 * side, 0.06, 0.34), 0.08, BODY_L, scale=(1.0, 0.3, 0.6), rot=(0, -side * 25, 0))
    for i, x in enumerate((-0.06, 0.0, 0.06)):
        k.cyl("tail", (x, 0.26, 0.22), 0.04, 0.0, 0.16, BODY, rot=(-70, x * 200, 0), seg=4, smooth=False)

    idle = k.clip("Idle", 12, True)
    motions.flap(idle, amp=35.0, cycles=1)
    motions.hover(idle, bob=0.04)
    fly = k.clip("Walk", 10, True)
    motions.flap(fly, amp=45.0, cycles=1)
    motions.hover(fly, bob=0.03, tilt=12.0)
    atk = k.clip("Attack", 20, False)
    motions.flap(atk, amp=40.0, cycles=2)
    motions.lunge_attack(atk, head=None, dist=0.2, pitch=30.0)
    die = k.clip("Death", 18, False)
    motions.death(die, head=None, flier=True, fall=60.0, limbs=("wing.L", "wing.R"))
