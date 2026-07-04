# 下个 session 启动 prompt（三国化轨道A·继续开发）

> 用途：三国题材改版做到 A3 + 若干 UX/音频修，新开 session 把下面这段直接贴进去接着干。真相源 = [HISTORY.md](../../HISTORY.md)「V5 三国改版」各段 + [PLAN_V5_SANGUO.md](../../PLAN_V5_SANGUO.md) + [PLAN_V5_HBATTLE.md](../../PLAN_V5_HBATTLE.md)。最后更新 2026-07-05。

---

你是资深中核手游卡牌/系统策划 + 本项目核心开发伙伴，精通 Clash Royale-like 品类。项目=竖屏对推小游戏，Godot 4.6.3/GDScript 客户端 + Go 服务端，Windows 开发。编码前先读 CLAUDE.md + HISTORY.md。

## 上个 session 已完成（三国题材改版轨道A；细节见 HISTORY「V5 三国改版」各段）
- **三国化启动**：世界观/画风全换三国（魏/蜀/吴/群雄 12×4，热血物语三头身高清像素），**卡ID/费用/数值/机制/结构全部冻结**、只动包装层。施工图 PLAN_V5_SANGUO.md（§0 十条决策）；美术真相源 docs/design/card_art_spec_48cards.xlsx（三国版）。
- **A1** 美术表口径对齐入库（觉醒 5 处按已实现机制降级、4 张延后件标"数值占位"；增强版挪 KAN-88）。
- **A2** 文案层三国化：cards.json 48 卡名+`faction` 字段（Excel 列往返）/ units.json 39 单位名 / card_progression 22 处觉醒 note / 稀有度显示名 **寻常/精良/非凡/无双**（内部枚举 common~legendary 不动）/ **i18n 补全 48 卡双语**（顺带修了 32 新卡 UI 显示 card_xxx 键名的断层）。⚠️ UI 卡名真相源=i18n（`tr("card_"+id)`），**改卡名要 i18n+cards.json 两处同步**。
- **A2.5** 占位精灵铺满：sprite_db 39/39 单位全覆盖（新启用 7 张素材包贴图 + tint 阵营染色 魏蓝/蜀绿/吴红/群黄 + scale 体型 + `ph` 占位标记）；**替换正式素材三步指引在 sprite_db.gd 文件头**；test_sprite_db 占位账本断言=31（替换一条减一）。
- **A3** 场景与系统美术清单：docs/design/scene_system_art_spec.xlsx（6 sheet/69 行：塔分阵营 5 套[我方汉军+敌方四阵营随章节，P0=我方+黄巾]/地形 3 主题/FX 18 项/UI 中式小改[大改版另立项]/头像 16[四阵营×4]/音频方向）。可直接发美术。
- **滚动交互修复**（验收反馈 bug）：`view/ui/drag_scroll.gd` 通用组件（鼠标按住拖动+轻点派发 pressed；真机触摸走引擎原生防双滚），组卡/创号/图鉴/闯关四界面接入；组卡卡池与创号头像网格补 ScrollContainer（48 卡/39 头像超屏无滚动的阻塞 bug）。
- **首批 BGM**：菜单=Oriental / 战斗=Ninja Theme（OpenGameArt **CC0** 可商用免署名，来源许可记 audio_assets.json source_notes）；顺手修 AudioManager loop 缺口（清单 loop 从未落到资源）；test_audio_assets 守门。
- **横版战斗立项（只方案未开工）**：PLAN_V5_HBATTLE.md——战场纵改横（我左敌右）便于侧视帧素材，logic 零改动、纵横重放 hash 一致为硬验收；已给用户"最小可看里程碑"提案 = H1 变换层收敛 + H2 横版投影 + 设置页临时实验开关（PvE 先行），**等用户说"做"**。
- 全部已提交推送 master（72624b5 → b75c387 → 641ee1e）。客户端单测 **358/358**；dockers 已同步（api 日志 cfg ver=cd27932e）。数值线 KAN-87/88 挂起（CV 审计结论：inferno_dragon 平 200DPS 全池最超模、battle_ram 碾压 bone_ram 违反稀有度红线等——重启时看 HISTORY 与当时对话记录）。

## 待办/欠账
- **真人验收台账 = docs/ACCEPTANCE_SANGUO.md**（勾进度都在里面）：A组文案 4 例（部分过）/ B组精灵 5 例（部分过：卡有图、对战正常）/ C组滚动 5 例（DragScroll 二次修后待重测）/ D组 BGM 2 例 / A3 表评审 / S8e 老账。验收过+用户拍板 → 对应 Jira Done。
- **Jira 手工清单**（Atlassian MCP 未授权，用户手工）：PLAN_V5_SANGUO §4 七条（A1A2、A2.5 建 In Review 等）。
- **下一步候选**（用户定）：①横版战斗 H1+H2+临时开关（用户已表兴趣）②A4 素材接入+世界观文本+**遭遇/奖励回填**（15 遭遇模板全旧 16 卡、100 关奖励只掉 8 旧卡碎片——新卡 PvE 零曝光零获取，纯配置活可先行）③A3 表发美术后按 P0 素材接入 ④数值线复盘重启。

## 铁律（务必遵守）
- **改 logic/ 或 config/ 后 `docker restart server-verifier-1`**（否则重放 mismatch→shadow 封号）；**加/删卡再另重启 api+gateway**（ensureSeeded 播种+配置版本）。dockers 常开。
- 数值/卡牌配置改完跑 `uv run --with openpyxl python tools/build_config.py --from-json` + `--check`；音频走 `tools/build_audio_config.py` 同两步。card_progression/arena 不进 Excel 镜像。
- **三国化包装铁律**：卡 ID/数值/机制冻结；卡名改动 i18n+cards.json 两处同步；稀有度内部枚举永不改（只动显示名）；faction 仅题材归属+羁绊预留**不产克制**（羁绊若做禁裸数值加成）；顶级人物（曹刘孙关张赵吕马）留库不出卡。
- 稀有度≠强度（base_power 禁喂战斗数值）；觉醒机制优先、保脆弱面；每卡必须能被 counter。
- 一步一确认；每步更 HISTORY.md（+PLAN 相应文档）；真人验收欠账记 ACCEPTANCE_SANGUO.md；仅用户说"提交"才 git commit+push（可直接在 master 改）。
- Windows 跑单测：godot 用完整 winget console exe 路径 + `--headless --path . --script res://tests/test_runner.gd`（见记忆/HISTORY 快速上手）；heredoc 在 git bash 会截断，python 脚本先写文件再执行。

## 这次要做
先读 CLAUDE.md + HISTORY「V5 三国改版」各段 + PLAN_V5_SANGUO.md 建立认知，然后按我口头指定的候选项开工（横版 H1H2 / A4 回填 / 素材接入 / 数值线复盘）。plan-first、一步一确认。
