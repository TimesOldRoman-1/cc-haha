# Update the theme-only branch onto upstream/main, verify it, then optionally
# rebuild the unpacked Windows app. GenUI is intentionally absent.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\update-theme.ps1
#   ... -Build
#   ... -Build -SkipTests
#   ... -Build -SkipInstall
#   ... -Build -OutDir build-artifacts\theme-next

param(
    [switch]$Build,
    [switch]$SkipTests,
    [switch]$SkipInstall,
    [string]$OutDir = 'build-artifacts\theme-next'
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Set-Location -LiteralPath $PSScriptRoot

$OutDirRel = $OutDir
$OutDirAbs = Join-Path $PSScriptRoot ("desktop\" + $OutDirRel)
$ExePath = Join-Path $OutDirAbs 'win-unpacked\Claude Code Haha.exe'
$GeneratedPreviewAgent = 'desktop/src-tauri/resources/preview-agent.js'
$ExpectedBranch = 'personal-theme'

function Stop-Update {
    param([string]$Message)
    Write-Host ('[theme-update] ' + $Message) -ForegroundColor Red
    exit 1
}

Write-Host ('[theme-update] Workspace: ' + $PSScriptRoot) -ForegroundColor Cyan

$branchRaw = git rev-parse --abbrev-ref HEAD
if ($LASTEXITCODE -ne 0) { Stop-Update 'Not a git working tree.' }
$branch = ($branchRaw | Out-String).Trim()
Write-Host ('[theme-update] Branch: ' + $branch)
if ($branch -ne $ExpectedBranch) {
    Stop-Update ('Expected branch ' + $ExpectedBranch + ', got ' + $branch + '. Switch branches first.')
}

$desktopPkg = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'desktop\package.json') -Raw | ConvertFrom-Json
Write-Host ('[theme-update] Desktop version (current): ' + $desktopPkg.version)

if ($Build) {
    $running = Get-Process 'Claude Code Haha' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($OutDirAbs, [System.StringComparison]::OrdinalIgnoreCase) }
    if ($running) {
        Write-Host '[theme-update] The target output directory is running. Close it first, then rerun with -Build.' -ForegroundColor Yellow
        $running | Select-Object Id, Path | Format-Table -AutoSize
        exit 1
    }
}

$status = @(git -c core.quotepath=false status --porcelain)
$unexpected = @($status | Where-Object { $_ -notmatch 'desktop/src-tauri/resources/preview-agent\.js$' })
if ($unexpected.Count -gt 0) {
    Write-Host '[theme-update] Working tree has uncommitted changes. Commit them first:' -ForegroundColor Yellow
    $unexpected | ForEach-Object { Write-Host ('  ' + $_) }
    exit 1
}
if ($status.Count -gt 0) {
    Write-Host '[theme-update] Stashing generated preview-agent.js...'
    git stash push -m 'auto: preview-agent build artifact' -- $GeneratedPreviewAgent
    if ($LASTEXITCODE -ne 0) { Stop-Update 'Could not stash preview-agent.js.' }
}

Write-Host '[theme-update] Fetching upstream...'
git fetch upstream --tags
if ($LASTEXITCODE -ne 0) { Stop-Update 'git fetch upstream failed.' }

$upstreamVersion = 'unknown'
try {
    $upstreamRaw = git show upstream/main:desktop/package.json | Out-String
    $upstreamVersion = ($upstreamRaw | ConvertFrom-Json).version
} catch {
    $upstreamVersion = 'unknown'
}
Write-Host ('[theme-update] Desktop version (upstream/main): ' + $upstreamVersion)

Write-Host '[theme-update] Rebasing personal-theme onto upstream/main...'
git rebase upstream/main
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '[theme-update] Rebase stopped. Resolve the conflicts below, then:' -ForegroundColor Yellow
    Write-Host '  git add <file>'
    Write-Host '  $env:GIT_EDITOR="true"; git rebase --continue'
    Write-Host 'To abort this update: git rebase --abort'
    Write-Host ''
    git status --short
    exit 1
}

$personalCommitsRaw = git rev-list --count upstream/main..HEAD
$personalCommits = ($personalCommitsRaw | Out-String).Trim()
Write-Host ('[theme-update] Rebase done. Theme commits on top of upstream/main: ' + $personalCommits)

Write-Host ''
Write-Host '[theme-update] Verifying the theme branch...'
& (Join-Path $PSScriptRoot 'verify-theme.ps1') -SkipTests:$SkipTests
if ($LASTEXITCODE -ne 0) { Stop-Update 'Theme verification failed.' }
Set-Location -LiteralPath $PSScriptRoot

if ($Build) {
    if (-not $SkipInstall) {
        Write-Host '[theme-update] Installing dependencies (root / desktop / mobile / adapters)...'
        foreach ($dir in @('', 'desktop', 'mobile', 'adapters')) {
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
        Write-Host ('[theme-update] Removing previous staging output: ' + $OutDirAbs)
        Remove-Item -LiteralPath $OutDirAbs -Recurse -Force
    }

    Push-Location -LiteralPath 'desktop'
    try {
        Write-Host '[theme-update] Building sidecars...'
        & bun run build:sidecars
        if ($LASTEXITCODE -ne 0) { throw 'build:sidecars failed' }

        Write-Host '[theme-update] Building renderer...'
        & bun run build
        if ($LASTEXITCODE -ne 0) { throw 'renderer build failed' }

        Write-Host '[theme-update] Building Electron main/preload...'
        & bun run build:electron
        if ($LASTEXITCODE -ne 0) { throw 'electron build failed' }

        Write-Host '[theme-update] Packaging unpacked app...'
        & bunx electron-builder --dir --publish never ("--config.directories.output=" + $OutDirRel)
        # The unpacked app is written before the signing-cache step may fail;
        # judge by the exe below.
    } finally {
        Pop-Location
    }

    if (-not (Test-Path -LiteralPath $ExePath)) {
        Stop-Update ('Build did not produce ' + $ExePath)
    }

    Write-Host ''
    Write-Host '[theme-update] Verifying packaged output...'
    & (Join-Path $PSScriptRoot 'verify-theme.ps1') -SkipTests -BuildDir $OutDirAbs
    if ($LASTEXITCODE -ne 0) { Stop-Update 'Packaged output verification failed.' }

    Write-Host ''
    Write-Host ('[theme-update] Output: ' + $ExePath) -ForegroundColor Green
    Write-Host '[theme-update] Close the running theme build, then launch the exe above.' -ForegroundColor Green
} else {
    Write-Host '[theme-update] Source is ready. Re-run with -Build to produce an unpacked app.' -ForegroundColor Green
}

exit 0
