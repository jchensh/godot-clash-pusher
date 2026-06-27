#!/usr/bin/env python3
"""V5-S8c stages 生成器：config/stages_spec.json → config/stages.json（100 关，章节制）。

铺量口径（PLAN_V5 §11.3，用户 2026-06-27 拍板）：
  - 全局关序 idx = (chapter-1)*stages_per_chapter + index（1..100）。
  - 难度系数 coef(idx) = coef_base + (idx-1)*coef_per_idx；每章第 N 关(=boss) 再 ×boss_coef_mult。
  - 推荐战力 rec = round(rec_team_power * coef * rec_tightness)。
  - 首通金 = (base + per_chapter*(章-1)) ×(boss 时 ×boss_gold_mult)；重复金 = 首通 ×repeat_gold_ratio。
  - 首通宝石 = first_clear_gems（boss = boss_gems）。
  - 碎片：每关首通发 shards_per_first_clear 张本章 shard_card（boss ×boss_shard_mult）+ shard_drop 概率掉落。
  - 星级目标统一 [win / 保王塔≥pct / 限时 sec]。
  - encounter：非 boss 关在本章 encounters 池按 (index-1)%len 轮转；boss 关用 boss_encounter。
  - ai：非 boss 用 ai_base，boss 用 ai_boss。

服务器经济（server/internal/economy/config.go）与客户端 ConfigLoader 都直接读生成出的 stages.json
（配置驱动，两端自动吃到，无需改 Go/GDScript）。改 spec → 跑本脚本重生成；提交前用 --check 校验无 drift。

用法：
  python tools/build_stages.py          # 生成/覆盖 config/stages.json
  python tools/build_stages.py --check   # 校验现有 stages.json == 由 spec 重生成（提交前必跑）；drift 退出码 1
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC_PATH = os.path.join(ROOT, "config", "stages_spec.json")
OUT_PATH = os.path.join(ROOT, "config", "stages.json")
ENC_PATH = os.path.join(ROOT, "config", "encounters.json")
CARDS_PATH = os.path.join(ROOT, "config", "cards.json")


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def build(spec, encounters, cards):
    """Return (stages_dict, errors)."""
    errors = []
    curve = spec["curve"]
    spc = int(spec["stages_per_chapter"])
    out = {
        "_comment": "由 tools/build_stages.py 从 config/stages_spec.json 生成，勿手改。改 spec 跑生成器；提交前 --check。"
                    " difficulty_coef=敌方乘区；recommended_power=队伍推荐战力(UI 着色)；stars=3 星目标；"
                    "first_clear/repeat=金币/宝石/碎片；shard_drop=概率掉碎片。数值〔示意·待 S8d probe 校准〕。",
    }
    for ch in spec["chapters"]:
        c = int(ch["chapter"])
        pool = ch["encounters"]
        boss_enc = ch["boss_encounter"]
        shard_card = ch["shard_card"]
        # 引用校验（早抓 spec 笔误）。
        for e in list(pool) + [boss_enc]:
            if e not in encounters:
                errors.append("chapter %d 引用了不存在的 encounter '%s'" % (c, e))
        if shard_card not in cards:
            errors.append("chapter %d 的 shard_card '%s' 不在 cards 中" % (c, shard_card))
        if not pool:
            errors.append("chapter %d 的 encounters 池为空" % c)
            continue

        for i in range(1, spc + 1):
            gidx = (c - 1) * spc + i
            is_boss = (i == spc)
            base_coef = curve["coef_base"] + (gidx - 1) * curve["coef_per_idx"]
            coef = round(base_coef * (curve["boss_coef_mult"] if is_boss else 1.0), 3)
            rec = int(round(curve["rec_team_power"] * coef * curve["rec_tightness"]))
            enc = boss_enc if is_boss else pool[(i - 1) % len(pool)]
            ai = ch["ai_boss"] if is_boss else ch["ai_base"]

            fc_gold = int(round(
                (curve["first_clear_gold_base"] + curve["first_clear_gold_per_chapter"] * (c - 1))
                * (curve["boss_gold_mult"] if is_boss else 1.0)))
            fc_gems = int(curve["boss_gems"] if is_boss else curve["first_clear_gems"])
            shard_n = int(curve["shards_per_first_clear"] * (curve["boss_shard_mult"] if is_boss else 1))
            repeat_gold = max(1, int(round(fc_gold * curve["repeat_gold_ratio"])))

            out["stage_%d_%d" % (c, i)] = {
                "chapter": c,
                "index": i,
                "encounter": enc,
                "base_level": ch["base_level"],
                "difficulty_coef": coef,
                "ai_difficulty": ai,
                "recommended_power": rec,
                "stars": [
                    {"goal": "win"},
                    {"goal": "king_hp_pct", "min": curve["stars_king_hp_pct"]},
                    {"goal": "time_under", "sec": curve["stars_time_under_sec"]},
                ],
                "first_clear": {"gold": fc_gold, "gems": fc_gems, "shards": {shard_card: shard_n}},
                "repeat": {"gold": repeat_gold},
                "shard_drop": {shard_card: {"chance": curve["shard_drop_chance"], "amount": curve["shard_drop_amount"]}},
            }
    return out, errors


def main():
    check = "--check" in sys.argv[1:]
    spec = load_json(SPEC_PATH)
    encounters = load_json(ENC_PATH)
    cards = load_json(CARDS_PATH)
    stages, errors = build(spec, encounters, cards)
    if errors:
        for e in errors:
            print("[build_stages] 错误: %s" % e)
        sys.exit(1)

    n = sum(1 for k in stages if not k.startswith("_"))
    text = json.dumps(stages, ensure_ascii=False, indent=2) + "\n"

    if check:
        if not os.path.exists(OUT_PATH):
            print("[build_stages] --check 失败：%s 不存在" % OUT_PATH)
            sys.exit(1)
        current = load_json(OUT_PATH)
        if current == stages:
            print("[build_stages] --check OK：stages.json 与 spec 一致（%d 关）" % n)
            sys.exit(0)
        print("[build_stages] --check 失败：stages.json 与 spec 重生成结果不一致（跑无参重生成）")
        sys.exit(1)

    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("[build_stages] 生成 %s：%d 关（%d 章）" % (OUT_PATH, n, len(spec["chapters"])))


if __name__ == "__main__":
    main()
