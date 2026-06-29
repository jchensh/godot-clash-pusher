# NOTE — 用 image-gen MCP 打通「角色/立绘」这堵墙（Tier-2/3）

> **状态**：参考笔记，**未实施**。记录"将来想试时怎么接"。不改任何现有代码/资源。
> **背景**：agent 单干能把 UI chrome / HUD / 闯关图 / 养成屏（Tier-1 几何件）画到 ship 质量（见 `scratch/draw_proof_card_panel.gd` 校准件 + `tools/gen_ui_assets.py` + `sbpixel`）。**画不出的只有「表现性角色/怪物/Boss 立绘 + 卡面肖像」**（Tier-2/3）——本笔记就是把这堵墙变成"可编排"的方案。

---

## 0. 核心原则（全行业趋同的那条）

**把"创意推理"和"确定性像素操作"分开**：
- **Agent（我）** 负责：规划要哪些素材、写 prompt、定 SpriteDB 清单、跑后处理脚本、肉眼前的初筛。
- **Image model（MCP 后端）** 负责：把 prompt 渲成原始帧（这是我没有的能力——本 harness 无 diffusion）。
- **确定性脚本（Python）** 负责：裁剪/对齐网格/补齐帧数/打表 → 输出符合 `SpriteDB` schema 的 spritesheet。

> 这正是 `gen_ui_assets.py` 已经在做的事的延伸——只是把"PIL 画色块"换成"模型画立绘"，后处理与入库逻辑同构。**永不在运行时调模型**；产物 bake 成 PNG 入 git。

---

## 1. 候选后端（按贴合度排序）

| 后端 | 形态 | 适配度 | 备注 |
|---|---|---|---|
| **PixelLab** | 像素美术专用（文/骨架驱动、行走/攻击循环、4/8 向旋转、tileset） | ★★★★ | 最贴本项目（16/24/32px 像素兵 + walk/attack 多向）。骨架动画直接解「帧间一致性」这个最难的点。有无官方 MCP 需确认；否则走其 API + 自写薄 MCP/脚本 |
| **Agent Sprite Forge**（开源，Codex-first） | agent 规划 → 图生 → 确定性脚本切帧/导出 Godot | ★★★★ | 架构与本项目理念一模一样；可直接借鉴其切帧/导出层，甚至套 Godot scene/TileMap 输出 |
| **Aseprite MCP** | 让 agent 驱动 Aseprite（画/重上色/导出 spritesheet/改尺寸） | ★★★ | 最强用途其实是**重上色 + 导出 + 改网格**，而非从零画动画。对消除"暂换皮"占位（见 §4）极合适 |
| **Retro Diffusion** | 像素扩散模型 | ★★★ | PixelLab 的风格替代，可做单帧/贴图 |
| 通用图模型（任意 image-gen MCP） | 文生图 | ★★ | 出图非像素原生，需重度后处理降采样/对齐网格；做卡面大图/splash 可以，做小兵动画吃力 |
| Google Stitch / v0 / Figma Make | design-to-code（Web/React） | ✗（对引擎） | 只能帮**出 UI 点子/原型**，不产 Godot 场景与精灵。idea 板，不是 shipper |

---

## 2. 帧间一致性 = 最难的点（必须正视）

单张图容易，**走/攻多帧循环要"同一个角色、连贯姿态、稳定调色板"**——这是纯文生图最容易翻车处。缓解手段：
- 优先**骨架驱动**工具（PixelLab）做动画循环，而非逐帧文生图。
- "先定基准站姿 → 再派生其余帧"的流程。
- **锁死调色板**（限色 + 后处理量化到固定 palette）。
- **critic 回环**：生成→自检（帧数/尺寸/角色一致性）→不合格重生成（参考"四评审 language-to-sprite"实验）。

---

## 3. 接进 `SpriteDB` 的具体步骤

`view/sprite_db.gd` 的 schema（每单位每状态）：`tex / fw / fh / cols / row / row_up(可选) / n / fps / scale(+sc)`。流程：

1. **连 MCP**：`claude mcp add <backend> ...`，确认工具出现（`mcp__<backend>__*`）。
2. **写美术 brief**（每单位）：帧尺寸（16/24/32）、limited palette（复用现有夜色板）、需要的状态（walk/attack）、朝向（正面 row + 可选背面 row_up）、帧数 n、参考风格（对齐现有 `Heavy_Knight`/`orc` 等已购包观感）。
3. **agent 出图**：prompt 模型 → 原始透明帧（每状态一组）。
4. **确定性后处理**（新脚本 `tools/build_sprites.py`，仿 `gen_ui_assets.py`/`_frame_probe.py`）：trim → 对齐网格 → padding 到 fw×fh → 排成 cols×rows → 校验帧数 → 写 `assets/units/<unit>.png`。
5. **headless 导入**：`godot --headless --editor --path . --quit` 生成 `.import`/`.uid`（repo 惯例跟踪 .uid）。
6. **登记清单**：在 `SpriteDB.DB` 加该 unit 条目（tex/fw/fh/cols/row/row_up/n/fps/scale）。
7. **真人肉眼校**（按纪律：表现层交真人）：核 row/朝向/fps，微调。

> **可复现**：prompt + 参数写进 manifest（如 `config/sprite_briefs.json`），重生成可重放，和 `gen_ui_assets.py` 改色重跑同理。

---

## 4. 最低风险的第一步用法 = 消除"暂换皮"占位（不一定要从零生成）

`SpriteDB` 里 `golem_body` / `baby_dragon_body` 现在**复用** orc/fire_skull 帧（注释明写"缺真素材，暂换皮"）。**先别急着生成全新动画**——用 Aseprite-MCP/PIL 重上色把这俩占位**改成可区分的配色变体**（巨像=灰白巨化、幼龙=暗红/紫），就能立刻去掉"两张卡长一样"的尴尬，零生成成本、零一致性风险。这是验证整条 MCP 管线的理想小白鼠。

---

## 5. 治理（契合"一步一确认"）

- image-gen 是**付费 + 外部调用** → 每次走 batch + 用户明确 opt-in + 入库前评审，不擅自跑。
- **创意"手感/品味"仍是 agent 弱项**（行业共识）：16 张英雄卡的**最终立绘**建议留人类美术/精修把关；生成用于**占位 / 变体 / 迭代 / 量产敌兵**最划算。
- 产物一律 bake 成 PNG 入 git；prompt/params 入 manifest；**运行时绝不调模型**。

---

## 6. 一句话路线

连 **PixelLab 或 Aseprite MCP** → 先用"重上色消占位"（§4）验管线 → 再按 §3 把新敌兵/Boss 逐个生成入 `SpriteDB` → 英雄卡终稿留人精修。我从"画不出龙"变成"能编排把龙画出来"，分离式架构与现有 `gen_ui_assets` 完全同构。

> 参考案例：Agent Sprite Forge（github 0x0funky/agent-sprite-forge）、Aseprite-MCP swordsman 实验（ljvmiranda921.github.io）、language-to-sprite 四评审管线（kokutech.com）、PixelLab（pixellab.ai）。
