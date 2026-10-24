"""通用卡通动作模板：按骨骼命名约定批量写关键帧（toonkit.Clip，世界轴，单位度）。

骨骼约定：body / head / arm.L / arm.R / foot.L / foot.R / wing.L / wing.R / weapon 等；不存在的骨骼传 None 跳过。
符号约定（竖直骨骼、正面 -Y）：rot x 正 = 向前倾；手臂下垂时 rot x 负 = 向前摆；
左翼(+X) rot y 负 = 上扬，右翼 rot y 正 = 上扬。所有循环首尾闭合。
"""


def idle(clip, body="body", head="head", extra=(), bob=0.012, sway=3.0):
    """待机：身体呼吸起伏 + 头轻摆；extra = [(bone, channel, axis, amp, phase)] 附加摆动。"""
    clip.wave(body, "loc", 2, bob, samples=8)
    if head:
        clip.wave(head, "rot", 1, sway, samples=8)
    for bone, channel, axis, amp, phase in extra:
        clip.wave(bone, channel, axis, amp, phase=phase, samples=8)


def walk(clip, body="body", head="head", feet=("foot.L", "foot.R"), arms=("arm.L", "arm.R"), stride=0.09,
         lift=0.06, swing=18.0, lean=4.0, bob=0.04, extra=()):
    """两足小碎步：双脚前后交替 + 抬脚、身体上下起伏与左右晃、手臂反向摆。"""
    n = clip.frames
    half = n // 2
    for f, s in ((0, 1), (half, -1), (n, 1)):
        if feet[0]:
            clip.key(f, feet[0], loc=(0, -stride * s, 0))
        if feet[1]:
            clip.key(f, feet[1], loc=(0, stride * s, 0))
        if arms[0]:
            clip.key(f, arms[0], rot=(-swing * s, 0, 0))
        if arms[1]:
            clip.key(f, arms[1], rot=(swing * s, 0, 0))
        clip.key(f, body, rot=(lean, 3 * s, 0), loc=(0, 0, 0))
        if head:
            clip.key(f, head, rot=(-lean * 0.6, -2 * s, 0))
    for f, s in ((half // 2, 1), (half + half // 2, -1)):
        clip.key(f, body, rot=(lean, 0, 0), loc=(0, 0, bob))
        foot = feet[1] if s > 0 else feet[0]
        if foot:
            clip.key(f, foot, loc=(0, 0, lift))
    for bone, channel, axis, amp, phase in extra:
        clip.wave(bone, channel, axis, amp, phase=phase, samples=8)


def hop(clip, body="body", head="head", height=0.12, squash=0.12, extra=()):
    """史莱姆/无腿单位的蹦跳前进：落地压扁 → 起跳拉长 → 腾空 → 落地。"""
    n = clip.frames
    q = n // 4
    clip.key(0, body, loc=(0, 0, 0), scale=(1 + squash, 1 + squash, 1 - squash))
    clip.key(q, body, loc=(0, 0, height * 0.6), scale=(1 - squash * 0.6, 1 - squash * 0.6, 1 + squash))
    clip.key(2 * q, body, loc=(0, 0, height), scale=(1, 1, 1))
    clip.key(3 * q, body, loc=(0, 0, height * 0.4), scale=(1 - squash * 0.3, 1 - squash * 0.3, 1 + squash * 0.5))
    clip.key(n, body, loc=(0, 0, 0), scale=(1 + squash, 1 + squash, 1 - squash))
    if head:
        clip.key(0, head, rot=(-4, 0, 0)).key(2 * q, head, rot=(4, 0, 0)).key(n, head, rot=(-4, 0, 0))
    for bone, channel, axis, amp, phase in extra:
        clip.wave(bone, channel, axis, amp, phase=phase, samples=8)


def flap(clip, wings=("wing.L", "wing.R"), amp=30.0, base=0.0, cycles=1):
    """扇翅：上扬 → 下拍，cycles 次/片段；base 为整体上扬角。"""
    n = clip.frames
    for i in range(cycles * 2 + 1):
        f = round(n * i / (cycles * 2))
        s = 1 if i % 2 == 0 else -1
        a = base + amp * s
        if wings[0]:
            clip.key(f, wings[0], rot=(0, -a, 0))
        if wings[1]:
            clip.key(f, wings[1], rot=(0, a, 0))


def hover(clip, body="body", bob=0.06, tilt=0.0):
    clip.wave(body, "loc", 2, bob, samples=6, base=(0, 0, 0))
    if tilt:
        for f in (0, clip.frames):
            clip.key(f, body, rot=(tilt, 0, 0))


def swing_attack(clip, arm, body="body", head="head", windup=-40.0, strike=70.0, hit=0.45, twist=12.0,
                 arm_axis=0, lunge=0.08):
    """近战挥砍：蓄力后仰 → 快速劈下（hit 为打击时刻占比）→ 收势。arm_axis=0 竖劈，1 横扫。"""
    n = clip.frames
    w = round(n * (hit - 0.15))
    h = round(n * hit)
    r = round(n * (hit + 0.2))

    def arm_rot(a):
        return (a, 0, 0) if arm_axis == 0 else (0, 0, a)

    clip.key(0, body, rot=(0, 0, 0), loc=(0, 0, 0)).key(0, arm, rot=(0, 0, 0))
    clip.key(w, body, rot=(-8, 0, twist), loc=(0, lunge * 0.3, 0)).key(w, arm, rot=arm_rot(windup))
    clip.key(h, body, rot=(12, 0, -twist), loc=(0, -lunge, 0)).key(h, arm, rot=arm_rot(strike))
    clip.key(r, body, rot=(6, 0, -twist * 0.5), loc=(0, -lunge * 0.6, 0)).key(r, arm, rot=arm_rot(strike * 0.8))
    clip.key(n, body, rot=(0, 0, 0), loc=(0, 0, 0)).key(n, arm, rot=(0, 0, 0))
    if head:
        clip.key(0, head, rot=(0, 0, 0)).key(w, head, rot=(-6, 0, 0)).key(h, head, rot=(8, 0, 0)).key(n, head, rot=(0, 0, 0))


def shoot_attack(clip, gun, body="body", head="head", aim=-70.0, recoil=14.0, kick=0.06, hit=0.45):
    """远程射击：抬手瞄准 → 开火后坐（gun 后仰 + 身体后挫）→ 放下。aim 为手臂前抬角。"""
    n = clip.frames
    a = round(n * (hit - 0.2))
    h = round(n * hit)
    clip.key(0, gun, rot=(0, 0, 0)).key(0, body, rot=(0, 0, 0), loc=(0, 0, 0))
    clip.key(a, gun, rot=(aim, 0, 0)).key(a, body, rot=(4, 0, 0))
    clip.key(h, gun, rot=(aim - recoil, 0, 0)).key(h, body, rot=(-8, 0, 0), loc=(0, kick, 0))
    clip.key(round(n * (hit + 0.15)), gun, rot=(aim + 4, 0, 0)).key(round(n * (hit + 0.15)), body, rot=(2, 0, 0), loc=(0, 0, 0))
    clip.key(n, gun, rot=(0, 0, 0)).key(n, body, rot=(0, 0, 0), loc=(0, 0, 0))
    if head:
        clip.key(h, head, rot=(-6, 0, 0)).key(n, head, rot=(0, 0, 0))


def lunge_attack(clip, body="body", head="head", dist=0.22, pitch=25.0, hit=0.45, squash=0.0):
    """扑击/撞击（无手或骑乘单位）：后缩蓄力 → 向前扑 → 回位。"""
    n = clip.frames
    w = round(n * (hit - 0.18))
    h = round(n * hit)
    s0 = (1, 1, 1)
    clip.key(0, body, rot=(0, 0, 0), loc=(0, 0, 0), scale=s0)
    clip.key(w, body, rot=(-pitch * 0.5, 0, 0), loc=(0, dist * 0.4, 0),
             scale=(1 + squash, 1 + squash, 1 - squash) if squash else s0)
    clip.key(h, body, rot=(pitch, 0, 0), loc=(0, -dist, 0.02),
             scale=(1 - squash * 0.5, 1 - squash * 0.5, 1 + squash) if squash else s0)
    clip.key(n, body, rot=(0, 0, 0), loc=(0, 0, 0), scale=s0)
    if head:
        clip.key(w, head, rot=(-10, 0, 0)).key(h, head, rot=(14, 0, 0)).key(n, head, rot=(0, 0, 0))


def death(clip, body="body", head="head", fall=75.0, side=1, drop=-0.08, limbs=(), flier=False,
          feet=("foot.L", "foot.R")):
    """死亡（18 帧）：受击后仰 → 侧倒（飞行单位翻转坠落）→ 定格；limbs 软塌；脚跟随倒向（不留在原地）。
    不存在的骨骼会被 toonkit 忽略，模板可放心引用通用名。"""
    n = clip.frames
    k = round(n * 0.28)
    clip.key(0, body, rot=(0, 0, 0), loc=(0, 0, 0))
    clip.key(k, body, rot=(-12, 0, 0), loc=(0, 0.04, 0.06))
    if flier:
        clip.key(n, body, rot=(50, fall * side * 2, 0), loc=(0, 0, -0.45))
    else:
        clip.key(n, body, rot=(-10, fall * side, 0), loc=(0.12 * side, 0, drop))
    if head:
        clip.key(k, head, rot=(-15, 0, 0)).key(n, head, rot=(12, 10 * side, 0))
    for bone in limbs:
        clip.key(k, bone, rot=(-30, 0, 0)).key(n, bone, rot=(25, 0, 0))
    if not flier:
        for bone in feet:
            clip.key(0, bone, rot=(0, 0, 0), loc=(0, 0, 0))
            clip.key(n, bone, rot=(0, fall * side * 0.5, 0), loc=(0.14 * side, 0, 0.06))
