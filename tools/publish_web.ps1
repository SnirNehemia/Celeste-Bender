# publish_web.ps1 — export Windbound for the browser and publish it to GitHub Pages.
#
# What it does:
#   1. Runs Godot headless with the "Web" preset (export_presets.cfg) -> build/web/
#   2. Pushes the contents of build/web/ as a single commit to the `gh-pages` branch.
#      The branch is force-overwritten every time, so the big .wasm/.pck files
#      never pile up in the repo history (main stays small).
#
# GitHub Pages serves the gh-pages branch at:
#   https://snirnehemia.github.io/Celeste-Bender/
#
# Usage (from the project folder):
#   powershell -ExecutionPolicy Bypass -File tools/publish_web.ps1            # export + publish
#   powershell -ExecutionPolicy Bypass -File tools/publish_web.ps1 -NoPush    # export only

param(
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"

$godot = "D:\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe"
$projectDir = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectDir "build\web"

Set-Location $projectDir

# Fresh output folder so stale files from an older export never get published.
if (Test-Path $buildDir) { Remove-Item -Recurse -Force $buildDir }
New-Item -ItemType Directory -Force $buildDir | Out-Null

# .gdignore stops the Godot editor from importing the exported files as project assets.
New-Item -ItemType File -Force (Join-Path $projectDir "build\.gdignore") | Out-Null

# Debug export: keeps print()/errors visible in the browser console (chrome://inspect).
Write-Host "[publish] Exporting web build..."
& $godot --headless --path $projectDir --export-debug "Web" "$buildDir\index.html"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$buildDir\index.wasm")) {
    throw "[publish] Godot export failed (are the 4.4.1 export templates installed?)"
}

# .nojekyll tells GitHub Pages to serve files as-is instead of running Jekyll on them.
New-Item -ItemType File -Force (Join-Path $buildDir ".nojekyll") | Out-Null

if ($NoPush) {
    Write-Host "[publish] Export done (no push): $buildDir"
    exit 0
}

# Label the published build with the source commit, marking uncommitted changes.
$sourceCommit = (git rev-parse --short HEAD).Trim()
if (git status --porcelain) { $sourceCommit += "+uncommitted" }
$remoteUrl = (git remote get-url origin).Trim()

# Throwaway repo inside build/web: one commit, force-pushed to gh-pages.
Push-Location $buildDir
try {
    git init --quiet
    git checkout --quiet -b gh-pages
    git add -A
    git commit --quiet -m "Web build of $sourceCommit ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
    git push --force --quiet $remoteUrl gh-pages
    if ($LASTEXITCODE -ne 0) { throw "[publish] git push failed" }
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force (Join-Path $buildDir ".git") -ErrorAction SilentlyContinue
}

Write-Host "[publish] Published build of $sourceCommit -> https://snirnehemia.github.io/Celeste-Bender/"
Write-Host "[publish] Pages usually updates within ~1 minute. Refresh on the phone."
