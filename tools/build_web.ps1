# tools/build_web.ps1
# Godot 4.6.3 Web build and URL dynamic injection script

param (
    [string]$ApiUrl = "",
    [string]$WsUrl = ""
)

$ErrorActionPreference = "Stop"

# 1. Ensure build directory exists
$BuildDir = Join-Path $PSScriptRoot "../build/web"
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
    Write-Host "Created build directory: $BuildDir" -ForegroundColor Green
}

# 2. Call Godot to export Web release
Write-Host "Starting Godot Web export..." -ForegroundColor Cyan
& godot --headless --path . --export-release "Web" "$BuildDir/index.html"
Write-Host "Godot export finished successfully." -ForegroundColor Green

# 3. Dynamic injection of API/WS URL
$HtmlFile = "$BuildDir/index.html"
if ($HtmlFile -and (Test-Path $HtmlFile)) {
    Write-Host "Injecting environment variables into index.html..." -ForegroundColor Cyan
    
    $InjectScript = @"

    <!-- Injected by Antigravity Build Script -->
    <script>
      window.GAME_API_URL = "$ApiUrl";
      window.GAME_WS_URL = "$WsUrl";
    </script>
"@
    
    $Content = Get-Content -Raw -Path $HtmlFile
    if ($Content -match "<head>") {
        $Content = $Content -replace "<head>", "<head>`n$InjectScript"
        Set-Content -Path $HtmlFile -Value $Content -NoNewline
        Write-Host "Successfully injected: API_URL='$ApiUrl', WS_URL='$WsUrl'" -ForegroundColor Green
    } else {
        Write-Warning "Could not find <head> tag in index.html to inject configuration."
    }
} else {
    Write-Error "Export failed. index.html was not found in $BuildDir"
}

Write-Host "Web client build completed." -ForegroundColor Green
