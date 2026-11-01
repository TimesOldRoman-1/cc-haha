# Update the personal branch onto upstream/main, then optionally rebuild.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\update-personal.ps1
#   powershell -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build
#
# The build output is deliberately kept in build-artifacts\personal-next so it
# never touches the stock install at C:\Claude Code Haha.

param([switch]$Build)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$OutDirRel = 'build-artifacts\personal-next'
$OutDirAbs = Join-Path $PSScriptRoot "desktop\$OutDirRel"
$ExePath = Join-Path $OutDirAbs 'win-unpacked\Claude Code Haha.exe'

if ($Build) {
    $running = Get-Process 'Claude Code Haha' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($OutDirAbs, [System.StringComparison]::OrdinalIgnoreCase) }
    if ($running) {
        Write-Host '[update] The personal build is running. Close it first, then rerun with -Build.' -ForegroundColor Yellow
        $running | Select-Object Id, Path | Format-Table -AutoSize
        exit 1
    }
}

git diff --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host '[update] Working tree has uncommitted changes. Commit or stash them first.' -ForegroundColor Yellow
    exit 1
}

Write-Host '[update] Fetching upstream...'
git fetch upstream --tags
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host '[update] Rebasing personal onto upstream/main...'
git rebase upstream/main
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '[update] Rebase stopped. Resolve the conflicts below, then:' -ForegroundColor Yellow
    Write-Host '  git add <file>'
    Write-Host '  git rebase --continue'
    Write-Host 'To abort this update: git rebase --abort'
    Write-Host ''
    git status --short
    exit 1
}

Write-Host '[update] Rebase done.'

if ($Build) {
    Write-Host '[update] Cleaning old output...'
    if (Test-Path -LiteralPath $OutDirAbs) {
        Remove-Item -LiteralPath $OutDirAbs -Recurse -Force
    }

    Push-Location desktop
    try {
        Write-Host '[update] Building sidecars...'
        bun run build:sidecars
        if ($LASTEXITCODE -ne 0) { throw 'build:sidecars failed' }

        Write-Host '[update] Building renderer...'
        bun run build
        if ($LASTEXITCODE -ne 0) { throw 'renderer build failed' }

        Write-Host '[update] Building Electron main/preload...'
        bun run build:electron
        if ($LASTEXITCODE -ne 0) { throw 'electron build failed' }

        Write-Host '[update] Packaging unpacked app...'
        bunx electron-builder --dir --publish never "--config.directories.output=$OutDirRel"
        # electron-builder may exit non-zero while extracting its Windows
        # signing cache on machines without symlink privileges. By then the
        # unpacked app is already written, so judge the result by the exe.
    } finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "Build did not produce $ExePath"
    }
    Write-Host "[update] Output: $ExePath" -ForegroundColor Green
    Write-Host '[update] Close the old build, then run the exe above.' -ForegroundColor Green
}
