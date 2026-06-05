Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

function Merge-JsonKeys {
    param(
        [string]$TemplatePath,
        [string]$TargetPath,
        [string]$FallbackPath = $null
    )

    $template = Read-JsonObject -Path $TemplatePath
    $target = Read-JsonObject -Path $TargetPath
    $fallback = @{}
    if ($FallbackPath -and (Test-Path -LiteralPath $FallbackPath -PathType Leaf)) {
        $fallback = Read-JsonObject -Path $FallbackPath
    }

    $ordered = [ordered]@{}
    $added = New-Object System.Collections.ArrayList
    $kept = 0
    $fallbackUsed = 0

    foreach ($key in @($template.Keys | Sort-Object)) {
        $existing = Get-Value -Object $target -Key $key -Default $null
        if ($null -ne $existing -and -not [string]::IsNullOrWhiteSpace([string]$existing)) {
            $ordered[$key] = $existing
            $kept++
            continue
        }

        $fallbackValue = Get-Value -Object $fallback -Key $key -Default $null
        if ($null -ne $fallbackValue -and -not [string]::IsNullOrWhiteSpace([string]$fallbackValue)) {
            $ordered[$key] = $fallbackValue
            $fallbackUsed++
        } else {
            $ordered[$key] = "TODO-ZH: $($template[$key])"
            [void]$added.Add($key)
        }
    }

    foreach ($key in @($target.Keys | Sort-Object)) {
        if (-not $ordered.Contains($key)) {
            $ordered[$key] = $target[$key]
            $kept++
        }
    }

    Write-JsonFile -Path $TargetPath -Value $ordered
    return [pscustomobject]@{
        target = $TargetPath
        templateKeys = @($template.Keys).Count
        finalKeys = $ordered.Count
        kept = $kept
        fallbackUsed = $fallbackUsed
        todo = $added.Count
        todoKeys = @($added)
    }
}

try {
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    $artifacts = Get-ProjectArtifacts

    $reports = New-Object System.Collections.ArrayList
    [void]$reports.Add((Merge-JsonKeys -TemplatePath (Join-Path $install.I18nDir "ja-JP.json") -TargetPath $artifacts.IonLocale))
    [void]$reports.Add((Merge-JsonKeys -TemplatePath (Join-Path $install.I18nDir "ja-JP.overrides.json") -TargetPath $artifacts.IonOverrides -FallbackPath $artifacts.IonLocale))
    [void]$reports.Add((Merge-JsonKeys -TemplatePath (Join-Path $install.StatsigDir "ja-JP.json") -TargetPath $artifacts.StatsigLocale))

    $reportPath = Join-Path (Get-ProjectRoot) "locales\sync-zh-CN-report.json"
    Write-JsonFile -Path $reportPath -Value $reports

    foreach ($report in $reports) {
        Write-Host "Synced: $($report.target)" -ForegroundColor Green
        Write-Host "  template=$($report.templateKeys) final=$($report.finalKeys) fallback=$($report.fallbackUsed) todo=$($report.todo)"
    }
    Write-Host "Report: $reportPath" -ForegroundColor Gray

    $todoTotal = ($reports | Measure-Object -Property todo -Sum).Sum
    if ($todoTotal -gt 0) {
        Write-Host "TODO-ZH entries remain: $todoTotal" -ForegroundColor Yellow
        exit 2
    }
    exit 0
}
catch {
    Write-Host "Sync failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
