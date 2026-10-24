"""女主 / 小公主（princess_body）：Q 版公主，金发王冠、粉色蓬裙、白领、金吊坠，右手法杖（蓝宝珠）。
原画：testAssets/新风格美术资源0830/动作/女主/女主.png（正面 3/4）；背面长发与鞋为补全设计。
"""

SKIN = "#ffe0cc"
HAIR = "#f5c84c"
DRESS = "#f4a6c4"
DRESS_D = "#d97aa2"
WHITE = "#fff7f0"
GOLD = "#ffcc33"
EYE = "#3b2a26"
BLUSH = "#ff9db4"
WOOD = "#8b5a2b"
ORB = "#4fb4ff"
SHOE = "#a0522d"


def build(k):
    k.bone("body", (0, 0, 0.08), 0.5)
    k.bone("head", (0, 0, 0.74), 0.3, "body")
    k.bone("hair", (0, 0.1, 1.05), 0.2, "head")
    k.bone("arm.R", (-0.2, 0, 0.67), 0.1, "body")
    k.bone("arm.L", (0.2, 0, 0.67), 0.1, "body")
    k.bone("staff", (-0.29, -0.06, 0.44), 0.3, "arm.R")
    k.bone("foot.R", (-0.1, 0, 0.04), 0.1)
    k.bone("foot.L", (0.1, 0, 0.04), 0.1)

    # 身体：蓬裙 + 裙摆 + 上身 + 白领 + 吊坠
    k.cyl("body", (0, 0, 0.32), 0.42, 0.17, 0.56, DRESS, seg=18)
    k.torus("body", (0, 0, 0.05), 0.39, 0.045, DRESS_D, seg=20)
    k.sphere("body", (0, 0, 0.6), 0.17, DRESS, scale=(1.0, 0.85, 1.1))
    k.torus("body", (0, 0, 0.7), 0.13, 0.055, WHITE, seg=16, ring=8)
    k.sphere("body", (0, -0.17, 0.62), 0.035, GOLD)

    # 头：脸 + 头发（后脑、刘海、两侧发束）+ 五官 + 王冠
    k.sphere("head", (0, 0, 1.02), 0.3, SKIN, scale=(1.0, 0.95, 0.95))
    k.sphere("head", (0, 0.05, 1.08), 0.33, HAIR, scale=(1.02, 0.95, 0.95))
    k.sphere("head", (0, -0.13, 1.2), 0.24, HAIR, scale=(1.15, 0.55, 0.5))
    for x in (-1, 1):
        k.sphere("head", (0.28 * x, 0.04, 0.93), 0.1, HAIR, scale=(0.65, 0.8, 1.25))
        k.sphere("head", (0.1 * x, -0.265, 1.0), 0.052, EYE, scale=(0.8, 0.5, 1.25))
        k.sphere("head", (0.115 * x - 0.01, -0.29, 1.03), 0.016, WHITE)
        k.sphere("head", (0.18 * x, -0.24, 0.92), 0.05, BLUSH, scale=(1.0, 0.3, 0.6))
    k.sphere("head", (0, -0.285, 0.9), 0.022, "#c0504d", scale=(1.3, 0.5, 0.6))
    k.cyl("head", (0, 0, 1.36), 0.14, 0.15, 0.08, GOLD, seg=12)
    for i, x in enumerate((-0.09, 0.0, 0.09)):
        k.cyl("head", (x, -0.07 if i != 1 else -0.1, 1.44), 0.035, 0.0, 0.1, GOLD, seg=8)
    k.sphere("head", (0, -0.15, 1.36), 0.03, ORB)

    # 后背长发（跟随骨）
    k.sphere("hair", (0, 0.15, 0.84), 0.3, HAIR, scale=(1.05, 0.55, 1.35))

    # 手臂：泡泡袖 + 手臂 + 手
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.sphere(bone, (0.21 * side, 0, 0.67), 0.09, WHITE)
        k.cyl(bone, (0.25 * side, -0.02, 0.56), 0.05, 0.045, 0.2, DRESS, rot=(0, -18 * side, 0), seg=10)
        k.sphere(bone, (0.29 * side, -0.05, 0.45), 0.06, SKIN)

    # 法杖：杖身 + 金环 + 宝珠
    k.tube("staff", [(-0.29, -0.06, 0.12), (-0.29, -0.06, 1.12)], 0.026, WOOD)
    k.torus("staff", (-0.29, -0.06, 1.14), 0.07, 0.022, GOLD, seg=14, ring=6)
    k.sphere("staff", (-0.29, -0.06, 1.24), 0.09, ORB)

    # 鞋
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.sphere(bone, (0.1 * side, -0.05, 0.035), 0.07, SHOE, scale=(0.9, 1.3, 0.6))

    _anims(k)


def _anims(k):
    idle = k.clip("Idle", 60, True)
    idle.wave("body", "loc", 2, 0.012, samples=8)
    idle.wave("head", "rot", 1, 3.0, samples=8)
    idle.wave("hair", "rot", 0, 4.0, phase=-0.8, samples=8)
    idle.wave("arm.R", "rot", 0, -3.0, samples=8)
    idle.wave("arm.L", "rot", 1, 4.0, phase=0.5, samples=8)

    walk = k.clip("Walk", 24, True)
    for f, s in ((0, 1), (12, -1), (24, 1)):
        walk.key(f, "foot.R", loc=(0, -0.09 * s, 0))
        walk.key(f, "foot.L", loc=(0, 0.09 * s, 0))
        walk.key(f, "arm.L", rot=(-18 * s, 0, 0))
        walk.key(f, "arm.R", rot=(10 * s, 0, 0))
        walk.key(f, "body", rot=(4, 3 * s, 0), loc=(0, 0, 0))
        walk.key(f, "head", rot=(-3, -2 * s, 0))
        walk.key(f, "hair", rot=(-8, 0, 0))
    for f, s in ((6, 1), (18, -1)):
        walk.key(f, "body", rot=(4, 0, 0), loc=(0, 0, 0.04))
        walk.key(f, "foot.R" if s > 0 else "foot.L", loc=(0, 0, 0.06))
        walk.key(f, "hair", rot=(-14, 0, 0))

    atk = k.clip("Attack", 30, False)
    atk.key(0, "body", rot=(0, 0, 0)).key(0, "arm.R", rot=(0, 0, 0))
    atk.key(9, "body", rot=(-10, 0, -8)).key(9, "arm.R", rot=(-60, 10, 0)).key(9, "head", rot=(-6, 0, 0))
    atk.key(13, "body", rot=(10, 0, 6)).key(13, "arm.R", rot=(-100, 0, 0)).key(13, "head", rot=(6, 0, 0))
    atk.key(13, "hair", rot=(-15, 0, 0)).key(18, "hair", rot=(8, 0, 0))
    atk.key(18, "arm.R", rot=(-95, 0, 0)).key(18, "body", rot=(8, 0, 4))
    atk.key(30, "body", rot=(0, 0, 0)).key(30, "arm.R", rot=(0, 0, 0)).key(30, "head", rot=(0, 0, 0))
    atk.key(30, "hair", rot=(0, 0, 0))

    die = k.clip("Death", 18, False)
    die.key(0, "body", rot=(0, 0, 0), loc=(0, 0, 0))
    die.key(5, "body", rot=(-12, 0, 0), loc=(0, 0, 0.06)).key(5, "head", rot=(-15, 0, 0))
    die.key(5, "arm.R", rot=(-40, 30, 0)).key(5, "arm.L", rot=(-40, -30, 0))
    die.key(18, "body", rot=(-10, 75, 0), loc=(0.15, 0, -0.08)).key(18, "head", rot=(10, 10, 0))
    die.key(18, "arm.R", rot=(20, 40, 0)).key(18, "arm.L", rot=(-60, -20, 0)).key(18, "hair", rot=(20, 0, 0))
