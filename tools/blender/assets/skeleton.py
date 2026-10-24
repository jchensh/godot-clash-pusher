"""小骷髅（skeleton_body，锁定卡单位·自行设计，小骷髅/骷髅大军）：大头小身的 Q 版骷髅，黑洞眼里有亮点，肋骨身体，挥小短剑。
无原画：按 0830 卡通风格自行设计。
"""
import motions

BONE = "#f2ecdc"
BONE_D = "#cfc6b0"
HOLE = "#2a2622"
GLOW = "#8fe3ff"
STEEL = "#c9d1d8"
WOOD = "#5b3a24"


def build(k):
    k.bone("body", (0, 0, 0.1), 0.3)
    k.bone("head", (0, 0, 0.48), 0.25, "body")
    k.bone("arm.R", (-0.12, 0, 0.42), 0.08, "body")
    k.bone("arm.L", (0.12, 0, 0.42), 0.08, "body")
    k.bone("foot.R", (-0.07, 0, 0.04), 0.08)
    k.bone("foot.L", (0.07, 0, 0.04), 0.08)
    # 脊柱 + 肋骨 + 骨盆
    k.cyl("body", (0, 0.02, 0.32), 0.03, 0.03, 0.3, BONE_D, seg=6)
    for i, z in enumerate((0.42, 0.36, 0.3)):
        k.torus("body", (0, -0.01, z), 0.1 - i * 0.012, 0.018, BONE, seg=12, ring=4, scale=(1, 0.75, 1))
    k.sphere("body", (0, 0, 0.18), 0.09, BONE, scale=(1.3, 0.8, 0.5))
    # 大骷髅头：头盖 + 下颌 + 眼洞 + 鼻洞 + 牙
    k.sphere("head", (0, 0, 0.66), 0.21, BONE)
    k.box("head", (0, -0.06, 0.5), (0.22, 0.18, 0.1), BONE, bevel=0.4)
    for x in (-1, 1):
        k.sphere("head", (0.08 * x, -0.17, 0.66), 0.06, HOLE, scale=(0.9, 0.5, 1.0))
        k.sphere("head", (0.08 * x, -0.205, 0.67), 0.018, GLOW)
    k.cyl("head", (0, -0.2, 0.58), 0.025, 0.0, 0.05, HOLE, rot=(-90, 0, 0), seg=3, smooth=False)
    for x in (-0.06, -0.02, 0.02, 0.06):
        k.box("head", (x, -0.15, 0.5), (0.03, 0.02, 0.04), "#ffffff", bevel=0.3)
    # 骨头手臂 + 小剑（右手）+ 腿
    for side, bone in ((-1, "arm.R"), (1, "arm.L")):
        k.tube(bone, [(0.12 * side, 0, 0.42), (0.17 * side, -0.03, 0.3)], 0.018, BONE)
        k.sphere(bone, (0.18 * side, -0.04, 0.28), 0.03, BONE)
    k.box("arm.R", (-0.19, -0.05, 0.42), (0.04, 0.015, 0.24), STEEL, bevel=0.3)
    k.box("arm.R", (-0.19, -0.05, 0.3), (0.1, 0.03, 0.025), WOOD, bevel=0.3)
    for side, bone in ((-1, "foot.R"), (1, "foot.L")):
        k.tube(bone, [(0.06 * side, 0, 0.15), (0.07 * side, -0.01, 0.04)], 0.02, BONE)
        k.sphere(bone, (0.07 * side, -0.04, 0.03), 0.035, BONE, scale=(1, 1.5, 0.6))

    idle = k.clip("Idle", 30, True)
    motions.idle(idle, bob=0.01, sway=6.0)
    walk = k.clip("Walk", 14, True)
    motions.walk(walk, stride=0.06, lift=0.05, swing=25.0, lean=6.0)
    atk = k.clip("Attack", 18, False)
    motions.swing_attack(atk, "arm.R", windup=40.0, strike=-80.0, hit=0.45)
    die = k.clip("Death", 18, False)   # 散架：头掉落滚开、身体塌下
    die.key(0, "head", rot=(0, 0, 0), loc=(0, 0, 0)).key(6, "head", loc=(0, 0, 0.12), rot=(-20, 0, 0))
    die.key(18, "head", loc=(0.15, -0.1, -0.38), rot=(40, 0, 90))
    die.key(0, "body", rot=(0, 0, 0), loc=(0, 0, 0)).key(18, "body", rot=(75, 0, 10), loc=(0, -0.05, -0.08))
    die.key(18, "arm.R", rot=(60, 0, 40)).key(18, "arm.L", rot=(60, 0, -40))
