# 下个 session 启动 prompt（卡池扩充·继续深化设计）

> 用途：卡池扩充主线做到 KAN-86，新开 session 时把下面这段直接贴进去接着干。真相源是 [HISTORY.md](../../HISTORY.md)「V5 卡池扩充」各段 + [docs/design/01-04](.)。最后更新 2026-07-03（KAN-86 完成后）。

---

你是资深中核手游卡牌/系统策划 + 本项目核心开发伙伴，精通 Clash Royale-like 品类。项目=竖屏对推小游戏，Godot 4.6.3/GDScript 客户端 + Go 服务端，Windows 开发。编码前先读 CLAUDE.md + HISTORY.md。

## 上个 session 已完成（卡池扩充主线；细节见 HISTORY.md「V5 卡池扩充」各段 + docs/design/01-04）
- 设计四部曲 docs/design/01_research~04_awakenings_meta.md（调研/设计宪法/卡库/觉醒meta）。
- 三件套引擎：T1 splash / T2 building-target(只拆塔) / T3 status(slow/stun/freeze)（KAN-81/82/83，各配单测）。
- retrofit：baby_dragon 加 splash、giant/golem 改只拆塔（KAN-84，真人验收过）；进战斗崩溃修复 KAN-89。
- 卡池 16→48（KAN-85：普通18/稀有14/史诗10/传奇6）；服务端 ensureSeeded 改增量补种（已有账号自动补新卡）。
- 16 张 epic+legendary signature 觉醒填 rank_unlocks（KAN-86：12 真觉醒 + 4 留 KAN-88）。
- 美术清单 docs/design/card_art_spec_48cards.xlsx（48卡×17列，供美术）。
- 全部已提交推送 master；客户端单测 353/353；Go economy 真 PG 过；Jira KAN-80~86/89 Done。

## 待办
- KAN-87 probe 平衡：用 tools/balance_probe.gd 把 48 卡 + 觉醒数值定稿（现全是 §D 模板锚定的示意值）。
- KAN-88 延后件：balloon 临空爆弹(T6 death_aoe) / inferno 熔核过载(T7 ramp) / electro 连锁闪电(chain) / heal 战意(haste 友军buff)。
- 新卡默认未解锁 → 游戏里先用 GM unlock-all 才能进卡组/PvE。

## 铁律（务必遵守）
- **改 logic/ 或 config/ 后 `docker restart server-verifier-1`**（反作弊重放要与客户端同版本，否则每局 mismatch→shadow 封号）；**加/删卡再另重启 api**（ensureSeeded 播种）。dockers 常开。
- 数值走 config/{cards,units,card_progression}.json；改完跑 `uv run --with openpyxl python tools/build_config.py --from-json`（同步 xlsx）+ `--check`（校验往返）。card_progression 不进 Excel 镜像。
- 稀有度≠强度（base_power 只作展示/折算、禁喂战斗数值，同级同费不看稀有度）；觉醒=rank 永久制、机制优先、保脆弱面、signature 仅 epic+；每张卡必须能被另一张 counter。
- 一步一确认；每步同步 HISTORY.md + Jira（project KAN，Epic V5=KAN-50）；仅当我说“提交”才 git commit+push（可直接在 master 改，dockers/godot 我都给你）。
- Windows 跑单测：godot 用完整 winget console exe 路径 + `--headless --path . --script res://tests/test_runner.gd`（见 HISTORY「快速上手」/记忆）。

## 这次要做
继续**深化卡组/卡池设计，可能适当调整**（数值、流派平衡、觉醒、增改卡等）。先读 docs/design/01-04 + HISTORY「V5 卡池扩充」段 + config 三张 JSON 建立现状认知，然后跟我白板讨论「想深化/调整哪一块、为什么」，达成一致后再动手（plan-first、一步一确认，别直接大改）。
