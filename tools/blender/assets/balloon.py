"""马蜂王（balloon_body，大型空军，只打建筑）：大黄蜂——棕色绒胸、紫色大复眼、黄黑条纹大腹带尾针、两对米色大翅、下垂细腿。
原画：testAssets/新风格美术资源0830/动作/马蜂王/马蜂王.png；背面为补全设计。攻击是腹部前刺尾针。
"""
import motions

FUZZ = "#8a5a36"
FUZZ_L = "#b07a4a"
YELLOW = "#ffd23f"
BLACK = "#2b2522"
EYE = "#5a3f8c"
WING = "#efe2c6"
WING_D = "#cdb98f"
LEG = "#3a2c22"


def build(k):
    k.bone("body", (0, 0, 0.6), 0.3)                     # 胸
    k.bone("head", (0, -0.25, 0.85), 0.2, "body")
    k.bone("abdomen", (0, 0.15, 0.62), 0.2, "body")
    k.bone("wing.L", (0.15, 0.08, 1.0), 0.1, "body")
    k.bone("wing.R", (-0.15, 0.08, 1.0), 0.1, "body")
    k.bone("legs", (0, -0.05, 0.5), 0.1, "body")
    # 胸 + 头
    k.sphere("body", (0, 0, 0.85), 0.3, FUZZ, scale=(1.0, 0.95, 0.95))
    k.sphere("body", (0, -0.05, 0.98), 0.2, FUZZ_L, scale=(1.2, 1.0, 0.6))
    k.sphere("head", (0, -0.33, 0.95), 0.25, FUZZ)
    for x in (-1, 1):
        k.sphere("head", (0.14 * x, -0.5, 1.0), 0.11, EYE, scale=(0.8, 0.6, 1.1))
        k.sphere("head", (0.15 * x - 0.02, -0.58, 1.04), 0.03, "#ffffff")
        k.tube("head", [(0.08 * x, -0.42, 1.17), (0.16 * x, -0.5, 1.33), (0.22 * x, -0.56, 1.35)], 0.015, BLACK)
        k.cyl("head", (0.05 * x, -0.55, 0.82), 0.03, 0.0, 0.1, BLACK, rot=(160, 0, 20 * x), seg=5)
    # 黄黑条纹大腹 + 尾针（斜向后下）
    for i, (y, z, r, c) in enumerate(((0.32, 0.62, 0.3, YELLOW), (0.44, 0.52, 0.31, BLACK), (0.55, 0.42, 0.29, YELLOW),
                                      (0.65, 0.33, 0.25, BLACK), (0.73, 0.25, 0.19, YELLOW))):
        k.sphere("abdomen", (0, y, z), r, c, scale=(1.0, 0.7, 0.9))
    k.cyl("abdomen", (0, 0.82, 0.13), 0.06, 0.0, 0.2, BLACK, rot=(-140, 0, 0), seg=6)
    # 两对翅（上大下小）
    for side, bone in ((1, "wing.L"), (-1, "wing.R")):
        k.sphere(bone, (0.42 * side, 0.18, 1.18), 0.36, WING, scale=(1.0, 0.07, 0.5), rot=(0, -side * 25, 0))
        k.sphere(bone, (0.32 * side, 0.25, 0.98), 0.22, WING_D, scale=(1.0, 0.07, 0.55), rot=(0, -side * 5, 0))
    # 六条细腿（下垂）
    for x in (-1, 1):
        for i, y in enumerate((-0.15, 0.0, 0.15)):
            k.tube("legs", [(0.12 * x, y, 0.65), (0.2 * x, y - 0.05, 0.42), (0.17 * x, y - 0.08, 0.25)], 0.022, LEG)

    idle = k.clip("Idle", 16, True)
    motions.flap(idle, amp=26.0, cycles=2)
    motions.hover(idle, bob=0.05)
    idle.wave("abdomen", "rot", 0, -5.0, samples=6)
    idle.wave("legs", "rot", 0, 6.0, phase=1.0, samples=6)
    fly = k.clip("Walk", 12, True)
    motions.flap(fly, amp=32.0, cycles=2)
    motions.hover(fly, bob=0.04, tilt=10.0)
    fly.wave("legs", "rot", 0, 10.0, offset=-15.0, samples=6)
    atk = k.clip("Attack", 30, False)   # 腹部前卷，尾针向前下猛刺
    motions.flap(atk, amp=28.0, cycles=3)
    atk.key(0, "abdomen", rot=(0, 0, 0)).key(10, "abdomen", rot=(-15, 0, 0)).key(15, "abdomen", rot=(60, 0, 0))
    atk.key(20, "abdomen", rot=(50, 0, 0)).key(30, "abdomen", rot=(0, 0, 0))
    atk.key(0, "body", rot=(0, 0, 0)).key(15, "body", rot=(10, 0, 0)).key(30, "body", rot=(0, 0, 0))
    die = k.clip("Death", 18, False)
    motions.death(die, flier=True, fall=60.0, limbs=("wing.L", "wing.R", "legs"))
