"""雷精灵（electro_spirit_body）：亮黄色火苗形小团子，头顶两道锯齿闪电，Q 版脸；蹦跳前进，攻击时闪电炸开。
原画：testAssets/新风格美术资源0830/动作/雷精灵/雷精灵.png；背面为补全设计。
"""
import motions

YELLOW = "#ffe14d"
YELLOW_D = "#f2b81f"
BOLT = "#fff6a8"
EYE = "#2b2216"


def _bolt(k, bone, base, scale):
    pts = [(0, 0, 0), (0.06, 0, 0.1), (-0.02, 0, 0.13), (0.05, 0, 0.25)]
    pts = [(base[0] + p[0] * scale, base[1], base[2] + p[2] * scale) for p in pts]
    k.tube(bone, pts, 0.022 * scale, BOLT, seg=5)


def build(k):
    k.bone("body", (0, 0, 0.04), 0.3)
    k.bone("bolts", (0, 0.0, 0.55), 0.15, "body")
    k.sphere("body", (0, 0, 0.24), 0.23, YELLOW)
    k.sphere("body", (0, 0.04, 0.16), 0.22, YELLOW_D, scale=(1.05, 1.0, 0.45))
    k.cyl("body", (0, 0.03, 0.5), 0.17, 0.0, 0.32, YELLOW, rot=(-15, 0, 0), seg=10)
    k.cyl("body", (0.13, 0.03, 0.42), 0.08, 0.0, 0.2, YELLOW_D, rot=(-10, 30, 0), seg=8)
    for x in (-1, 1):
        k.sphere("body", (0.08 * x, -0.2, 0.28), 0.04, EYE, scale=(0.8, 0.5, 1.2))
        k.sphere("body", (0.09 * x - 0.01, -0.225, 0.3), 0.012, "#ffffff")
        k.sphere("body", (0.14 * x, -0.17, 0.2), 0.03, "#ffb36b", scale=(1, 0.3, 0.6))
    k.sphere("body", (0, -0.215, 0.2), 0.022, EYE, scale=(1.4, 0.5, 0.7))
    _bolt(k, "bolts", (-0.16, 0.0, 0.62), 1.0)
    _bolt(k, "bolts", (0.12, 0.02, 0.66), 0.8)

    idle = k.clip("Idle", 30, True)
    idle.wave("body", "scale", 2, 0.05, base=(1, 1, 1), samples=6)
    idle.wave("bolts", "loc", 2, 0.04, samples=6)
    idle.wave("bolts", "rot", 1, 8.0, phase=0.7, samples=6)
    walk = k.clip("Walk", 14, True)
    motions.hop(walk, head=None, height=0.16, squash=0.14)
    atk = k.clip("Attack", 20, False)
    atk.key(0, "body", scale=(1, 1, 1)).key(6, "body", scale=(1.15, 1.15, 0.8))
    atk.key(10, "body", scale=(0.85, 0.85, 1.25)).key(20, "body", scale=(1, 1, 1))
    atk.key(0, "bolts", scale=(1, 1, 1), loc=(0, 0, 0)).key(10, "bolts", scale=(1.8, 1.8, 1.8), loc=(0, 0, 0.12))
    atk.key(20, "bolts", scale=(1, 1, 1), loc=(0, 0, 0))
    die = k.clip("Death", 18, False)
    die.key(0, "body", scale=(1, 1, 1), loc=(0, 0, 0)).key(5, "body", scale=(1.3, 1.3, 1.3))
    die.key(18, "body", scale=(0.05, 0.05, 0.05), loc=(0, 0, 0.2))
