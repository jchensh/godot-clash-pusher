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
godot --headless --path F:\godotProject --script res://tests/test_runner.gd
```

macOS example:

```bash
godot --headless --path /path/to/godotProject --script res://tests/test_runner.gd
```

Open the editor:

```powershell
godot --path F:\godotProject -e
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

## Rules For Agents

- Use headless tests for logic correctness.
- Use Godot AI MCP as a display/editor aid: scene hierarchy, screenshots,
  logs, runtime state, UI/animation/effect debugging.
- Do not use MCP writes to bypass `PLAN_V2.md` or the one-step-at-a-time
  confirmation discipline.
- Visual quality and game feel still require human verification in the editor.
