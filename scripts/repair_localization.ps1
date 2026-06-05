Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$logPath = Join-Path $projectRoot "repair-localization-last.log"

function Write-LogLine {
    param([string]$Message)
    $Message | Tee-Object -FilePath $logPath -Append
}

function Invoke-RepairStep {
    param([string]$Name, [string]$ScriptPath)

    Write-LogLine ""
    Write-LogLine $Name
    Write-LogLine ("=" * $Name.Length)
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 2>&1 |
        Tee-Object -FilePath $logPath -Append
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

try {
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        Remove-Item -LiteralPath $logPath -Force
    }

    Write-LogLine "Claude Desktop localization repair"
    Write-LogLine "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-LogLine "Project: $projectRoot"

    Invoke-RepairStep -Name "[1/2] Applying visible UI localization fixes" -ScriptPath (Join-Path $PSScriptRoot "apply_visible_fixes.ps1")
    Invoke-RepairStep -Name "[2/2] Verifying localization" -ScriptPath (Join-Path $PSScriptRoot "verify_localization.ps1")

    Write-LogLine ""
    Write-LogLine "Repair completed successfully."
    Write-LogLine "Log: $logPath"
    exit 0
}
catch {
    Write-LogLine ""
    Write-LogLine "Repair failed: $($_.Exception.Message)"
    Write-LogLine "Log: $logPath"
    exit 1
}
