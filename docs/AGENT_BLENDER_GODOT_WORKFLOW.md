# Agent → Blender 建模 / 动画 → Godot 工作流

> 2026-10-24，来自“小小”首轮实作。已验证组合：Windows、Blender 5.2.3 LTS、Blender Lab 官方 MCP、Godot 4.6.3。
> 本文是操作指南；小小的资产规格与真人验收见 [ACCEPTANCE_XIAOXIAO_3D.md](ACCEPTANCE_XIAOXIAO_3D.md)。

## 1. 先说明要什么

给 agent 一张现有角色图或明确素材路径，说明要静态模型还是动画，以及最终用在什么地方。
推荐把工作收敛成一个可验收的小步：参考图 → 建模 → 看预览 → 绑定 / 动画 → GLB → 独立 Godot 展示场景。

可直接使用的请求：

```text
从项目美术素材中选一个角色，先读原图，保留比例、轮廓和配色，
在 Blender 中制作真正有厚度的 3D 模型。单张原图没有的背面请明确说明是补全设计。
先给我静态预览，通过后再做 Idle、Walk、Attack。
动画要能导入 Godot：待机和行走循环，攻击单次播放，不带 root motion。
交付可编辑 .blend、运行用 .glb、几何/骨骼检查结果，以及能 F6 运行的独立展示场景。
不要自行把它接进正式战斗、改主场景或提交推送。
```

项目内开发仍遵守根级 AGENTS.md：先查 HISTORY / Jira，使用独立 worktree；真人确认与提交分开。
Jira 不可用时先说明阻塞，只有用户明确授权本次例外后才可先做并记录待补；不能把本次例外当永久许可。

## 2. 连接 Blender

### 本机已安装的组件

| 组件 | 位置 / 用途 |
|---|---|
| Blender | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` |
| 官方 MCP 源码和独立 Python 环境 | `%USERPROFILE%\.codex\tools\blender-mcp-official\` |
| Blender 扩展 | `bl_ext.user_default.mcp`，在 Blender 内运行 TCP 桥 |
| Codex MCP 配置 | 用户级 `blender` 服务，stdio 进程连接本机 `127.0.0.1:9876` |
| 技能 | `%USERPROFILE%\.codex\skills\blender-*\`，先读 `blender-core/SKILL.md` |

这里使用 [Blender Lab 官方 MCP](https://www.blender.org/lab/mcp-server/)，源码在 [Blender 官方仓库](https://projects.blender.org/lab/blender_mcp)。
社区 `ahujasid/mcp-for-blender` 是另一套实现，协议与工具不同，不要混装后指向同一端口。
技能来自 [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills)，不是 Blender 内置功能。

### 每次开始

先检查已有窗口、9876 端口和当前打开文件。已经连接目标窗口时继续使用它；不要反复开新实例。
不要关闭他人的窗口或占用中的工作。

```powershell
Get-Process blender -ErrorAction SilentlyContinue
Get-NetTCPConnection -State Listen -LocalPort 9876 -ErrorAction SilentlyContinue

# 仅在需要新窗口时执行；脚本会启用已安装扩展并启动桥。
& "$env:USERPROFILE\.codex\tools\blender-mcp-official\start-blender-mcp.ps1"

codex mcp get blender
```

网络下载走 Clash `http://127.0.0.1:7897`；本机桥连接直连，`NO_PROXY=localhost,127.0.0.1`。
上述脚本、MCP 环境和技能是本机用户工具，不随项目仓库分发；换机器须按上游文档重新安装。
Codex 新增 MCP 后若工具列表没刷新，重新加载连接或重启客户端。

连接后先调用 `get_objects_summary`，确认文件 / 场景确实是目标，再调用 `execute_blender_code`。
可返回结构化数据：

```python
import bpy
result = {"file": bpy.data.filepath, "version": bpy.app.version_string}
```

本机也有两个已验证的辅助脚本，供未刷新原生工具列表时诊断：

```powershell
$taskTools = "$env:USERPROFILE\.codex\tools\blender-mcp-official"
& "$taskTools\.venv\Scripts\python.exe" "$taskTools\verify_connection.py"
# run_script.py 读取一个本地 bpy 脚本，通过官方 stdio MCP 在当前 Blender 内执行。
& "$taskTools\.venv\Scripts\python.exe" "$taskTools\run_script.py" 'C:\path\to\task.py'
```

MCP 具有执行任意 Python 的能力：只运行审阅过的代码，桥保持本机监听，不开放到公网。

## 3. 从原图建模

1. **读取原图**，不要只根据文件名猜造型。运行时小图不够时，去 `testAssets/` 找原始大图。
2. 记录轮廓、头身比、关节位置、材质分区、识别特征；区分原图事实和补全设计。
3. 先搭大体块，做正面、侧面、背面、三分之四视角预览；比例通过后再加细节。
4. 原点放脚底中央，Z 向上、角色正面约定为 Blender -Y；使用米制、单位缩放 1。
5. 保存独立工作文件；修改现有模型前保存备份，不清空或删除用户场景中无关内容。
6. 先控制网格 / 材质成本，再考虑细节。小小首版为 4,040 三角面、一个材质。

按需要读取技能：硬表面 `blender-hardsurface-modeling`、有机形体 `blender-sculpting`、
材质 `blender-pbr-materials`、灯光 `blender-lighting-lookdev`、渲染 `blender-rendering`。

优先通过 `bpy.data` / `bmesh` 创建和修改数据。必须用 operator 时，显式设置选择与 active object；
编辑模式修改后回到 Object 模式再检查。每次 MCP 调用重新 import 所需模块，不依赖上一次调用的 Python 局部变量。

Blender 5.x 与旧教程有 API 差异：动作采用 slots/channelbags，EEVEE 名称为 `BLENDER_EEVEE`。
遇到属性错误先读 `blender-core/references/api-changes-5x.md`，并在当前版本验证，别堆静默 fallback。

## 4. 模型检查后再做动画

用 `blender-asset-qa` 检查法线、退化面、重复点、悬空部件、共面闪烁、缩放和 UV。
检查结果必须包含三角面数、材质数、尺寸；修复 errors，逐条解释未修的 warnings。
渲染多角度和线框检查图，agent 自己打开图片检查；最终造型仍由真人确认。

```python
import sys
sys.path.insert(0, r"C:/Users/user/.codex/skills/blender-asset-qa/scripts")
import qa_check
result = qa_check.run(objects=["Stone_Body", "Fist_L", "Fist_R"], profile="game")
```

示例对象名和本机路径须换成实际值；应把同一角色的相关部件一起传入。
单张原画的背面补全、无骨骼的概念模型、已完成绑定的运行模型，要在交付中明确区分。

## 5. 绑定和制作动画

先读 `blender-character-rigging` 和 `blender-animation`。

- **石头 / 装甲分块角色**：每块刚性绑定到一根骨骼，保持石块体积；小小采用这种方式。
- **柔软身体**：关节周围平滑分配权重，检查肘、膝、肩的极限姿态；不要生搬刚性权重。
- 建一个位于原点的 root；关节枢轴放进实际连接位置；骨架和网格旋转 / 缩放保持规范。
- 所有顶点都有规范化权重，每顶点最多四个影响；无权重到非变形控制骨或无效骨。
- 待机包含身体呼吸和微小跟随；行走包含接触、承重、抬脚、摆臂；攻击包含蓄力、打击和收势。
- 先定关键姿态和节奏，再补过渡。嫩芽等附件可增加延迟跟随，不只让整个模型平移。
- 每个动作单独一个 Action，设置 fake user；确保 Action 的 slot 绑定目标 Armature。
- 引擎用原地动作时固定 root；骨骼 scale 不做非均匀动画。
- 循环首尾姿态闭合；逐帧检查脚底高度，避免穿地、滑步或双脚无意同时离地。
- IK、约束和驱动器如果用于控制，导出前把最终结果烘焙到变形骨关键帧。

小小实作使用 30 fps，`Idle_loop`（61 帧）、`Walk_loop`（41 帧）、`Attack`（46 帧）。
帧数是本例节奏，不是后续角色的硬性规格。导出后的实际时长以 Godot 读取结果为准。

用 `rig_check.py` 检查骨架 / 权重；分别渲染动作的起始、蓄力、打击和结束帧，检查动作确实改变姿态。
不要以“存在三个 Action 名字”代替真实运动验证。调用超时后先检查当前状态，不重放同一修改。

## 6. 导出 GLB

先读 `blender-game-optimization`、`blender-export-pipelines` 及其 `references/godot-web.md`。
源文件保留可编辑结构；运行资产只导出目标网格与骨架，排除地板、参考图、灯光和相机。

可在 MCP 中使用技能内已验证的导出器：

```python
import sys
sys.path.insert(0, r"C:/Users/user/.codex/skills/blender-export-pipelines/scripts")
import export_asset
result = export_asset.run(
    preset="godot", objects=["RIG_Xiaoxiao"],
    out=r"C:/path/to/project/assets/models/xiaoxiao/xiaoxiao_animated.glb")
```

导出必须确认：

- glTF 2.0 / GLB，单位为米；由导出器完成 Blender Z-up → glTF/Godot Y-up 转换，不手动再转一次。
- 网格、材质、skin、动画数量符合预期，文件存在且非空。
- 动画按 `ACTIONS` 导出，采样 / 烘焙覆盖完整动作；检查 skin 和 JOINTS / WEIGHTS 数据。
- 普通 PBR 用 Principled BSDF 和图片贴图；复杂程序节点需烘焙，不能期待 Godot自动重建。
- 小小用顶点色方案，已确认 GLB 含 `COLOR_0`，Godot 保留配色；无需额外贴图。
- 源骨架 15 骨、Godot 14 变形骨是本例正常结果：不变形 root 被导出规则排除，不应只比总数。

## 7. 放进 Godot 的独立场景

建议目录（小小已按此落地）：

```text
assets/models/xiaoxiao/
  xiaoxiao_animated.glb
  xiaoxiao_animated.glb.import
  source/
    .gdignore
    xiaoxiao_animated.blend
view/labs/xiaoxiao_showcase.tscn
view/labs/xiaoxiao_showcase.gd
```

`.blend` 作为源文件跟踪，但 source 目录放 `.gdignore`，让 Godot 只导入 GLB；避免重复导入及本机 Blender 路径依赖。
提交资产时同时保留 `.import` 设置；不要提交 `.godot/` 缓存。

展示台放在 `view/labs/`，实例化 GLB，配 Camera3D、灯光、地面和 CanvasLayer 控件。
通过导入的 AnimationPlayer 播放动作，别另外写一套假的摆动替代模型里的动画。
Godot 本例把 `Idle_loop` / `Walk_loop` 自动识别成循环并命名为 `Idle` / `Walk`；`Attack` 保持单次。
始终先读取 `get_animation_list()` 和每段 `loop_mode`，不要假设源文件名字原样保留。

独立展示台可以做动作切换、暂停 / 继续、调速、旋转、缩放和单次攻击结束回待机。
它只用于资产验收，不接账号、经济、战斗判定或正式入口。正式游戏接入另行规划。

## 8. 验证和交付

占用 Godot / 端口前先检查其他进程；不要操作别的 agent/worktree 正在使用的实例。
在目标工作树根目录执行，不要误在 master 导入和运行另一工作树的资源：

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tools/check_xiaoxiao_showcase.gd
godot --path . res://view/labs/xiaoxiao_showcase.tscn
```

最后两条是小小的检查 / 展示入口；新角色需要对应的脚本和场景。
导入后检查报错、骨骼和蒙皮、动画是否真的驱动骨骼、循环是否闭合，以及按钮切换和攻击结束状态。
视觉 / 手感交给真人：编辑器打开场景按 F6，按验收用例操作。AI 不自行驱动鼠标点引擎窗口。

交付 `.blend`、`.glb`、展示 `.tscn/.gd`、自动检查结果、明确可执行的真人用例；同步文档索引和 HISTORY。
需要人工验收就写“待验收”，不要以渲染预览或测试通过冒充真人认可。用户说“提交”后才 commit + push。
