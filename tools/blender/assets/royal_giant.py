"""瓜牛炮（royal_giant_body）：绿色蜗牛背着褐色螺壳，壳顶架一门黑铁大炮，炮尾引信冒黄星。
原画：testAssets/新风格美术资源0830/动作/瓜牛炮/瓜牛炮.png；壳另一侧螺纹与背面为补全设计。
大型单位：缓慢蠕行，开炮有后坐 + 身体压缩。
"""

GREEN = "#8fd16a"
GREEN_D = "#5fa845"
SHELL = "#9a5b34"
SHELL_D = "#6e3d22"
IRON = "#4a4f57"
IRON_D = "#2e3238"
EYE = "#2b2422"
WHITE = "#ffffff"
BLUSH = "#ff9fa8"
STAR = "#ffd23f"


def build(k):
    k.bone("body", (0, 0, 0.05), 0.3)
    k.bone("head", (0, -0.42, 0.3), 0.3, "body")
    k.bone("ant.R", (-0.12, -0.6, 0.78), 0.15, "head")
    k.bone("ant.L", (0.12, -0.6, 0.78), 0.15, "head")
    k.bone("shell", (0, 0.12, 0.3), 0.4, "body")
    k.bone("cannon", (0, 0.05, 1.05), 0.2, "shell")

    # 腹足 + 身体
    k.sphere("body", (0, 0.05, 0.14), 0.5, GREEN_D, scale=(0.78, 1.45, 0.32))
    k.sphere("body", (0, -0.15, 0.26), 0.36, GREEN, scale=(0.95, 1.4, 0.6))

    # 头：抬起的颈 + 大眼 + 腮红 + 小嘴；触角
    k.sphere("head", (0, -0.5, 0.52), 0.28, GREEN, scale=(1.0, 0.9, 1.05))
    for x in (-1, 1):
        k.sphere("head", (0.11 * x, -0.74, 0.57), 0.06, EYE, scale=(0.85, 0.5, 1.2))
        k.sphere("head", (0.125 * x - 0.012, -0.775, 0.6), 0.02, WHITE)
        k.sphere("head", (0.19 * x, -0.71, 0.47), 0.05, BLUSH, scale=(1.0, 0.3, 0.6))
    k.sphere("head", (0, -0.78, 0.46), 0.03, "#7a3b2e", scale=(1.4, 0.5, 0.6))
    for side, bone in ((-1, "ant.R"), (1, "ant.L")):
        k.tube(bone, [(0.12 * side, -0.6, 0.74), (0.17 * side, -0.66, 0.92)], 0.025, GREEN_D)
        k.sphere(bone, (0.17 * side, -0.66, 0.95), 0.045, GREEN)

    # 螺壳：主体 + 两侧螺纹环 + 壳口
    k.sphere("shell", (0, 0.2, 0.66), 0.5, SHELL, scale=(0.72, 0.95, 0.95))
    for x in (-1, 1):
        k.torus("shell", (0.33 * x, 0.2, 0.66), 0.3, 0.05, SHELL_D, rot=(0, 90, 0), seg=18, ring=6)
        k.torus("shell", (0.355 * x, 0.23, 0.69), 0.16, 0.045, SHELL_D, rot=(0, 90, 0), seg=14, ring=6)
        k.sphere("shell", (0.36 * x, 0.25, 0.71), 0.07, SHELL_D, scale=(0.4, 1, 1))
    k.torus("shell", (0, -0.12, 0.42), 0.28, 0.05, SHELL_D, rot=(70, 0, 0), seg=16, ring=6)

    # 大炮：炮座 + 炮管（朝前上方）+ 炮口箍 + 炮尾引信黄星
    k.cyl("cannon", (0, 0.12, 1.1), 0.2, 0.22, 0.14, IRON_D, seg=12)
    k.cyl("cannon", (0, -0.2, 1.2), 0.15, 0.17, 0.85, IRON, rot=(72, 0, 0), seg=14)
    k.torus("cannon", (0, -0.6, 1.33), 0.15, 0.045, IRON_D, rot=(72, 0, 0), seg=14, ring=6)
    k.sphere("cannon", (0, 0.2, 1.16), 0.13, IRON)
    k.tube("cannon", [(0, 0.3, 1.2), (0.03, 0.38, 1.33)], 0.015, "#3a2a1a")
    for i in range(5):
        a = i * 72
        k.cyl("cannon", (0.03, 0.39, 1.36), 0.035, 0.0, 0.16, STAR, rot=(a, 90, 0), seg=4, smooth=False)
    k.sphere("cannon", (0.03, 0.39, 1.36), 0.05, STAR)

    _anims(k)


def _anims(k):
    idle = k.clip("Idle", 60, True)
    idle.wave("shell", "rot", 0, 2.5, samples=8)
    idle.wave("head", "rot", 1, 4.0, phase=0.6, samples=8)
    idle.wave("ant.R", "rot", 1, 10.0, samples=8)
    idle.wave("ant.L", "rot", 1, -10.0, phase=0.9, samples=8)
    idle.wave("body", "scale", 2, 0.03, base=(1, 1, 1), samples=8)

    walk = k.clip("Walk", 36, True)
    for f, s in ((0, 1), (18, -1), (36, 1)):
        walk.key(f, "body", scale=(1.0, 1.0 + 0.08 * s, 1.0 - 0.06 * s))
        walk.key(f, "head", rot=(6 * s, 0, 0), loc=(0, -0.04 * s, 0))
        walk.key(f, "shell", rot=(-3 * s, 0, 0))
        walk.key(f, "ant.R", rot=(10 * s, 0, 0)).key(f, "ant.L", rot=(10 * s, 0, 0))

    atk = k.clip("Attack", 40, False)
    atk.key(0, "cannon", rot=(0, 0, 0), loc=(0, 0, 0)).key(0, "body", scale=(1, 1, 1))
    atk.key(10, "cannon", rot=(-6, 0, 0), loc=(0, 0.04, 0)).key(10, "head", rot=(-8, 0, 0))
    atk.key(13, "cannon", rot=(14, 0, 0), loc=(0, 0.18, -0.03)).key(13, "body", scale=(1.08, 1.0, 0.86))
    atk.key(13, "shell", rot=(-8, 0, 0)).key(13, "head", rot=(10, 0, 0))
    atk.key(22, "cannon", rot=(4, 0, 0), loc=(0, 0.05, 0)).key(22, "body", scale=(0.97, 1.0, 1.04))
    atk.key(22, "shell", rot=(2, 0, 0))
    atk.key(40, "cannon", rot=(0, 0, 0), loc=(0, 0, 0)).key(40, "body", scale=(1, 1, 1))
    atk.key(40, "shell", rot=(0, 0, 0)).key(40, "head", rot=(0, 0, 0))

    die = k.clip("Death", 18, False)
    die.key(0, "body", scale=(1, 1, 1)).key(0, "shell", rot=(0, 0, 0))
    die.key(6, "shell", rot=(0, -15, 0), loc=(0, 0, 0.08)).key(6, "head", rot=(-20, 0, 0))
    die.key(18, "shell", rot=(0, 70, 0), loc=(0.2, 0, -0.15)).key(18, "head", rot=(35, 0, 0), loc=(0, 0, -0.12))
    die.key(18, "body", scale=(1.1, 1.05, 0.6)).key(18, "cannon", rot=(30, 20, 0))
    die.key(18, "ant.R", rot=(40, 0, 0)).key(18, "ant.L", rot=(40, 0, 0))
