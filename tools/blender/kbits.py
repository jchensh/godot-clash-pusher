"""kbits —— 王国建筑（D6）共用构件：拱门、窗、坡屋顶、尖塔顶、栅栏、旗子。都挂 root 骨（静态资产）。

坐标约定同 toonkit：米制、Z 向上、正面朝 -Y、原点在占地底面中心。门窗贴在「正面墙」y 平面上（略外凸防共面）。
"""

B = "root"

CREAM = "#f3e6c8"
CREAM_D = "#ddc9a1"
BLUE = "#3f78d0"
BLUE_D = "#2c58a6"
BLUE_L = "#6da2ea"
WOOD = "#b27b45"
WOOD_D = "#7d5230"
STONE = "#c9c3b5"
STONE_D = "#a19a8a"
GOLD = "#f6c343"
GOLD_D = "#d39a2a"
GREEN = "#7cc36a"
GREEN_D = "#58a04c"
RED = "#d9483b"
GLASS = "#a8dcf2"
DARK = "#4a3423"
GRASS = "#8fcf6a"


def dome_rib(k, cx, cy, cz, r, zscale, yaw, color, thick=0.05, steps=10):
    """穹顶上的半圆肋条（只取地平线以上半弧，免得整圈圆环从墙外穿出）。yaw 为肋条所在竖直面的朝向（度）。"""
    import math
    a = math.radians(yaw)
    pts = []
    for i in range(steps + 1):
        t = math.pi * i / steps
        pts.append((cx + math.cos(t) * r * math.cos(a), cy + math.cos(t) * r * math.sin(a), cz + math.sin(t) * r * zscale))
    k.tube(B, pts, thick, color, seg=6)


def on_dome(cx, cy, cz, r, zscale, x, y, lift=0.0):
    """椭球穹顶（半径 r、竖向缩放 zscale）上 (x, y) 处的表面高度，供斑点/星星贴面摆放。"""
    import math
    d2 = ((x - cx) ** 2 + (y - cy) ** 2) / (r * r)
    return cz + r * zscale * math.sqrt(max(0.0, 1.0 - d2)) + lift


def door(k, x, y, z0, w, h, color=WOOD_D, frame=CREAM_D):
    """拱顶木门：门板 + 半圆拱 + 门框（y 为墙面，门向 -y 凸出）。"""
    k.box(B, (x, y - 0.02, z0 + h * 0.5 + 0.02), (w + 0.2, 0.1, h + 0.1), frame, bevel=0.15)
    k.box(B, (x, y - 0.08, z0 + (h - w * 0.5) * 0.5), (w, 0.1, h - w * 0.5), color, bevel=0.1)
    k.cyl(B, (x, y - 0.08, z0 + h - w * 0.5), w * 0.5, w * 0.5, 0.1, color, rot=(90, 0, 0), seg=12)
    k.box(B, (x, y - 0.14, z0 + (h - w * 0.5) * 0.5), (0.04, 0.03, h - w * 0.5), DARK, bevel=0)


def window(k, x, y, z, w, h, glass=GLASS, frame=WOOD_D):
    k.box(B, (x, y - 0.03, z), (w + 0.12, 0.06, h + 0.12), frame, bevel=0.2)
    k.box(B, (x, y - 0.07, z), (w, 0.04, h), glass, bevel=0.1)


def round_window(k, x, y, z, r, glass=GLASS, frame=WOOD_D):
    k.cyl(B, (x, y - 0.03, z), r + 0.07, r + 0.07, 0.06, frame, rot=(90, 0, 0), seg=14)
    k.cyl(B, (x, y - 0.07, z), r, r, 0.04, glass, rot=(90, 0, 0), seg=14)


def gable(k, cx, cy, base_z, length, depth, height, color, axis="x"):
    """三棱柱坡屋顶（显式建点，屋脊居中）：axis=x 屋脊左右走向（正面看到斜坡），axis=y 前后走向（正面看到山墙三角）。
    length 沿屋脊，depth 为屋檐跨度，height 为屋脊高；(cx, cy, base_z) 为檐口底面中心。"""
    import bmesh
    hl, hd = length * 0.5, depth * 0.5
    prof = [(-hd, 0.0), (hd, 0.0), (0.0, height)]
    verts = []
    for along in (-hl, hl):
        for (u, z) in prof:
            verts.append(k.bm.verts.new((along, u, z) if axis == "x" else (u, along, z)))
    a0, a1, a2, b0, b1, b2 = verts
    faces = [k.bm.faces.new(f) for f in ((a0, a2, a1), (b0, b1, b2), (a0, a1, b1, b0), (a1, a2, b2, b1),
                                        (a2, a0, b0, b2))]
    bmesh.ops.recalc_face_normals(k.bm, faces=faces)
    k._finish(verts, B, color, (cx, cy, base_z), (0, 0, 0), (1, 1, 1), smooth=False)


def spire(k, x, y, z, r, h, color, seg=8, tip=GOLD):
    """圆锥尖顶 + 金色顶珠。"""
    k.cyl(B, (x, y, z + h * 0.5), r, 0.0, h, color, seg=seg, smooth=False)
    k.sphere(B, (x, y, z + h + 0.05), max(r * 0.12, 0.05), tip)


def round_tower(k, x, y, r, h, wall=CREAM, roof=BLUE, roof_h=None, band=STONE_D):
    """圆塔：塔身 + 底边石带 + 檐口 + 尖顶。"""
    k.cyl(B, (x, y, h * 0.5), r, r, h, wall, seg=14)
    k.cyl(B, (x, y, 0.12), r + 0.06, r + 0.06, 0.24, band, seg=14)
    k.cyl(B, (x, y, h), r + 0.12, r + 0.12, 0.14, band, seg=14)
    spire(k, x, y, h + 0.05, r + 0.18, roof_h or r * 2.4, roof)


def fence(k, x0, x1, y0, y1, h=0.45, post=WOOD_D, rail=WOOD, step=0.55, sides="nsew", gap=None):
    """矩形栅栏：四角+等距立柱、两道横栏；gap=(side, center, width) 留开口。"""
    def run(ax, a0, a1, fixed, side):
        n = max(1, int(round(abs(a1 - a0) / step)))
        for i in range(n + 1):
            t = a0 + (a1 - a0) * i / n
            if gap and gap[0] == side and abs(t - gap[1]) < gap[2] * 0.5:
                continue
            p = (t, fixed) if ax == "x" else (fixed, t)
            k.box(B, (p[0], p[1], h * 0.5), (0.1, 0.1, h), post, bevel=0.2)
        for z in (h * 0.4, h * 0.8):
            segs = [(a0, a1)]
            if gap and gap[0] == side:
                segs = [(a0, gap[1] - gap[2] * 0.5), (gap[1] + gap[2] * 0.5, a1)]
            for s0, s1 in segs:
                if s1 - s0 < 0.05:
                    continue
                c = (s0 + s1) * 0.5
                p = (c, fixed) if ax == "x" else (fixed, c)
                size = (s1 - s0, 0.06, 0.07) if ax == "x" else (0.06, s1 - s0, 0.07)
                k.box(B, (p[0], p[1], z), size, rail, bevel=0.2)
    if "s" in sides:
        run("x", x0, x1, y0, "s")
    if "n" in sides:
        run("x", x0, x1, y1, "n")
    if "w" in sides:
        run("y", y0, y1, x0, "w")
    if "e" in sides:
        run("y", y0, y1, x1, "e")


def flag(k, x, y, z, pole_h, color=BLUE, w=0.55, h=0.32):
    k.tube(B, [(x, y, z), (x, y, z + pole_h)], 0.035, WOOD_D)
    k.box(B, (x + w * 0.5, y, z + pole_h - h * 0.5 - 0.02), (w, 0.04, h), color, bevel=0.15)
    k.sphere(B, (x, y, z + pole_h + 0.04), 0.06, GOLD)


def shield(k, x, y, z, s, field=BLUE, rim=GOLD, emblem=GOLD):
    """正面盾徽（贴墙）：金边 + 底色 + 星形徽记。"""
    k.box(B, (x, y - 0.03, z + s * 0.12), (s, 0.06, s * 0.7), rim, bevel=0.25)
    k.box(B, (x, y - 0.03, z - s * 0.2), (s * 0.62, 0.06, s * 0.62), rim, rot=(0, 45, 0), bevel=0.2)
    k.box(B, (x, y - 0.06, z + s * 0.12), (s * 0.8, 0.05, s * 0.55), field, bevel=0.25)
    k.box(B, (x, y - 0.06, z - s * 0.17), (s * 0.48, 0.05, s * 0.48), field, rot=(0, 45, 0), bevel=0.2)
    star(k, x, y - 0.1, z + s * 0.08, s * 0.24, emblem)


def star(k, x, y, z, r, color):
    """五角星（贴正面）：五根细尖锥。"""
    import math
    for i in range(5):
        a = math.radians(i * 72)
        k.cyl(B, (x + math.sin(a) * r * 0.5, y, z + math.cos(a) * r * 0.5), r * 0.36, 0.0, r, color,
              rot=(0, i * 72, 0), seg=4, smooth=False, scale=(1.0, 0.3, 1.0))


def bush(k, x, y, r=0.3, color=GREEN):
    k.sphere(B, (x, y, r * 0.7), r, color, scale=(1.0, 1.0, 0.8))
    k.sphere(B, (x + r * 0.6, y + 0.05, r * 0.5), r * 0.7, GREEN_D)


def barrel(k, x, y, r=0.22, h=0.45):
    k.cyl(B, (x, y, h * 0.5), r, r, h, WOOD, seg=12)
    for z in (h * 0.25, h * 0.75):
        k.cyl(B, (x, y, z), r + 0.02, r + 0.02, 0.05, STONE_D, seg=12)


def sack(k, x, y, s=0.22, color="#e8d7a6"):
    k.sphere(B, (x, y, s * 0.8), s, color, scale=(1.0, 0.9, 1.0))
    k.cyl(B, (x, y, s * 1.7), s * 0.3, s * 0.15, s * 0.3, "#c9b17a", seg=8)


def base_plate(k, w, d, color=STONE_D, h=0.16):
    """占地底座：圆角石板，压住建筑与地面的交界。"""
    k.box(B, (0, 0, h * 0.5), (w, d, h), color, bevel=0.35)
