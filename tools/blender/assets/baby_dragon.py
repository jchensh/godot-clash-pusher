"""龙宝宝（baby_dragon_body，锁定卡单位·自行设计，空军溅射；熔岩龙/喷火小龙借用并染色）：圆胖绿色小龙，奶油肚皮，
橙色小角与背刺，深绿小膜翼，短尾；攻击是仰头后向前喷火的动作（火焰特效 D8 另做）。无原画：按 0830 卡通风格自行设计。
"""
import motions

GREEN = "#6fc46a"
GREEN_D = "#4a9a4c"
BELLY = "#fff0c4"
HORN = "#ffad4a"
WING = "#3f8a4a"
EYE = "#1d1612"


def build(k):
    k.bone("body", (0, 0, 0.1), 0.4)
    k.bone("head", (0, -0.12, 0.62), 0.25, "body")
    k.bone("wing.L", (0.22, 0.12, 0.55), 0.1, "body")
    k.bone("wing.R", (-0.22, 0.12, 0.55), 0.1, "body")
    k.bone("tail", (0, 0.3, 0.3), 0.1, "body")
    # 圆胖身体 + 肚皮 + 背刺 + 小脚
    k.sphere("body", (0, 0.05, 0.4), 0.3, GREEN, scale=(1.0, 1.0, 1.0))
    k.sphere("body", (0, -0.17, 0.36), 0.19, BELLY, scale=(1.0, 0.5, 1.15))
    for i, (y, z) in enumerate(((0.15, 0.7), (0.28, 0.6), (0.36, 0.46))):
        k.cyl("body", (0, y, z), 0.06, 0.0, 0.12, HORN, rot=(-30 - i * 25, 0, 0), seg=4, smooth=False)
    for x in (-1, 1):
        k.sphere("body", (0.14 * x, -0.08, 0.1), 0.08, GREEN_D, scale=(1, 1.3, 0.7))
        k.sphere("body", (0.25 * x, -0.12, 0.38), 0.07, GREEN_D)
    # 大头：口鼻 + 鼻孔 + 大眼 + 小角
    k.sphere("head", (0, -0.15, 0.8), 0.25, GREEN)
    k.sphere("head", (0, -0.36, 0.74), 0.15, GREEN, scale=(1.1, 0.9, 0.8))
    for x in (-1, 1):
        k.sphere("head", (0.05 * x, -0.48, 0.77), 0.02, GREEN_D)
        k.sphere("head", (0.1 * x, -0.33, 0.88), 0.055, "#ffffff")
        k.sphere("head", (0.1 * x, -0.37, 0.88), 0.03, EYE)
        k.cyl("head", (0.12 * x, -0.07, 1.02), 0.05, 0.0, 0.14, HORN, rot=(-20, 20 * x, 0), seg=6)
        k.sphere("head", (0.16 * x, -0.32, 0.76), 0.035, "#ff9fb0", scale=(1, 0.3, 0.6))
    # 小膜翼
    for side, bone in ((1, "wing.L"), (-1, "wing.R")):
        k.sphere(bone, (0.4 * side, 0.16, 0.7), 0.22, WING, scale=(1.0, 0.1, 0.55), rot=(0, -side * 30, 0))
        k.sphere(bone, (0.36 * side, 0.17, 0.56), 0.16, GREEN_D, scale=(1.0, 0.1, 0.5), rot=(0, side * 10, 0))
        k.tube(bone, [(0.22 * side, 0.15, 0.6), (0.4 * side, 0.15, 0.78), (0.6 * side, 0.15, 0.8)], 0.025, GREEN_D)
    # 尾巴
    k.tube("tail", [(0, 0.3, 0.28), (0, 0.48, 0.22), (0.08, 0.6, 0.26)], 0.07, GREEN, end_radius=0.03)
    k.cyl("tail", (0.1, 0.65, 0.28), 0.05, 0.0, 0.1, HORN, rot=(-80, 0, 30), seg=4, smooth=False)

    idle = k.clip("Idle", 24, True)
    motions.flap(idle, amp=25.0, cycles=1)
    motions.hover(idle, bob=0.05)
    idle.wave("tail", "rot", 2, 12.0, samples=6)
    fly = k.clip("Walk", 16, True)
    motions.flap(fly, amp=35.0, cycles=1)
    motions.hover(fly, bob=0.04, tilt=10.0)
    fly.wave("tail", "rot", 2, 18.0, samples=6)
    atk = k.clip("Attack", 30, False)   # 吸气仰头 → 向前喷
    motions.flap(atk, amp=25.0, cycles=2)
    atk.key(0, "head", rot=(0, 0, 0)).key(10, "head", rot=(-30, 0, 0)).key(15, "head", rot=(25, 0, 0))
    atk.key(22, "head", rot=(20, 0, 0)).key(30, "head", rot=(0, 0, 0))
    atk.key(0, "body", scale=(1, 1, 1)).key(10, "body", scale=(1.08, 1.08, 1.05)).key(15, "body", scale=(0.95, 0.95, 0.95))
    atk.key(30, "body", scale=(1, 1, 1))
    die = k.clip("Death", 18, False)
    motions.death(die, flier=True, fall=60.0, limbs=("wing.L", "wing.R", "tail"))
