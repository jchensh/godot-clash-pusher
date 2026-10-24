"""火精灵（fire_spirit_body，空军）：橙红水滴形小火苗，黄色火心，Q 版脸，身旁一簇小火星；攻击是扑撞自爆式前冲。
原画：testAssets/新风格美术资源0830/动作/火精灵/火精灵.png；背面为补全设计。
"""
import motions

RED = "#f0532b"
ORANGE = "#ff8a2a"
YELLOW = "#ffd84d"
EYE = "#2b1a12"


def build(k):
    k.bone("body", (0, 0, 0.05), 0.3)
    k.bone("tip", (0, 0.02, 0.45), 0.15, "body")
    k.bone("ember", (0.24, 0.0, 0.2), 0.08, "body")
    k.sphere("body", (0, 0.04, 0.27), 0.24, RED, scale=(1.05, 0.9, 1.0))
    k.sphere("body", (0, -0.03, 0.25), 0.22, ORANGE)
    k.sphere("body", (0, -0.12, 0.22), 0.14, YELLOW, scale=(1.0, 0.55, 1.0))
    for x in (-1, 1):
        k.sphere("body", (0.08 * x, -0.245, 0.3), 0.035, EYE, scale=(0.8, 0.5, 1.2))
        k.sphere("body", (0.09 * x - 0.01, -0.268, 0.32), 0.011, "#ffffff")
    k.sphere("body", (0, -0.25, 0.23), 0.02, EYE, scale=(1.5, 0.5, 0.6))
    k.cyl("tip", (0, 0.0, 0.56), 0.15, 0.0, 0.42, ORANGE, rot=(-12, 0, 0), seg=10)
    k.cyl("tip", (0, -0.04, 0.5), 0.09, 0.0, 0.24, YELLOW, rot=(-10, 0, 0), seg=8)
    k.cyl("tip", (0.13, 0.04, 0.48), 0.08, 0.0, 0.26, RED, rot=(-5, 35, 0), seg=8)
    k.cyl("tip", (-0.13, 0.04, 0.46), 0.07, 0.0, 0.22, RED, rot=(-5, -35, 0), seg=8)
    k.sphere("ember", (0.28, -0.02, 0.12), 0.05, ORANGE)
    k.cyl("ember", (0.28, -0.02, 0.19), 0.045, 0.0, 0.1, RED, seg=6)

    idle = k.clip("Idle", 24, True)
    motions.hover(idle, bob=0.04)
    idle.wave("tip", "rot", 1, 10.0, samples=6)
    idle.wave("tip", "scale", 2, 0.08, base=(1, 1, 1), phase=1.0, samples=6)
    idle.wave("ember", "loc", 2, 0.05, phase=2.0, samples=6)
    fly = k.clip("Walk", 16, True)
    motions.hover(fly, bob=0.05, tilt=14.0)
    fly.wave("tip", "rot", 0, -12.0, offset=-10.0, samples=6)
    fly.wave("tip", "scale", 2, 0.1, base=(1, 1, 1), samples=6)
    atk = k.clip("Attack", 20, False)
    motions.lunge_attack(atk, head=None, dist=0.35, pitch=30.0, hit=0.5, squash=0.2)
    atk.key(10, "tip", scale=(1.3, 1.3, 1.4)).key(20, "tip", scale=(1, 1, 1))
    die = k.clip("Death", 18, False)   # 噗地熄灭：膨胀一下后缩没
    die.key(0, "body", scale=(1, 1, 1), loc=(0, 0, 0))
    die.key(5, "body", scale=(1.35, 1.35, 1.35), loc=(0, 0, 0.06))
    die.key(18, "body", scale=(0.05, 0.05, 0.05), loc=(0, 0, 0.3))
