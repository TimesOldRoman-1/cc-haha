# Update the personal branch onto upstream/main, verify the personal features,
# then optionally rebuild the unpacked Windows app.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\update-personal.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build -SkipTests
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build -SkipInstall
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build -OutDir build-artifacts\personal-next
#
# The build output is deliberately kept away from the stock install at
# C:\Claude Code Haha and from the build that may currently be running.

param(
    [switch]$Build,
    [switch]$SkipTests,
    [switch]$SkipInstall,
    [string]$OutDir = 'build-artifacts\personal-next'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Set-Location -LiteralPath $PSScriptRoot

$OutDirRel = $OutDir
$OutDirAbs = Join-Path $PSScriptRoot ("desktop\" + $OutDirRel)
$ExePath = Join-Path $OutDirAbs 'win-unpacked\Claude Code Haha.exe'
$GeneratedPreviewAgent = 'desktop/src-tauri/resources/preview-agent.js'

function Stop-Update {
    param([string]$Message)
    Write-Host ('[update] ' + $Message) -ForegroundColor Red
    exit 1
}

Write-Host ('[update] Workspace: ' + $PSScriptRoot) -ForegroundColor Cyan

$branchRaw = git rev-parse --abbrev-ref HEAD
if ($LASTEXITCODE -ne 0) { Stop-Update 'Not a git working tree.' }
$branch = ($branchRaw | Out-String).Trim()
Write-Host ('[update] Branch: ' + $branch)

$desktopPkg = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'desktop\package.json') -Raw | ConvertFrom-Json
Write-Host ('[update] Desktop version (current): ' + $desktopPkg.version)

if ($Build) {
    $running = Get-Process 'Claude Code Haha' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($OutDirAbs, [System.StringComparison]::OrdinalIgnoreCase) }
    if ($running) {
        Write-Host '[update] The target output directory is running. Close it first, then rerun with -Build.' -ForegroundColor Yellow
        $running | Select-Object Id, Path | Format-Table -AutoSize
        exit 1
    }
}

# The renderer build regenerates this tracked bundle; it is build noise, not a
# personal feature. Stash it so a rebase can proceed. Everything else must be
# committed.
$status = @(git -c core.quotepath=false status --porcelain)
$unexpected = @($status | Where-Object { $_ -notmatch 'desktop/src-tauri/resources/preview-agent\.js$' })
if ($unexpected.Count -gt 0) {
    Write-Host '[update] Working tree has uncommitted changes. Commit them first:' -ForegroundColor Yellow
    $unexpected | ForEach-Object { Write-Host ('  ' + $_) }
    Write-Host '[update] The generated preview-agent.js is tolerated automatically; anything else is not.' -ForegroundColor Yellow
    exit 1
}
if ($status.Count -gt 0) {
    Write-Host '[update] Stashing generated preview-agent.js...'
    git stash push -m 'auto: preview-agent build artifact' -- $GeneratedPreviewAgent
    if ($LASTEXITCODE -ne 0) { Stop-Update 'Could not stash preview-agent.js.' }
}

Write-Host '[update] Fetching upstream...'
git fetch upstream --tags
if ($LASTEXITCODE -ne 0) { Stop-Update 'git fetch upstream failed.' }

$upstreamVersion = 'unknown'
try {
    $upstreamRaw = git show upstream/main:desktop/package.json | Out-String
    $upstreamVersion = ($upstreamRaw | ConvertFrom-Json).version
} catch {
    $upstreamVersion = 'unknown'
}
Write-Host ('[update] Desktop version (upstream/main): ' + $upstreamVersion)

Write-Host '[update] Rebasing personal onto upstream/main...'
git rebase upstream/main
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '[update] Rebase stopped. Resolve the conflicts below, then:' -ForegroundColor Yellow
    Write-Host '  git add <file>'
    Write-Host '  $env:GIT_EDITOR="true"; git rebase --continue'
    Write-Host 'To abort this update: git rebase --abort'
    Write-Host ''
    git status --short
    exit 1
}

$personalCommitsRaw = git rev-list --count upstream/main..HEAD
$personalCommits = ($personalCommitsRaw | Out-String).Trim()
Write-Host ('[update] Rebase done. Personal commits on top of upstream/main: ' + $personalCommits)

Write-Host ''
Write-Host '[update] Verifying personal features...'
& (Join-Path $PSScriptRoot 'verify-personal.ps1') -SkipTests:$SkipTests
if ($LASTEXITCODE -ne 0) { Stop-Update 'Personal feature verification failed.' }
Set-Location -LiteralPath $PSScriptRoot

if ($Build) {
    if (-not $SkipInstall) {
        Write-Host '[update] Installing dependencies (root / desktop / mobile / adapters)...'
        $installDirs = @('', 'desktop', 'mobile', 'adapters')
        foreach ($dir in $installDirs) {
            $target = $PSScriptRoot
            if ($dir -ne '') { $target = Join-Path $PSScriptRoot $dir }
            Write-Host ('  bun install in ' + $target)
            Push-Location -LiteralPath $target
            try {
                & bun install
                if ($LASTEXITCODE -ne 0) { throw ('bun install failed in ' + $target) }
            } finally {
                Pop-Location
            }
        }
    }

    if (Test-Path -LiteralPath $OutDirAbs) {
        Write-Host ('[update] Removing previous staging output: ' + $OutDirAbs)
        Remove-Item -LiteralPath $OutDirAbs -Recurse -Force
    }

    Push-Location -LiteralPath 'desktop'
    try {
        Write-Host '[update] Building sidecars...'
        & bun run build:sidecars
        if ($LASTEXITCODE -ne 0) { throw 'build:sidecars failed' }

        Write-Host '[update] Building renderer (includes GenUI assets)...'
        & bun run build
        if ($LASTEXITCODE -ne 0) { throw 'renderer build failed' }

        Write-Host '[update] Building Electron main/preload...'
        & bun run build:electron
        if ($LASTEXITCODE -ne 0) { throw 'electron build failed' }

        Write-Host '[update] Packaging unpacked app...'
        & bunx electron-builder --dir --publish never ("--config.directories.output=" + $OutDirRel)
        # electron-builder may exit non-zero while extracting its Windows
        # signing cache on machines without symlink privileges. The unpacked
        # app is already written by then, so judge by the exe below.
    } finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $ExePath)) {
        Stop-Update ('Build did not produce ' + $ExePath)
    }

    Write-Host ''
    Write-Host '[update] Verifying packaged output...'
    & (Join-Path $PSScriptRoot 'verify-personal.ps1') -SkipTests -BuildDir $OutDirAbs
    if ($LASTEXITCODE -ne 0) { Stop-Update 'Packaged output verification failed.' }

    Write-Host ''
    Write-Host ('[update] Output: ' + $ExePath) -ForegroundColor Green
    Write-Host '[update] Close the running personal build, then launch the exe above (or update your shortcut).' -ForegroundColor Green
} else {
    Write-Host '[update] Source is ready. Re-run with -Build to produce an unpacked app.' -ForegroundColor Green
}

exit 0
