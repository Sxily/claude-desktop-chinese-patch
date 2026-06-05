Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

try {
    $config = Get-Config
    $install = Resolve-ClaudeInstall -Config $config
    $issues = @(Get-VerificationIssues -Config $config -Install $install)
    if ($issues.Count -gt 0) {
        Write-Host "VERIFY FAILED" -ForegroundColor Red
        foreach ($issue in $issues) { Write-Host " - $issue" }
        exit 1
    }

    $patchAnalysis = Analyze-PatchHits -Patches (Get-RequiredPatches) -AssetFiles (Get-AssetFiles -AssetsDir $install.AssetsDir)
    $matched = @($patchAnalysis | Where-Object { $_.matched }).Count
    $already = @($patchAnalysis | Where-Object { $_.alreadyPatched }).Count
    $unmatched = @($patchAnalysis | Where-Object { -not $_.matched -and -not $_.alreadyPatched }).Count
    $knownLocaleIds = (Get-KnownLocaleMessageIds).Count
    $runtimeTranslations = @(Get-JsonObjectEntries -Object (Get-RuntimeTranslations)).Count
    $missingPath = Join-Path (Get-ProjectRoot) (Get-Value $config "missingTranslationsPath" "locales\missing-zh-CN.json")
    $missingTranslations = 0
    if (Test-Path -LiteralPath $missingPath -PathType Leaf) {
        $missingTranslations = @(Read-JsonObject -Path $missingPath).Count
    }
    $coverage = [math]::Round((($knownLocaleIds + $runtimeTranslations) / ($knownLocaleIds + $runtimeTranslations + $missingTranslations)) * 100, 2)

    Write-Host "VERIFY OK" -ForegroundColor Green
    Write-Host "Target version: $($install.Version)"
    Write-Host "Required patch matches: ${matched}; already applied: ${already}; unmatched: ${unmatched}"
    Write-Host "Localization coverage: ${coverage}% (${missingTranslations} missing candidates)"
    exit 0
}
catch {
    Write-Host "Verify failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
