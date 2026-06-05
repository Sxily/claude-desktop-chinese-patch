Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Disable-CompressedCache {
    param([string]$Path, [string]$Timestamp)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $destination = "$Path.bak"
    if (Test-Path -LiteralPath $destination) {
        $destination = "$Path.$Timestamp.bak"
    }
    Rename-Item -LiteralPath $Path -NewName (Split-Path -Leaf $destination) -Force
    return $destination
}

function Get-VisibleFixPatches {
    $translations = Get-RuntimeTranslations
    $visibleSources = @(
        "OpenTelemetry collector endpoint",
        "Block auto-updates",
        "Auto-update enforcement window",
        "Block essential telemetry",
        "Block nonessential telemetry",
        "Block nonessential services",
        "This configuration contains sensitive values. They will be written to the exported file in plain text.",
        "macOS configuration profile",
        "Windows registry file",
        "Plain JSON",
        "Firewall allowlist (.txt)",
        "Copy to clipboard (redacted)",
        "Legacy Model",
        "Default",
        "Hide details",
        "Read in docs",
        "Skip login-mode chooser",
        "Connect a directory connector or add a custom endpoint to give agents tools.",
        "Connect GitHub, Linear"
    )
    $visiblePrefixes = @(
        "JSON array of model IDs or aliases",
        "Only affects **tool calls**",
        "Connect GitHub, Linear"
    )

    $visibleTranslations = @{}
    foreach ($source in $visibleSources) {
        $target = Get-Value -Object $translations -Key $source -Default $null
        if (-not [string]::IsNullOrWhiteSpace($target)) {
            $visibleTranslations[$source] = $target
        }
    }
    foreach ($entry in Get-JsonObjectEntries -Object $translations) {
        foreach ($prefix in $visiblePrefixes) {
            if ($entry.Name.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                $visibleTranslations[$entry.Name] = $entry.Value
            }
        }
    }

    $basePatches = @(Get-Patches)

    return @($basePatches + (New-RuntimeTranslationPatches -Translations $visibleTranslations))
}

try {
    if (-not (Test-IsAdministrator)) {
        throw "Administrator privileges are required to write Claude Desktop files under WindowsApps."
    }

    Write-Host "[1/5] Loading config and detecting Claude Desktop..." -ForegroundColor Cyan
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    $artifacts = Get-ProjectArtifacts
    Assert-PathExists -Path $artifacts.IonLocale -Description "project ion zh-CN locale"
    Write-Host "  Version: $($install.Version)" -ForegroundColor Green
    Write-Host "  resources: $($install.ResourcesDir)" -ForegroundColor Gray

    Write-Host "[2/5] Analyzing runtime patches..." -ForegroundColor Cyan
    $patches = Get-VisibleFixPatches
    Write-Host "  Patch rules: $($patches.Count)"
    $patchAnalysis = Analyze-PatchHits -Patches $patches -AssetFiles (Get-AssetFiles -AssetsDir $install.AssetsDir)
    $patchTargets = @(Get-PatchTargetFiles -PatchAnalysis $patchAnalysis)
    Write-Host "  Target files: $($patchTargets.Count)"

    Write-Host "[3/5] Creating backup..." -ForegroundColor Cyan
    $runDir = New-BackupRunDirectory -Config $config
    Backup-File -Source $install.IonLocale -BackupDir (Join-Path $runDir "ion")
    Backup-File -Source $install.IonLocaleZst -BackupDir (Join-Path $runDir "ion")
    foreach ($assetPath in $patchTargets) {
        Backup-File -Source $assetPath -BackupDir (Join-Path $runDir "assets")
        Backup-File -Source (Get-CompressedAssetPath -AssetPath $assetPath) -BackupDir (Join-Path $runDir "assets")
    }
    Write-Host "  Backup directory: $runDir" -ForegroundColor Gray

    Write-Host "[4/5] Applying locale and runtime patches..." -ForegroundColor Cyan
    Grant-PathAccess -Path $install.IonLocale
    Copy-Item -LiteralPath $artifacts.IonLocale -Destination $install.IonLocale -Force
    if (Test-Path -LiteralPath $install.IonLocaleZst -PathType Leaf) {
        Grant-PathAccess -Path $install.IonLocaleZst
        Disable-CompressedCache -Path $install.IonLocaleZst -Timestamp (Get-Timestamp) | Out-Null
    }

    $fileReport = New-Object System.Collections.ArrayList
    foreach ($assetPath in $patchTargets) {
        Grant-PathAccess -Path $assetPath
        $changes = @(Apply-PatchesToFile -Path $assetPath -Patches $patches)
        if ($changes.Count -eq 0) { continue }

        [void]$fileReport.Add([pscustomobject]@{ file = $assetPath; changes = $changes })
        $compressed = Get-CompressedAssetPath -AssetPath $assetPath
        if (Test-Path -LiteralPath $compressed -PathType Leaf) {
            Grant-PathAccess -Path $compressed
            Disable-CompressedCache -Path $compressed -Timestamp (Get-Timestamp) | Out-Null
        }
    }

    Write-Host "[5/5] Writing report..." -ForegroundColor Cyan
    $report = [pscustomobject]@{
        install = $install
        backup = $runDir
        targetFiles = $patchTargets.Count
        patchedFiles = $fileReport.Count
        files = $fileReport
    }
    $reportPath = Join-Path $runDir "visible-fixes-report.json"
    Write-JsonFile -Path $reportPath -Value $report

    Write-Host "Visible localization fixes applied." -ForegroundColor Green
    Write-Host "Patched files: $($fileReport.Count)"
    Write-Host "Backup directory: $runDir"
    Write-Host "Report: $reportPath"
    exit 0
}
catch {
    Write-Host "Visible localization fixes failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
