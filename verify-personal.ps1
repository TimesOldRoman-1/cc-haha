# Verify that the personal fork's bespoke features are still present after an
# upstream rebase, and optionally that a packaged build contains them.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-personal.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-personal.ps1 -SkipTests
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-personal.ps1 -BuildDir desktop\build-artifacts\personal-next
#
# Exit code 0 = all checks passed; 1 = at least one failure.

param(
    [string]$BuildDir = '',
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$script:Checks = 0
$script:Failures = 0

function Test-Feature {
    param(
        [string]$Name,
        [scriptblock]$Condition,
        [string]$Hint = ''
    )
    $script:Checks++
    $ok = $false
    try {
        $ok = [bool](& $Condition)
    } catch {
        $ok = $false
    }
    if ($ok) {
        Write-Host ("[PASS] " + $Name) -ForegroundColor Green
    } else {
        $script:Failures++
        Write-Host ("[FAIL] " + $Name) -ForegroundColor Red
        if ($Hint -ne '') {
            Write-Host ("       " + $Hint) -ForegroundColor Yellow
        }
    }
}

function Test-FileContains {
    param(
        [string]$Path,
        [string]$Needle
    )
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
Write-Host ("CC-Haha personal verification  (desktop version " + $version + ")") -ForegroundColor Cyan
Write-Host '== Source markers =='

# 1. DeepSeek theme
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

# 2. Workbench home
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

# 3. Windows notification identity (AUMID)
Test-Feature 'AUMID: personal app identity' {
    Test-FileContains 'desktop/electron/services/appIdentity.ts' 'com.claude-code-haha.desktop.personal'
} 'Expected WINDOWS_APP_USER_MODEL_ID to end in .personal.'
Test-Feature 'AUMID: assertion test exists' {
    Test-Path -LiteralPath 'desktop/electron/services/appIdentity.test.ts' -PathType Leaf
} 'appIdentity.test.ts is missing.'

# 4. Profile isolation
Test-Feature 'Isolation: personal userData path' {
    Test-FileContains 'desktop/electron/main.ts' 'claude-code-desktop-personal'
} 'Expected app.setPath(userData) to use claude-code-desktop-personal.'

# 5. GenUI renderer
Test-Feature 'GenUI: renderer component' {
    Test-Path -LiteralPath 'desktop/src/components/genui/GenuiRenderer.tsx' -PathType Leaf
} 'GenuiRenderer.tsx is missing.'
Test-Feature 'GenUI: markdown fence branch' {
    Test-FileContains 'desktop/src/components/markdown/MarkdownRenderer.tsx' 'dsh-ui'
} 'Expected the dsh-ui fence branch in MarkdownRenderer.tsx.'
Test-Feature 'GenUI: action bridge' {
    Test-FileContains 'desktop/src/components/chat/AssistantMessage.tsx' 'genui-action'
} 'Expected the [genui-action] bridge in AssistantMessage.tsx.'
Test-Feature 'GenUI: asset copy script' {
    Test-Path -LiteralPath 'desktop/scripts/copy-genui-assets.ts' -PathType Leaf
} 'copy-genui-assets.ts is missing.'
Test-Feature 'GenUI: dependency pinned' {
    Test-FileContains 'desktop/package.json' 'dsh-genui'
} 'Expected @changfenhuang/dsh-genui in desktop/package.json.'

# 6. Host-side GenUI injection
Test-Feature 'Injection: compact prompt module' {
    Test-Path -LiteralPath 'src/server/services/genuiSystemPrompt.ts' -PathType Leaf
} 'genuiSystemPrompt.ts is missing.'
Test-Feature 'Injection: prompt exported' {
    Test-FileContains 'src/server/services/genuiSystemPrompt.ts' 'GENUI_SYSTEM_PROMPT'
} 'Expected GENUI_SYSTEM_PROMPT export.'
Test-Feature 'Injection: conversation service wires it' {
    Test-FileContains 'src/server/services/conversationService.ts' 'GENUI_SYSTEM_PROMPT'
} 'Expected GENUI_SYSTEM_PROMPT in conversationService.ts.'
Test-Feature 'Injection: --append-system-prompt flag' {
    Test-FileContains 'src/server/services/conversationService.ts' '--append-system-prompt'
} 'Expected the CLI flag in buildSessionCliArgs.'
Test-Feature 'Injection: regression tests' {
    Test-FileContains 'src/server/__tests__/conversation-service.test.ts' 'injects the compact GenUI system prompt'
} 'Expected the GenUI injection test.'

# 7. Native build prerequisites
Test-Feature 'Build: agent-desktop staged' {
    Test-Path -LiteralPath 'desktop/src-tauri/binaries/agent-desktop.exe' -PathType Leaf
} 'Copy agent-desktop.exe from the official install; cargo is not required.'
Test-Feature 'Build: agent-desktop manifest' {
    Test-Path -LiteralPath 'desktop/src-tauri/binaries/agent-desktop-manifest.json' -PathType Leaf
} 'Copy agent-desktop-manifest.json with the matching commit.'

if (-not $SkipTests) {
    Write-Host ''
    Write-Host '== Desktop tests (theme + GenUI + AUMID) =='
    Push-Location -LiteralPath 'desktop'
    try {
        & bun run test -- --run src/theme/globals.test.ts src/theme/bootstrapScript.test.ts src/theme/contrast.test.ts src/components/genui/GenuiRenderer.test.tsx src/components/markdown/MarkdownRenderer.test.tsx electron/services/appIdentity.test.ts
        $desktopExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    Test-Feature 'Desktop regression suite' {
        $desktopExit -eq 0
    } 'Expected 300+ tests passing. Read the first failure above.'

    Write-Host ''
    Write-Host '== Server tests (host injection) =='
    & bun test -t 'GenUI' src/server/__tests__/conversation-service.test.ts
    $serverExit = $LASTEXITCODE
    Test-Feature 'Server GenUI injection tests' {
        $serverExit -eq 0
    } 'Expected 2 passing tests (main session injects, team worker does not).'
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
    $sidecarDir = Join-Path $absBuild 'win-unpacked\resources\app.asar.unpacked\src-tauri\binaries'
    $asar = Join-Path $absBuild 'win-unpacked\resources\app.asar'
    $distMermaid = Join-Path $PSScriptRoot 'desktop\dist\genui-assets\mermaid.js'
    $sourcePrompt = Join-Path $PSScriptRoot 'src\server\services\genuiSystemPrompt.ts'

    Test-Feature 'Package: app executable' {
        Test-Path -LiteralPath $exe -PathType Leaf
    } ('Missing ' + $exe)

    Test-Feature 'Package: app.asar' {
        Test-Path -LiteralPath $asar -PathType Leaf
    } ('Missing ' + $asar)

    $packagedSidecar = $null
    if (Test-Path -LiteralPath $sidecarDir -PathType Container) {
        $packagedSidecar = Get-ChildItem -LiteralPath $sidecarDir -Filter 'claude-sidecar-*.exe' -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }
    Test-Feature 'Package: sidecar binary' {
        $null -ne $packagedSidecar
    } 'Expected claude-sidecar-<triple>.exe under resources\app.asar.unpacked\src-tauri\binaries.'

    Test-Feature 'Package: sidecar newer than GenUI prompt source' {
        if ($null -eq $packagedSidecar) { return $false }
        if (-not (Test-Path -LiteralPath $sourcePrompt -PathType Leaf)) { return $false }
        return ($packagedSidecar.LastWriteTime -gt (Get-Item -LiteralPath $sourcePrompt).LastWriteTime)
    } 'The packaged sidecar predates genuiSystemPrompt.ts. Run build:sidecars and repackage.'

    Test-Feature 'Package: GenUI engine assets in dist' {
        Test-Path -LiteralPath $distMermaid -PathType Leaf
    } 'Run bun run build (it copies genui assets into dist/genui-assets).'
}

Write-Host ''
Write-Host ("Checks: " + $script:Checks + "   Failures: " + $script:Failures) -ForegroundColor Cyan
if ($script:Failures -gt 0) {
    Write-Host 'PERSONAL FEATURE VERIFICATION FAILED' -ForegroundColor Red
    exit 1
}
Write-Host 'PERSONAL FEATURES OK' -ForegroundColor Green
exit 0
