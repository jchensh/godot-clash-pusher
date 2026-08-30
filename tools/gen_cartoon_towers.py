#!/usr/bin/env python3
"""卡通塔美术欠账补位生成器（决策 49 P4 / KAN-124，2026-08-30）。

产出两件事：①另一阵营的配色套（红顶→蓝顶）；②王塔废墟（原先与箭塔废墟共用一张，
王塔倒下是决胜瞬间却看不出区别）。

—— ① 阵营配色套 ——
背景：0830 卡通塔素材只交付**一套**（红顶），另一方原本靠运行时整体乘红
（`Color.WHITE.lerp(红, 0.40)`）区分——但素材主色本身就含高饱和红（箭塔红顶
208,32,32 / 王塔暗红 112,0,0），整体乘红后敌我都偏红、且石墙木头一起脏。

方案：**离线派生蓝顶版**——只把红色系高饱和像素（色相落在红带 + 饱和度够高）旋到蓝，
石头/木头/米色一律不动，得到经典红蓝对立；运行时 tint 归位（敌我同为轻染 0.12，
见 view/battle_scene.gd `_draw_tower_one`）。

⚠️ 阵营指派（0830 用户拍板）：**我方=蓝顶（本脚本派生）/ 敌方=红顶（美术原生素材）**，
与 HUD 阵营色 `COL_PLAYER`(蓝)/`COL_OPPONENT`(红) 统一。故派生件名用中性的 `_blue`
后缀而非 `_enemy`——它是我方的皮，别被旧命名误导。

—— ② 王塔废墟 ——
沿用美术在箭塔废墟里定下的「废墟语言」（俯视空壳 + 锯齿断口 + 石板地 + 散落木梁），
放大到王塔尺寸后，把王塔上的金王冠抠下来蒙尘、倾倒着摆进内院 → 一眼读出「王塔倒了」。
废墟无阵营色（全是石砾）→ 敌我共用一张，归属靠左右半场位置读。

⚠️ 两者都是**高质量占位**：美术出正式素材后直接覆盖同名文件即可，代码零改。

用法： uv run --with pillow python tools/gen_cartoon_towers.py
产物（入 git）： assets/towers/cartoon_tower_{king,arrow}_blue.png
                assets/towers/cartoon_tower_king_broken.png
"""
import colorsys
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.stdout.reconfigure(encoding="utf-8")   # Windows 控制台默认 cp1252，中文输出需显式 UTF-8

SRC = "assets/towers"
# 只派生「活着的」两座塔：废墟(arrow_broken)全是无色石砾、红像素仅 0.9%，
# 派生出来与原图几乎一致 → 双方共用一张废墟（归属靠左右半场位置读，不靠颜色）。
NAMES = ["cartoon_tower_king", "cartoon_tower_arrow"]

# —— 红→蓝映射参数（红带定义与目标色相）——
# 红带 = 色相在 [RED_LO, 360) ∪ [0, RED_HI]（跨 0° 的环形区间），且饱和度 ≥ S_MIN。
# 米色(h≈40)/棕木(h≈24~30)/灰石(s≈0)全部落在带外 → 天然不受影响。
RED_LO = 330.0
RED_HI = 20.0
S_MIN = 0.35
BLUE_H = 212.0    # 目标色相（天空蓝系，与 UI 换肤「天空牧场」同家族）
BLUE_S = 1.06     # 饱和度微增（蓝在同明度下观感比红弱，补一点才等重）
BLUE_V = 1.02     # 明度微提（避免深红旋蓝后糊成黑块）

# 每张图预期改动像素数下限（防「静默没改到」——批量改写必须 assert 命中）
MIN_HITS = {
    "cartoon_tower_king": 1000,
    "cartoon_tower_arrow": 2000,
}


def in_red_band(h_deg: float, s: float) -> bool:
    if s < S_MIN:
        return False
    return h_deg >= RED_LO or h_deg <= RED_HI


def to_blue(im: Image.Image) -> tuple[Image.Image, int]:
    """红色系像素旋成蓝色系，其余原样返回。返回 (新图, 改动像素数)。"""
    out = im.copy()
    px = out.load()
    w, h = out.size
    hits = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if not in_red_band(hh * 360.0, ss):
                continue
            nr, ng, nb = colorsys.hsv_to_rgb(
                BLUE_H / 360.0, min(1.0, ss * BLUE_S), min(1.0, vv * BLUE_V)
            )
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
            hits += 1
    return out, hits


def _gold_mask(im: Image.Image) -> set:
    """王塔贴图上的金王冠像素集（金色带 + 外圈暗金描边，排除红旗）。"""
    px = im.load()
    w, h = im.size
    core = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 200:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if 35 <= hh * 360 <= 58 and ss >= 0.55 and vv >= 0.55:
                core.add((x, y))
    # 膨胀 2px 捞回王冠自身的暗金描边；红旗像素（红带）在此被挡掉。
    grown = set(core)
    for _ in range(2):
        ring = set()
        for x, y in grown:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p in grown or not (0 <= p[0] < w and 0 <= p[1] < h):
                    continue
                r, g, b, a = px[p]
                if a < 200:
                    continue
                hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                if 20 <= hh * 360 <= 62:      # 暗金/褐金收，红旗(h≈0)拒
                    ring.add(p)
        grown |= ring
    return _largest_blob(grown)


def _largest_blob(pts: set) -> set:
    """只留最大连通块——王塔贴图上有零星金色噪点，混进来会在废墟里变成孤立黑点。"""
    seen = set()
    best: set = set()
    for seed in pts:
        if seed in seen:
            continue
        blob = {seed}
        seen.add(seed)
        stack = [seed]
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    p = (x + dx, y + dy)
                    if p in pts and p not in seen:
                        seen.add(p)
                        blob.add(p)
                        stack.append(p)
        if len(blob) > len(best):
            best = blob
    return best


def _outline(im: Image.Image, color: tuple, px_w: int) -> Image.Image:
    """给不透明区域补一圈外描边（画布四周留出 px_w 边距容纳）。"""
    pad = px_w + 1
    big = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    big.alpha_composite(im, (pad, pad))
    a = big.getchannel("A")
    ring = a.filter(ImageFilter.MaxFilter(px_w * 2 + 1))
    stroke = Image.new("RGBA", big.size, color)
    stroke.putalpha(ring)
    stroke.alpha_composite(big)
    return stroke


def make_king_ruin(king: Image.Image, arrow_ruin: Image.Image) -> Image.Image:
    """王塔废墟：以美术的箭塔废墟为底（沿用其断口/石板/木梁笔触）放大到王塔尺寸，
    再放一顶蒙尘的金王冠倒在瓦砾中——王塔倒下是决胜瞬间，需一眼可辨。
    废墟无阵营色 → 敌我共用一张。"""
    kw = king.width
    scale = kw / arrow_ruin.width
    base = arrow_ruin.resize(
        (kw, round(arrow_ruin.height * scale)), Image.LANCZOS
    ).convert("RGBA")

    # —— 抠王冠 ——
    mask = _gold_mask(king)
    assert len(mask) >= 300, f"王冠像素只抠到 {len(mask)}，王塔素材或阈值变了"
    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    crown = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
    kpx = king.load()
    cpx = crown.load()
    for x, y in mask:
        cpx[x - box[0], y - box[1]] = kpx[x, y]

    # —— 蒙尘：去饱和 15% + 压暗 18%（躺在灰石瓦砾里的金不该像 UI 图标那样亮）——
    dpx = crown.load()
    for y in range(crown.height):
        for x in range(crown.width):
            r, g, b, a = dpx[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            nr, ng, nb = colorsys.hsv_to_rgb(hh, ss * 0.85, vv * 0.82)
            dpx[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)

    # —— 描边：王冠原图的暗金勾线抠不全，补一圈深褐（不然金块像贴纸，与手绘废墟笔触不搭）——
    crown = _outline(crown, (74, 58, 40, 235), 2)

    # —— 摆位：缩到废墟宽的 34%，倾倒 -24°，**按中心**落在内院石板中部（避开门洞与木梁）——
    cw = round(base.width * 0.34)
    crown = crown.resize((cw, round(crown.height * cw / crown.width)), Image.LANCZOS)
    crown = crown.rotate(-24, resample=Image.BICUBIC, expand=True)
    cx = round(base.width * 0.47 - crown.width * 0.5)
    cy = round(base.height * 0.55 - crown.height * 0.5)

    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        [cx + 6, cy + crown.height - 14, cx + crown.width - 6, cy + crown.height - 1],
        fill=(40, 34, 30, 85),
    )
    base.alpha_composite(shadow)
    base.alpha_composite(crown, (cx, cy))
    return base


def main() -> None:
    for name in NAMES:
        src = os.path.join(SRC, name + ".png")
        im = Image.open(src).convert("RGBA")
        out, hits = to_blue(im)
        lo = MIN_HITS[name]
        assert hits >= lo, f"{name}: 只改到 {hits} px（< {lo}），红带参数或素材变了，拒绝产出"
        dst = os.path.join(SRC, name + "_blue.png")
        out.save(dst)
        total = sum(1 for p in im.get_flattened_data() if p[3] > 0)
        print(f"{dst}  {im.size}  改色 {hits} px / 不透明 {total} px  ({hits / total:.1%})")

    king = Image.open(os.path.join(SRC, "cartoon_tower_king.png")).convert("RGBA")
    arrow_ruin = Image.open(
        os.path.join(SRC, "cartoon_tower_arrow_broken.png")
    ).convert("RGBA")
    ruin = make_king_ruin(king, arrow_ruin)
    rdst = os.path.join(SRC, "cartoon_tower_king_broken.png")
    ruin.save(rdst)
    print(f"{rdst}  {ruin.size}  王塔废墟（箭塔废墟放大 + 蒙尘王冠；敌我共用）")


if __name__ == "__main__":
    main()
