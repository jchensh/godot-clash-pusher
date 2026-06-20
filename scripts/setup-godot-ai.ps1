# Windows PowerShell helper for local Godot AI MCP setup.
param(
	[string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
	[string]$Proxy = "http://127.0.0.1:7897",
	[bool]$ConfigureCodex = $true,
	[bool]$ConfigureClaude = $true,
	[bool]$SetTelemetryOptOut = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
	param([string]$Message)
	Write-Host "[setup-godot-ai] $Message"
}

function Command-Exists {
	param([string]$Name)
	return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-UserPathIfMissing {
	param([string]$PathToAdd)
	if (-not (Test-Path -LiteralPath $PathToAdd)) {
		return
	}
	$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
	if ([string]::IsNullOrWhiteSpace($userPath)) {
		$userPath = ""
	}
	$parts = $userPath -split ";" | Where-Object { $_ -ne "" }
	if ($parts -notcontains $PathToAdd) {
		$newPath = if ($userPath.EndsWith(";") -or $userPath.Length -eq 0) {
			$userPath + $PathToAdd
		} else {
			$userPath + ";" + $PathToAdd
		}
		[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
		Write-Step "Added uv directory to user PATH. Open a new terminal to inherit it."
	}
	$env:Path = $PathToAdd + ";" + $env:Path
}

function Ensure-Uv {
	$wingetUvDir = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe"
	if (Command-Exists "uv") {
		Write-Step "uv found: $((uv --version) -join ' ')"
		return
	}
	if (Test-Path -LiteralPath (Join-Path $wingetUvDir "uv.exe")) {
		Add-UserPathIfMissing $wingetUvDir
		Write-Step "uv found in WinGet package directory: $wingetUvDir"
		return
	}
	if (-not (Command-Exists "winget")) {
		throw "uv is missing and winget is not available. Install uv manually: https://docs.astral.sh/uv/"
	}
	Write-Step "uv missing; installing astral-sh.uv with winget."
	$env:HTTP_PROXY = $Proxy
	$env:HTTPS_PROXY = $Proxy
	winget install --id astral-sh.uv -e --accept-package-agreements --accept-source-agreements
	Add-UserPathIfMissing $wingetUvDir
	if (-not (Command-Exists "uv") -and -not (Test-Path -LiteralPath (Join-Path $wingetUvDir "uv.exe"))) {
		throw "uv install completed but uv.exe was not found. Open a new terminal or check winget output."
	}
}

function Configure-CodexMcp {
	$codexDir = Join-Path $env:USERPROFILE ".codex"
	$configPath = Join-Path $codexDir "config.toml"
	New-Item -ItemType Directory -Force -Path $codexDir | Out-Null
	if (-not (Test-Path -LiteralPath $configPath)) {
		New-Item -ItemType File -Force -Path $configPath | Out-Null
	}
	$content = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath
	if ($content -match '\[mcp_servers\."godot-ai"\]') {
		Write-Step "Codex MCP config already contains godot-ai."
		return
	}
	$snippet = @'

[mcp_servers."godot-ai"]
url = "http://127.0.0.1:8000/mcp"
enabled = true
'@
	Add-Content -Encoding UTF8 -LiteralPath $configPath -Value $snippet
	Write-Step "Added godot-ai MCP config to $configPath"
}

function Configure-ClaudeMcp {
	if (-not (Command-Exists "claude")) {
		Write-Step "Claude Code CLI not found; skipping Claude MCP registration."
		return
	}
	$listOutput = claude mcp list 2>&1 | Out-String
	if ($listOutput -match 'godot-ai') {
		Write-Step "Claude MCP config already contains godot-ai."
		return
	}
	claude mcp add --scope user --transport http godot-ai http://127.0.0.1:8000/mcp
	Write-Step "Added godot-ai MCP config to Claude Code user scope."
}

Write-Step "Project root: $ProjectRoot"

$pluginCfg = Join-Path $ProjectRoot "addons\godot_ai\plugin.cfg"
if (-not (Test-Path -LiteralPath $pluginCfg)) {
	throw "Godot AI addon not found at $pluginCfg. Pull latest develop or copy addons/godot_ai into the project."
}

if (Command-Exists "godot") {
	Write-Step "Godot found: $((godot --version) -join ' ')"
} else {
	Write-Step "Godot command not found. Install Godot 4.6.3 and make sure 'godot' is on PATH."
}

if (Command-Exists "git") {
	Write-Step "Git found: $((git --version) -join ' ')"
} else {
	Write-Step "Git command not found. Install Git before normal development."
}

Ensure-Uv

if ($SetTelemetryOptOut) {
	[Environment]::SetEnvironmentVariable("GODOT_AI_DISABLE_TELEMETRY", "true", "User")
	[Environment]::SetEnvironmentVariable("DISABLE_TELEMETRY", "true", "User")
	$env:GODOT_AI_DISABLE_TELEMETRY = "true"
	$env:DISABLE_TELEMETRY = "true"
	Write-Step "Set Godot AI telemetry opt-out user environment variables."
}

if ($ConfigureCodex) {
	Configure-CodexMcp
}

if ($ConfigureClaude) {
	Configure-ClaudeMcp
}

Write-Step "Done. Open Godot with: godot --path `"$ProjectRoot`" -e"
Write-Step "Then verify Claude with: claude mcp list"
