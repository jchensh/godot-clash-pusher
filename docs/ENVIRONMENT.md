# Environment Setup

This project is a Godot 4 / GDScript game. The game code, Godot AI addon, and
project settings are tracked in git, but each developer machine still needs
local tools and MCP client registration.

## What Is In Git

- Godot project files, logic, view, config, tests.
- Godot AI editor addon: `addons/godot_ai/`.
- Godot plugin enablement in `project.godot`:
  - `[editor_plugins] enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")`
  - `[autoload] _mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"`
- Project instructions: `AGENTS.md`, `HISTORY.md`, `PLAN_*.md`.

## What Is Machine-Local

These do not come from git and must be configured on each machine:

- Godot engine installation.
- `uv` Python runner used by the Godot AI MCP server.
- Codex MCP registration in the user's Codex config.
- Claude Code MCP registration in the user's Claude config.
- Atlas (Atlassian) MCP connector for the Jira PM board — required in **both**
  Claude Code and Codex (see the "Atlas (Atlassian) MCP" section below). Without
  it, agents cannot maintain the `KAN` Jira board the workflow depends on.
- User environment variables such as telemetry opt-out.
- Local proxy settings for GitHub/PyPI downloads.

## Required Versions

- Godot: `4.6.3 stable`, standard GDScript build.
- Git: any modern version.
- `uv`: required by `godot-ai`.
- Optional but recommended: GitHub CLI `gh`.
- Optional agent clients: Codex, Claude Code.

The current imported Godot AI addon is:

- Repository: https://github.com/hi-godot/godot-ai
- Version: `2.6.1`

## Windows Setup

Shell: PowerShell.

Package manager: winget.

Common commands:

```powershell
winget install --id GodotEngine.GodotEngine -e
winget install --id Git.Git -e
winget install --id astral-sh.uv -e
winget install --id GitHub.cli -e
```

If the network needs Clash Verge, run download commands with:

```powershell
$env:HTTP_PROXY = "http://127.0.0.1:7897"
$env:HTTPS_PROXY = "http://127.0.0.1:7897"
```

Project helper script:

```powershell
.\scripts\setup-godot-ai.ps1
```

With an explicit proxy:

```powershell
.\scripts\setup-godot-ai.ps1 -Proxy http://127.0.0.1:7897
```

What the script does:

- Runs on Windows PowerShell only. It intentionally uses Windows user paths and
  winget.
- Verifies the project has `addons/godot_ai/plugin.cfg`.
- Checks `godot`, `git`, and `uv`.
- Installs `uv` through winget if missing.
- Sets user telemetry opt-out variables:
  - `GODOT_AI_DISABLE_TELEMETRY=true`
  - `DISABLE_TELEMETRY=true`
- Adds Codex MCP config if missing:

  ```toml
  [mcp_servers."godot-ai"]
  url = "http://127.0.0.1:8000/mcp"
  enabled = true
  ```

- Adds Claude Code MCP config if `claude` is installed:

  ```powershell
  claude mcp add --scope user --transport http godot-ai http://127.0.0.1:8000/mcp
  ```

## macOS Setup

Shell: Terminal.

Package manager: Homebrew.

Common commands:

```bash
brew install --cask godot
brew install git uv gh
```

If your shell cannot find Godot after installing the cask, either launch it
from Applications or add a shell alias/wrapper named `godot` that points to
the Godot executable inside the app bundle.

Configure Claude Code:

```bash
claude mcp add --scope user --transport http godot-ai http://127.0.0.1:8000/mcp
```

Configure Codex by adding this to `~/.codex/config.toml`:

```toml
[mcp_servers."godot-ai"]
url = "http://127.0.0.1:8000/mcp"
enabled = true
```

Telemetry opt-out:

```bash
export GODOT_AI_DISABLE_TELEMETRY=true
export DISABLE_TELEMETRY=true
```

Persist those exports in your shell profile if desired.

## Running The Project

Run all logic tests:

```powershell
godot --headless --path F:\godotTowerPush\master --script res://tests/test_runner.gd
```

macOS example:

```bash
godot --headless --path /path/to/godotProject --script res://tests/test_runner.gd
```

Open the editor:

```powershell
godot --path F:\godotTowerPush\master -e
```

## Using Godot AI MCP

Godot AI starts its MCP server only when the Godot editor GUI is open and the
plugin is enabled.

Expected ports:

- MCP HTTP: `127.0.0.1:8000`
- Godot editor WebSocket: `127.0.0.1:9500`

Claude Code check:

```powershell
claude mcp list
```

Expected line:

```text
godot-ai: http://127.0.0.1:8000/mcp (HTTP) - Connected
```

If it is disconnected:

1. Open Godot editor for this project.
2. Confirm `Project > Project Settings > Plugins > Godot AI` is enabled.
3. Confirm `uv` is available in the environment used to launch Godot.
4. Restart the agent client session.

## Atlas (Atlassian) MCP — Jira PM Board

This project uses the Jira project **`KAN`** ("godotRoyalClash") as the PM source
of truth, alongside `HISTORY.md`. Agents read/write it through the **Atlas
(Atlassian) remote MCP connector**. It is **required in both Claude Code and
Codex** — Codex follows the same plan-create / start→In Progress / done→Done
lifecycle described in `CLAUDE.md` / `AGENTS.md`. If the connector is not
connected, stop and ask the user to install it; do not silently skip Jira
updates.

Verified site facts:

- Site: `https://jchensh.atlassian.net`
- cloudId: `087c2538-1ab6-4794-90b5-2edf33e04312`
- Token scope: `jira-work` (read + write). No Confluence scope — Confluence
  tools will fail until re-authorized with a wider scope.
- Project key: `KAN`. Epics = version lines (V1=`KAN-5`, V2=`KAN-6`,
  V3=`KAN-7`, V4=`KAN-8`).

This is the Atlassian official **remote** MCP (OAuth in the browser, no local
process). Confirm the exact endpoint/transport against Atlassian's current
Remote MCP Server docs, then register it.

Claude Code (remote connector, OAuth):

```powershell
claude mcp add --scope user --transport sse atlassian https://mcp.atlassian.com/v1/sse
# then run /mcp in the Claude Code TUI to complete the browser OAuth
```

Codex — add the same remote server to `~/.codex/config.toml` (use Codex's
current remote/OAuth MCP syntax; verify against Codex docs):

```toml
[mcp_servers."atlassian"]
url = "https://mcp.atlassian.com/v1/sse"
enabled = true
```

Connectivity check:

```powershell
claude mcp list   # expect: atlassian ... Connected
```

Or call a read-only tool (`atlassianUserInfo` /
`getAccessibleAtlassianResources`) — it should return the `jchensh` account and
the cloudId above. The connector's tools are deferred MCP tools (names carry a
UUID prefix); load their schemas via ToolSearch before calling. Interactive
OAuth connectors may be unavailable in headless/cron runs.

## Rules For Agents

- Use headless tests for logic correctness.
- Use Godot AI MCP as a display/editor aid: scene hierarchy, screenshots,
  logs, runtime state, UI/animation/effect debugging.
- Do not use MCP writes to bypass `PLAN_V2.md` or the one-step-at-a-time
  confirmation discipline.
- Visual quality and game feel still require human verification in the editor.

---

## godot-ai MCP — 操作细节（从 CLAUDE.md 迁入，按需查）

> 使用守则（默认不主动用 / 写操作先确认 / 不替代真人验收）在 CLAUDE.md。这里是管理命令与画面/FX 验收协议。

**前提**：server 由 Godot 编辑器插件提供，**只有编辑器开着时可用**，关掉即断；**先开编辑器再开 agent 会话**，顺序反了需新开会话重连。注册信息在用户级配置（非项目内）。

**管理 / 排查**
```bash
claude mcp list            # 看连接状态（godot-ai ✓ Connected 即正常）
claude mcp get godot-ai
claude mcp remove godot-ai -s user   # 卸载注册（不删插件）
```
界面里 `/mcp` 也能看状态；Godot「项目设置→插件」启停 `godot_ai`。

**画面 / FX 验收协议（V2-4 教训，别让用户陪打）**
- **一次性载全工具**：开头一个 ToolSearch 拿全 `editor_state / project_run / project_manage / editor_screenshot / game_manage / logs_read`；用 **`editor_screenshot source="game"`** 截运行中游戏（2D 工程别用默认 `viewport` 源，会因无 Node3D 报错）。
- **干净启动序列**：`project_manage(op=stop)` → `editor_state`（等 `is_playing=false`）→ `project_run(autosave=false)` → 轮询 `editor_state` 到 `game_capture_ready=true` 才截图。
- **不碰运气抓 <0.3s 瞬时 FX、不让用户手动陪打**：写**临时(不提交)验收 harness**把 FX 摆好定格够久（`Engine.time_scale≈0.15` 慢放/暂停/循环），在已知时刻截图，验后删。
- **用日志掐时机**：`logs_read(source="game")` 拿运行中 stdout（SPAWN/DEATH/TOWER HIT 等），据此对准关键事件截图。
- **`game_manage input_mouse` 坐标不可靠**（被映射到桌面全局多屏坐标）：交互走代码钩子/harness 或让用户点。
