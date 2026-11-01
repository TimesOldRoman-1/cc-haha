# Update the personal branch onto upstream/main, then optionally rebuild.
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\update-personal.ps1
#   powershell -ExecutionPolicy Bypass -File .\update-personal.ps1 -Build

param([switch]$Build)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

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
    Write-Host '[update] Building the unpacked app...'
    Push-Location desktop
    try {
        bun run electron:package:dir
    } finally {
        Pop-Location
    }
    Write-Host '[update] Output: desktop\build-artifacts\electron\win-unpacked\' -ForegroundColor Green
}
