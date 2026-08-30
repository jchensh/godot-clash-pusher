#!/usr/bin/env python3
"""卡通改版 P1-5 切帧管线（决策 49/KAN-121）。

输入：testAssets/新风格美术资源0830/动作/<角色>/ 下的横排序列帧（美术 2 倍交付、
帧宽非整数、无帧数表）。对每张动作图：
  1. 透明列投影找内容段 → **相邻段中心距中位数推帧距** → N=round(W/帧距)：
     只用检测"数帧数"，切割永远用等距网格（美术等间距导出，角色每帧同位；
     粘连段/特效跨界不影响 N）。段不足时回退 N=8（本批标注帧数的均为 8x1）。
  2. 等距切 N 帧后取**全帧 alpha 包围盒并集**统一裁切（同一 crop 区域）——
     角色锚点跨帧恒定，不因单帧特效（枪口烟/挥击光）把该帧包围盒拉宽而跳动。
  3. 整图 ÷2（美术 2 倍交付 → 逻辑 1x），LANCZOS。
  4. 输出 assets/units_cartoon/<card_id>_{attack,walk}.png（等宽帧横排）
     + assets/units_cartoon/cartoon_frames.json（帧数/帧宽高/来源，供 sprite_db 读）。
  5. 立绘 ÷2 → assets/portraits_cartoon/<card_id>.png（P2 卡面/图鉴用，先行产出）。

用法：uv run --with pillow python tools/slice_cartoon_frames.py
幂等：重跑覆盖输出。角色→卡 ID 映射 = PLAN_V5_CARTOON.md §5（蝴蝶仙子→ice_wizard）。
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "testAssets" / "新风格美术资源0830" / "动作"
OUT_UNITS = ROOT / "assets" / "units_cartoon"
OUT_PORTRAITS = ROOT / "assets" / "portraits_cartoon"

# 角色文件夹名 → 卡 ID（PLAN_V5_CARTOON.md §5 初表定稿）
CHAR_TO_CARD = {
    "女主": "princess",
    "兔子": "archers",
    "鼹鼠火枪手": "musketeer",
    "火精灵": "fire_spirit",
    "雷精灵": "electro_spirit",
    "飞斧汪": "axe_thrower",
    "双斧火钳": "valkyrie",
    "小小": "knight",
    "蟑螂": "goblins",
    "猫炮手": "bomber",
    "猪猪配香菇": "hog_rider",
    "火又鸟": "phoenix",
    "幺蛾子": "lava_hound",
    "马蜂王": "balloon",
    "鸦王": "mega_minion",
    "岩石史莱姆": "golem",
    "锤锤莱姆": "mini_pekka",
    "棒槌史莱姆": "barbarians",
    "蟑螂恶霸": "goblin_gang",
    "瓜牛炮": "royal_giant",
    "蝴蝶仙子": "ice_wizard",
}

ATTACK_PAT = re.compile(r"(攻击|开炮)")
WALK_PAT = re.compile(r"(行走|移动|飞行|步行|走路)")
FALLBACK_FRAMES = 8  # 检测失败时的均分帧数（本批标注帧数的样例均为 8x1）


def find_segments(im: Image.Image) -> list[tuple[int, int]]:
    """按全透明列分隔返回 [(x0,x1)) 内容段。"""
    alpha = im.getchannel("A")
    w, h = im.size
    # 列有内容 = 该列最大 alpha > 0（用 bbox 逐列太慢：投影到 1px 高）
    col = alpha.resize((w, 1), Image.BOX)  # BOX 取均值，>0 即该列存在不透明像素
    data = col.load()
    segs: list[tuple[int, int]] = []
    x = 0
    while x < w:
        if data[x, 0] > 0:
            x0 = x
            while x < w and data[x, 0] > 0:
                x += 1
            segs.append((x0, x))
        else:
            x += 1
    return segs


def detect_n(segs: list[tuple[int, int]], w: int) -> tuple[int, str]:
    """段中心距中位数 → 帧距 → N=round(W/帧距)。段不足回退 8。"""
    if len(segs) >= 3:
        centers = [(a + b) / 2.0 for a, b in segs]
        dists = sorted(centers[i + 1] - centers[i] for i in range(len(centers) - 1))
        d = dists[len(dists) // 2]
        n = round(w / d)
        if 2 <= n <= 32:
            return n, "auto%d" % n
    return FALLBACK_FRAMES, "fallback%d" % FALLBACK_FRAMES


def slice_sheet(path: Path) -> tuple[list[Image.Image], str]:
    im = Image.open(path).convert("RGBA")
    w, _h = im.size
    n, mode = detect_n(find_segments(im), w)
    fw = w / n
    raw = [im.crop((round(i * fw), 0, round((i + 1) * fw), im.height)) for i in range(n)]
    # 全帧并集包围盒（相对帧原点）→ 同一 crop：角色锚点恒定
    x0, y0 = fw, im.height
    x1, y1 = 0, 0
    for f in raw:
        b = f.getbbox()
        if b is None:
            continue
        x0, y0 = min(x0, b[0]), min(y0, b[1])
        x1, y1 = max(x1, b[2]), max(y1, b[3])
    if x1 <= x0:
        raise ValueError(f"{path.name}: 全透明")
    return [f.crop((int(x0), int(y0), int(x1), int(y1))) for f in raw], mode


def pack(frames: list[Image.Image]) -> tuple[Image.Image, int, int]:
    """帧已同尺寸（并集 crop），直接横排。"""
    fw = frames[0].width
    fh = frames[0].height
    sheet = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * fw, 0))
    return sheet, fw, fh


def halve(im: Image.Image) -> Image.Image:
    return im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.LANCZOS)


def main() -> int:
    OUT_UNITS.mkdir(parents=True, exist_ok=True)
    OUT_PORTRAITS.mkdir(parents=True, exist_ok=True)
    meta: dict = {}
    problems: list[str] = []
    for char_dir in sorted(SRC.iterdir()):
        if not char_dir.is_dir():
            continue
        card = CHAR_TO_CARD.get(char_dir.name)
        if card is None:
            problems.append(f"未映射角色文件夹: {char_dir.name}")
            continue
        pngs = list(char_dir.glob("*.png"))
        attack = [p for p in pngs if ATTACK_PAT.search(p.stem)]
        walk = [p for p in pngs if WALK_PAT.search(p.stem) and not ATTACK_PAT.search(p.stem)]
        portrait = [p for p in pngs if p not in attack and p not in walk]
        entry: dict = {"char": char_dir.name}
        for kind, cands in (("attack", attack), ("walk", walk)):
            if len(cands) != 1:
                problems.append(f"{char_dir.name}/{kind}: 候选 {len(cands)} 个 {[p.name for p in cands]}")
                continue
            frames, mode = slice_sheet(cands[0])
            sheet, fw, fh = pack(frames)
            sheet = halve(sheet)
            out = OUT_UNITS / f"{card}_{kind}.png"
            sheet.save(out)
            entry[kind] = {
                "frames": len(frames),
                "fw": sheet.width // len(frames),
                "fh": sheet.height,
                "detect": mode,
                "src": cands[0].name,
            }
        if len(portrait) == 1:
            halve(Image.open(portrait[0]).convert("RGBA")).save(OUT_PORTRAITS / f"{card}.png")
            entry["portrait"] = portrait[0].name
        else:
            problems.append(f"{char_dir.name}/portrait: 候选 {len(portrait)} 个")
        meta[card] = entry
    (OUT_UNITS / "cartoon_frames.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    print(f"角色 {len(meta)}/{len(CHAR_TO_CARD)}")
    for cid in sorted(meta):
        e = meta[cid]
        a = e.get("attack", {})
        wk = e.get("walk", {})
        print(f"  {cid:<15} {e['char']:<6} attack {a.get('frames','?'):>2}帧 {a.get('fw','?')}x{a.get('fh','?')} [{a.get('detect','')}]"
              f" | walk {wk.get('frames','?'):>2}帧 {wk.get('fw','?')}x{wk.get('fh','?')} [{wk.get('detect','')}]")
    if problems:
        print("⚠ 问题：")
        for p in problems:
            print("  -", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
