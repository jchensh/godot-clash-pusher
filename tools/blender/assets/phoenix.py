"""火又鸟（phoenix_body，空军）：圆滚滚橙色小鸟，火焰翅膀与尾羽，头顶一簇小火苗，黄色小喙。
原画：testAssets/新风格美术资源0830/动作/火又鸟/火又鸟.png；背面与尾羽为补全设计。
原点在脚底；飞行高度由 presenter 统一抬升（纯表现），动作在原地悬停。
"""
import math

ORANGE = "#ff9a2e"
ORANGE_L = "#ffd36b"
RED = "#f0532b"
YELLOW = "#ffe066"
EYE = "#2b2422"
WHITE = "#ffffff"
BEAK = "#ffcf3a"
FOOT = "#e07a2a"


def build(k):
    k.bone("body", (0, 0, 0.12), 0.4)
    k.bone("wing.R", (-0.3, 0.02, 0.5), 0.15, "body")
    k.bone("wing.L", (0.3, 0.02, 0.5), 0.15, "body")
    k.bone("tail", (0, 0.3, 0.38), 0.15, "body")
    k.bone("crest", (0, -0.02, 0.86), 0.15, "body")
    k.bone("flame", (0, -0.05, 1.12), 0.12, "crest")

    # 身体：圆滚滚 + 浅色肚皮 + 眼睛/喙/腮红 + 小脚
    k.sphere("body", (0, 0, 0.5), 0.38, ORANGE, scale=(1.0, 0.95, 0.95))
    k.sphere("body", (0, -0.17, 0.42), 0.28, ORANGE_L, scale=(1.0, 0.6, 0.95))
    for x in (-1, 1):
        k.sphere("body", (0.12 * x, -0.33, 0.6), 0.055, EYE, scale=(0.8, 0.5, 1.2))
        k.sphere("body", (0.135 * x - 0.012, -0.36, 0.63), 0.018, WHITE)
        k.sphere("body", (0.21 * x, -0.29, 0.5), 0.05, "#ff7a6a", scale=(1.0, 0.3, 0.6))
        k.cyl("body", (0.1 * x, -0.04, 0.12), 0.03, 0.02, 0.14, FOOT, seg=6)
        k.sphere("body", (0.1 * x, -0.08, 0.06), 0.05, FOOT, scale=(1.0, 1.4, 0.5))
    k.cyl("body", (0, -0.4, 0.52), 0.06, 0.0, 0.12, BEAK, rot=(90, 0, 0), seg=8)

    # 头顶火焰簇（三瓣）+ 漂浮的小火苗
    for x, h, r in ((-0.08, 0.2, 0.08), (0.0, 0.28, 0.1), (0.09, 0.2, 0.08)):
        k.cyl("crest", (x, -0.02, 0.86 + h * 0.5), r, 0.0, h, RED if x else ORANGE, rot=(0, x * 120, 0), seg=8)
    k.sphere("flame", (0, -0.05, 1.18), 0.07, RED, scale=(1.0, 1.0, 1.3))
    k.cyl("flame", (0, -0.05, 1.27), 0.06, 0.0, 0.14, ORANGE, seg=8)
    k.sphere("flame", (0, -0.06, 1.17), 0.04, YELLOW)

    # 火焰翅膀：三片花瓣状火羽从翼根向外上方扇开（下橙 → 中亮橙 → 上红，最上一片最长）
    for side, bone in ((-1, "wing.R"), (1, "wing.L")):
        root = (0.3 * side, 0.03, 0.52)
        for ang, ln, c in ((12, 0.24, ORANGE), (38, 0.3, "#ff7a22"), (64, 0.34, RED)):
            a = math.radians(ang)
            d = (math.cos(a) * side, 0.0, math.sin(a))
            loc = (root[0] + d[0] * ln * 0.95, root[1] + 0.02, root[2] + d[2] * ln * 0.95)
            k.sphere(bone, loc, ln, c, scale=(1.0, 0.42, 0.2), rot=(0, -side * ang, 0))
        k.sphere(bone, (root[0] + 0.1 * side, root[1], root[2]), 0.13, ORANGE_L, scale=(1.2, 0.7, 0.9))

    # 尾羽：三根后翘火羽
    for i, x in enumerate((-0.1, 0.0, 0.1)):
        k.cyl("tail", (x, 0.42, 0.42 + (0.04 if i == 1 else 0)), 0.07, 0.0, 0.32, RED if i != 1 else ORANGE,
              rot=(-70, x * 150, 0), seg=6)

    _anims(k)


def _flap(clip, frames, amp, base_x=0.0):
    """扇翅：上举→下拍循环；左右翼镜像（左翼负 y 为上举）。"""
    for f, s in ((0, 1), (frames // 2, -1), (frames, 1)):
        clip.key(f, "wing.L", rot=(base_x, -amp * s, 0))
        clip.key(f, "wing.R", rot=(base_x, amp * s, 0))


def _anims(k):
    idle = k.clip("Idle", 30, True)
    _flap(idle, 30, 28)
    idle.wave("body", "loc", 2, 0.05, samples=6)
    idle.wave("tail", "rot", 0, 8.0, phase=1.0, samples=6)
    idle.wave("flame", "loc", 2, 0.03, phase=0.5, samples=6)
    idle.wave("crest", "rot", 1, 6.0, samples=6)

    fly = k.clip("Walk", 16, True)
    _flap(fly, 16, 40, base_x=-5)
    for f in (0, 8, 16):
        fly.key(f, "body", rot=(12, 0, 0), loc=(0, 0, 0.04 if f == 8 else 0.0))
        fly.key(f, "tail", rot=(-15 if f != 8 else 5, 0, 0))
        fly.key(f, "crest", rot=(-12, 0, 0))

    atk = k.clip("Attack", 24, False)
    _flap(atk, 24, 30)
    atk.key(0, "body", rot=(0, 0, 0), loc=(0, 0, 0))
    atk.key(7, "body", rot=(-18, 0, 0), loc=(0, 0.12, 0.06)).key(7, "crest", rot=(-15, 0, 0))
    atk.key(11, "body", rot=(28, 0, 0), loc=(0, -0.22, -0.04)).key(11, "crest", rot=(20, 0, 0))
    atk.key(11, "tail", rot=(-25, 0, 0))
    atk.key(24, "body", rot=(0, 0, 0), loc=(0, 0, 0)).key(24, "crest", rot=(0, 0, 0)).key(24, "tail", rot=(0, 0, 0))

    die = k.clip("Death", 18, False)
    die.key(0, "body", rot=(0, 0, 0), loc=(0, 0, 0))
    die.key(0, "wing.L", rot=(0, -20, 0)).key(0, "wing.R", rot=(0, 20, 0))
    die.key(6, "body", rot=(-20, 30, 0), loc=(0, 0, 0.1))
    die.key(18, "body", rot=(60, 160, 0), loc=(0, 0, -0.4))
    die.key(18, "wing.L", rot=(0, 50, 0)).key(18, "wing.R", rot=(0, -50, 0))
    die.key(18, "flame", loc=(0, 0, 0.3), scale=0.2)
