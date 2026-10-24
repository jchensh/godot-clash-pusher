"""史莱姆系共用构件（岩石史莱姆 / 锤锤莱姆 / 棒槌史莱姆 / 小岩史莱姆）：圆顶软体 + Q 版脸 + 蹦跳/融化动作。"""
import motions

EYE = "#1d1a18"
BLUSH = "#ff9fb0"


def blob(k, radius, color, color_d, height=0.8, face_z=None, angry=False):
    """圆顶身体（body 骨）+ 底部压扁裙边 + 脸。返回脸的高度。"""
    r = radius
    k.sphere("body", (0, 0, r * height), r, color, scale=(1.08, 1.0, height))
    k.sphere("body", (0, 0, r * 0.18), r * 1.05, color_d, scale=(1.1, 1.05, 0.22))
    fz = face_z if face_z is not None else r * height * 1.05
    front = -r * 0.93
    for x in (-1, 1):
        k.sphere("body", (r * 0.3 * x, front, fz), r * 0.11, EYE, scale=(0.8, 0.5, 1.2))
        k.sphere("body", (r * 0.32 * x - r * 0.03, front - r * 0.05, fz + r * 0.04), r * 0.035, "#ffffff")
        k.sphere("body", (r * 0.52 * x, front * 0.92, fz - r * 0.14), r * 0.09, BLUSH, scale=(1, 0.3, 0.6))
        if angry:
            k.box("body", (r * 0.3 * x, front - r * 0.02, fz + r * 0.2), (r * 0.26, r * 0.05, r * 0.06), EYE,
                  rot=(0, -28 * x, 0), bevel=0.3)
    k.sphere("body", (0, front, fz - r * 0.2), r * 0.06, "#7a2f2a", scale=(1.6, 0.5, 0.7))
    return fz


def anims(k, weapon=None, shield=None, slow=1.0, strike=-95.0):
    idle = k.clip("Idle", int(50 * slow), True)
    idle.wave("body", "scale", 2, 0.04, base=(1, 1, 1), samples=8)
    if weapon:
        idle.wave(weapon, "rot", 0, 3.0, phase=0.5, samples=8)
    walk = k.clip("Walk", int(20 * slow), True)
    motions.hop(walk, head=None, height=0.14, squash=0.12)
    atk = k.clip("Attack", int(30 * slow), False)
    if weapon:
        motions.swing_attack(atk, weapon, head=None, windup=45.0, strike=strike, hit=0.48, lunge=0.1)
    if shield:
        atk.key(0, shield, rot=(0, 0, 0)).key(round(atk.frames * 0.48), shield, rot=(-15, 0, 0)).key(atk.frames, shield, rot=(0, 0, 0))
    atk.key(round(atk.frames * 0.48), "body", scale=(1.12, 1.12, 0.86)).key(0, "body", scale=(1, 1, 1))
    atk.key(atk.frames, "body", scale=(1, 1, 1))
    die = k.clip("Death", 18, False)   # 融化：压扁摊开 + 下沉，武器倒地
    die.key(0, "body", scale=(1, 1, 1), loc=(0, 0, 0))
    die.key(5, "body", scale=(0.9, 0.9, 1.15), loc=(0, 0, 0.04))
    die.key(18, "body", scale=(1.45, 1.45, 0.25), loc=(0, 0, -0.04))
    for bone, side in ((weapon, -1), (shield, 1)):
        if bone:
            die.key(0, bone, rot=(0, 0, 0)).key(18, bone, rot=(30, side * 70, 0), loc=(0.1 * side, 0, -0.1))
