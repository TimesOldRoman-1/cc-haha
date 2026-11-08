# Verify the theme-only personal branch: DeepSeek theme, workbench, profile
# isolation and the personal AUMID. Also asserts that GenUI is absent.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-theme.ps1
#   ... -SkipTests
#   ... -BuildDir desktop\build-artifacts\theme-next

param(
    [string]$BuildDir = '',
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
Set-Location -LiteralPath $PSScriptRoot

$script:Checks = 0
$script:Failures = 0

function Test-Feature {
    param([string]$Name, [scriptblock]$Condition, [string]$Hint = '')
    $script:Checks++
    $ok = $false
    try { $ok = [bool](& $Condition) } catch { $ok = $false }
    if ($ok) {
        Write-Host ("[PASS] " + $Name) -ForegroundColor Green
    } else {
        $script:Failures++
        Write-Host ("[FAIL] " + $Name) -ForegroundColor Red
        if ($Hint -ne '') { Write-Host ("       " + $Hint) -ForegroundColor Yellow }
    }
}

function Test-FileContains {
    param([string]$Path, [string]$Needle)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $raw = Get-Content -LiteralPath $Path -Raw
    return ($raw.IndexOf($Needle, [System.StringComparison]::Ordinal) -ge 0)
}

$version = 'unknown'
$pkgFile = Join-Path $PSScriptRoot 'desktop\package.json'
if (Test-Path -LiteralPath $pkgFile) {
    $version = (Get-Content -LiteralPath $pkgFile -Raw | ConvertFrom-Json).version
}

Write-Host ''
Write-Host ("CC-Haha theme branch verification  (desktop version " + $version + ")") -ForegroundColor Cyan
Write-Host '== Theme =='

Test-Feature 'Theme: deepseek in settings types' {
    Test-FileContains 'desktop/src/types/settings.ts' 'deepseek'
} 'Expected THEME_MODES / DARK_THEME_MODES to contain deepseek.'
Test-Feature 'Theme: deepseek background mapping' {
    Test-FileContains 'desktop/src/theme/systemAppearance.ts' 'deepseek'
} 'Expected THEME_BACKGROUNDS.deepseek.'
Test-Feature 'Theme: deepseek CSS block' {
    Test-FileContains 'desktop/src/theme/globals.css' '[data-theme="deepseek"]'
} 'Expected the [data-theme="deepseek"] block in globals.css.'
Test-Feature 'Theme: deepseek pre-hydration entry' {
    Test-FileContains 'desktop/index.html' 'deepseek'
} 'Expected deepseek in the pre-hydration theme script.'

Write-Host '== Workbench =='
Test-Feature 'Workbench: page exists' {
    Test-Path -LiteralPath 'desktop/src/pages/WorkbenchHome.tsx' -PathType Leaf
} 'WorkbenchHome.tsx is missing.'
Test-Feature 'Workbench: home tab id registered' {
    Test-FileContains 'desktop/src/stores/tabStore.ts' 'HOME_TAB_ID'
} 'Expected HOME_TAB_ID in tabStore.ts.'
Test-Feature 'Workbench: router renders home' {
    Test-FileContains 'desktop/src/components/layout/ContentRouter.tsx' 'WorkbenchHome'
} 'Expected WorkbenchHome in ContentRouter.tsx.'
Test-Feature 'Workbench: sidebar entry' {
    Test-FileContains 'desktop/src/components/layout/Sidebar.tsx' 'HOME_TAB_ID'
} 'Expected the workbench sidebar entry.'

Write-Host '== Isolation and identity =='
Test-Feature 'Isolation: personal userData path' {
    Test-FileContains 'desktop/electron/main.ts' 'claude-code-desktop-personal'
} 'Expected app.setPath(userData) to use claude-code-desktop-personal.'
Test-Feature 'AUMID: personal app identity' {
    Test-FileContains 'desktop/electron/services/appIdentity.ts' 'com.claude-code-haha.desktop.personal'
} 'Expected WINDOWS_APP_USER_MODEL_ID to end in .personal.'
Test-Feature 'AUMID: assertion test exists' {
    Test-Path -LiteralPath 'desktop/electron/services/appIdentity.test.ts' -PathType Leaf
} 'appIdentity.test.ts is missing.'

Write-Host '== GenUI must stay out =='
Test-Feature 'No GenUI: renderer directory absent' {
    -not (Test-Path -LiteralPath 'desktop/src/components/genui' -PathType Container)
} 'This is the theme-only branch; remove GenUI if it reappears.'
Test-Feature 'No GenUI: host prompt absent' {
    -not (Test-Path -LiteralPath 'src/server/services/genuiSystemPrompt.ts' -PathType Leaf)
} 'This is the theme-only branch; the host prompt must not be injected.'
Test-Feature 'No GenUI: dependency absent' {
    -not (Test-FileContains 'desktop/package.json' 'dsh-genui')
} 'Remove @changfenhuang/dsh-genui from desktop/package.json.'

Write-Host '== Build prerequisites =='
Test-Feature 'Build: agent-desktop staged' {
    Test-Path -LiteralPath 'desktop/src-tauri/binaries/agent-desktop.exe' -PathType Leaf
} 'Copy agent-desktop.exe from the official install; cargo is not required.'
Test-Feature 'Build: agent-desktop manifest' {
    Test-Path -LiteralPath 'desktop/src-tauri/binaries/agent-desktop-manifest.json' -PathType Leaf
} 'Copy agent-desktop-manifest.json with the matching commit.'

if (-not $SkipTests) {
    Write-Host ''
    Write-Host '== Theme tests =='
    Push-Location -LiteralPath 'desktop'
    try {
        & bun run test -- --run src/theme/globals.test.ts src/theme/bootstrapScript.test.ts src/theme/contrast.test.ts src/theme/systemAppearance.test.ts src/theme/designSystem.test.ts
        $desktopExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    Test-Feature 'Theme regression suite' {
        $desktopExit -eq 0
    } 'Expected ~261 tests passing. Note: paletteEscapes/tokenUsage have pre-existing upstream failures; they are not part of this suite.'
}

if ($BuildDir -ne '') {
    Write-Host ''
    Write-Host '== Packaged build =='
    if ([System.IO.Path]::IsPathRooted($BuildDir)) {
        $absBuild = $BuildDir
    } else {
        $absBuild = Join-Path $PSScriptRoot $BuildDir
    }
    $exe = Join-Path $absBuild 'win-unpacked\Claude Code Haha.exe'
    $asar = Join-Path $absBuild 'win-unpacked\resources\app.asar'
    $sidecarDir = Join-Path $absBuild 'win-unpacked\resources\app.asar.unpacked\src-tauri\binaries'
    $distCss = Join-Path $PSScriptRoot 'desktop\dist\assets'

    Test-Feature 'Package: app executable' {
        Test-Path -LiteralPath $exe -PathType Leaf
    } ('Missing ' + $exe)
    Test-Feature 'Package: app.asar' {
        Test-Path -LiteralPath $asar -PathType Leaf
    } ('Missing ' + $asar)

    $sidecar = $null
    if (Test-Path -LiteralPath $sidecarDir -PathType Container) {
        $sidecar = Get-ChildItem -LiteralPath $sidecarDir -Filter 'claude-sidecar-*.exe' -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }
    Test-Feature 'Package: sidecar binary' {
        $null -ne $sidecar
    } 'Expected claude-sidecar-<triple>.exe under resources\app.asar.unpacked\src-tauri\binaries.'

    Test-Feature 'Package: deepseek in built CSS' {
        if (-not (Test-Path -LiteralPath $distCss -PathType Container)) { return $false }
        $hit = Get-ChildItem -LiteralPath $distCss -Filter '*.css' -File |
            Select-String -Pattern 'deepseek' -SimpleMatch -List
        return ($null -ne $hit)
    } 'Run bun run build; the built CSS should contain the deepseek theme.'
}

Write-Host ''
Write-Host ("Checks: " + $script:Checks + "   Failures: " + $script:Failures) -ForegroundColor Cyan
if ($script:Failures -gt 0) {
    Write-Host 'THEME BRANCH VERIFICATION FAILED' -ForegroundColor Red
    exit 1
}
Write-Host 'THEME BRANCH OK' -ForegroundColor Green
exit 0
