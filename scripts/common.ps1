Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Web.Extensions

function Read-Utf8Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8Text {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $script:Utf8NoBom)
}

function New-JsonSerializer {
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = 67108864
    return $serializer
}

function Read-JsonObject {
    param([string]$Path)
    return (New-JsonSerializer).DeserializeObject((Read-Utf8Text -Path $Path))
}

function Write-JsonFile {
    param([string]$Path, $Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (($null -ne $Value) -and
        ($Value -is [System.Collections.ICollection]) -and
        (-not ($Value -is [System.Collections.IDictionary])) -and
        ($Value.Count -eq 0)) {
        $json = "[]"
    } else {
        $json = ConvertTo-Json -InputObject $Value -Depth 12
    }
    Write-Utf8Text -Path $Path -Content ($json + "`n")
}

function Get-Value {
    param($Object, [string]$Key, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if (($Object.PSObject.Methods.Name -contains "ContainsKey") -and $Object.ContainsKey($Key)) {
            return $Object[$Key]
        }
        if (($null -ne $Object.Keys) -and ($Object.Keys -contains $Key)) {
            return $Object[$Key]
        }
        return $Default
    }
    if ($Object.PSObject.Properties.Name -contains $Key) {
        return $Object.$Key
    }
    return $Default
}

function Get-ProjectRoot {
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Get-Config {
    $config = Read-JsonObject -Path (Join-Path (Get-ProjectRoot) "config.json")
    if (-not (Get-Value $config "locale")) { $config["locale"] = "zh-CN" }
    if (-not (Get-Value $config "backupDirName")) { $config["backupDirName"] = "backups" }
    return $config
}

function Get-Patches {
    return Read-JsonObject -Path (Join-Path (Get-ProjectRoot) "patches\main-ui-patches.json")
}

function Get-RequiredPatches {
    return @(Get-Patches | Where-Object { [bool](Get-Value $_ "required" $false) })
}

function Get-RuntimeTranslations {
    $path = Join-Path (Get-ProjectRoot) "locales\runtime-zh-CN.translations.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return @{}
    }
    return Read-JsonObject -Path $path
}

function Get-JsonObjectEntries {
    param($Object)
    $entries = New-Object System.Collections.ArrayList
    if ($null -eq $Object) { return @($entries) }
    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($entry in $Object.GetEnumerator()) {
            [void]$entries.Add([pscustomobject]@{ Name = $entry.Key; Value = $entry.Value })
        }
        return @($entries)
    }
    foreach ($property in $Object.PSObject.Properties) {
        [void]$entries.Add([pscustomobject]@{ Name = $property.Name; Value = $property.Value })
    }
    return @($entries)
}

function Get-KnownLocaleMessageIds {
    $artifacts = Get-ProjectArtifacts
    $ids = @{}
    foreach ($path in @($artifacts.RootLocale, $artifacts.IonLocale, $artifacts.IonOverrides, $artifacts.StatsigLocale)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $locale = Read-JsonObject -Path $path
        foreach ($entry in Get-JsonObjectEntries -Object $locale) {
            if ($entry.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($entry.Value)) {
                $ids[$entry.Name] = $true
            }
        }
    }
    return $ids
}

function New-RuntimeTranslationPatches {
    param($Translations)
    $patches = New-Object System.Collections.ArrayList
    $shapes = @(
        @{ Kind = "defaultMessage"; Prefix = 'defaultMessage:"'; Suffix = '"' },
        @{ Kind = "label"; Prefix = 'label:"'; Suffix = '"' },
        @{ Kind = "title"; Prefix = 'title:"'; Suffix = '"' },
        @{ Kind = "cowork"; Prefix = 'cowork:"'; Suffix = '"' },
        @{ Kind = "placeholder"; Prefix = 'placeholder:"'; Suffix = '"' },
        @{ Kind = "aria-label"; Prefix = 'aria-label:"'; Suffix = '"' },
        @{ Kind = "group"; Prefix = 'group:"'; Suffix = '"' },
        @{ Kind = "banner"; Prefix = 'banner:"'; Suffix = '"' },
        @{ Kind = "body"; Prefix = 'body:"'; Suffix = '"' },
        @{ Kind = "description"; Prefix = 'description:"'; Suffix = '"' },
        @{ Kind = "description"; Prefix = "description:'"; Suffix = "'" },
        @{ Kind = "hint"; Prefix = 'hint:"'; Suffix = '"' },
        @{ Kind = "children"; Prefix = 'children:"'; Suffix = '"' },
        @{ Kind = "recents"; Prefix = 'recents:"'; Suffix = '"' },
        @{ Kind = "shared"; Prefix = 'shared:"'; Suffix = '"' }
    )

    foreach ($entry in @(Get-JsonObjectEntries -Object $Translations | Sort-Object Name)) {
        $source = $entry.Name
        $target = $entry.Value
        if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($target)) {
            continue
        }
        foreach ($shape in $shapes) {
            [void]$patches.Add([pscustomobject]@{
                description = "Runtime translation: $source"
                kind = "runtime-translation"
                required = $false
                find = "$($shape.Prefix)$source$($shape.Suffix)"
                replace = "$($shape.Prefix)$target$($shape.Suffix)"
            })
        }
    }
    return @($patches)
}

function Get-EffectivePatches {
    $basePatches = @(Get-Patches)
    $translationPatches = @(New-RuntimeTranslationPatches -Translations (Get-RuntimeTranslations))
    return @($basePatches + $translationPatches)
}

function Get-ProjectArtifacts {
    $projectRoot = Get-ProjectRoot
    return @{
        RootLocale = Join-Path $projectRoot "locales\root-zh-CN.json"
        IonLocale = Join-Path $projectRoot "locales\ion-zh-CN.json"
        IonLocaleZst = Join-Path $projectRoot "locales\ion-zh-CN.json.zst"
        IonOverrides = Join-Path $projectRoot "locales\ion-zh-CN.overrides.json"
        IonOverridesZst = Join-Path $projectRoot "locales\ion-zh-CN.overrides.json.zst"
        StatsigLocale = Join-Path $projectRoot "locales\statsig\zh-CN.json"
        StatsigLocaleZst = Join-Path $projectRoot "locales\statsig\zh-CN.json.zst"
        MissingTranslations = Join-Path $projectRoot "locales\missing-zh-CN.json"
    }
}

function Assert-PathExists {
    param([string]$Path, [string]$Description, [switch]$Directory)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description does not exist or cannot be accessed: $Path"
    }
    if ($Directory -and -not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Description is not a directory: $Path"
    }
    if (-not $Directory -and -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description is not a file: $Path"
    }
}

function Assert-ProjectArtifacts {
    param($Artifacts)
    foreach ($key in @("RootLocale", "IonLocale", "IonLocaleZst", "IonOverrides", "IonOverridesZst", "StatsigLocale", "StatsigLocaleZst")) {
        Assert-PathExists -Path $Artifacts[$key] -Description "project artifact $key"
    }
}

function Get-VersionFromClaudePackageName {
    param([string]$Name)
    if ($Name -match '^Claude_([0-9]+(?:\.[0-9]+)+)_') {
        return $Matches[1]
    }
    return $null
}

function New-ClaudeInstallInfo {
    param([string]$ResourcesDir, [string]$Version = "")
    $resources = [System.IO.Path]::GetFullPath($ResourcesDir)
    $i18n = Join-Path $resources "ion-dist\i18n"
    $assets = Join-Path $resources "ion-dist\assets\v1"
    return [pscustomobject]@{
        Version = $Version
        ResourcesDir = $resources
        AppAsar = Join-Path $resources "app.asar"
        I18nDir = $i18n
        StatsigDir = Join-Path $i18n "statsig"
        AssetsDir = $assets
        RootLocale = Join-Path $resources "zh-CN.json"
        IonLocale = Join-Path $i18n "zh-CN.json"
        IonLocaleZst = Join-Path $i18n "zh-CN.json.zst"
        IonOverrides = Join-Path $i18n "zh-CN.overrides.json"
        IonOverridesZst = Join-Path $i18n "zh-CN.overrides.json.zst"
        StatsigLocale = Join-Path $i18n "statsig\zh-CN.json"
        StatsigLocaleZst = Join-Path $i18n "statsig\zh-CN.json.zst"
    }
}

function Test-ClaudeInstallInfo {
    param($Install)
    return (
        (Test-Path -LiteralPath $Install.AppAsar -PathType Leaf) -and
        (Test-Path -LiteralPath $Install.I18nDir -PathType Container) -and
        (Test-Path -LiteralPath $Install.AssetsDir -PathType Container)
    )
}

function Find-ClaudeInstallFromAppx {
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        return $null
    }

    $packages = @(Get-AppxPackage -Name "Claude" -ErrorAction SilentlyContinue)
    foreach ($package in @($packages | Sort-Object @{ Expression = { [version]$_.Version }; Descending = $true })) {
        $installLocation = Get-Value -Object $package -Key "InstallLocation" -Default $null
        if (-not $installLocation) { continue }
        $install = New-ClaudeInstallInfo -ResourcesDir (Join-Path $installLocation "app\resources") -Version ([string]$package.Version)
        if (Test-ClaudeInstallInfo -Install $install) {
            return $install
        }
    }
    return $null
}

function Find-ClaudeInstall {
    param(
        [string]$WindowsAppsRoot = "C:\Program Files\WindowsApps",
        [string]$ManualInstallRoot = $null
    )

    if ($ManualInstallRoot) {
        $manual = New-ClaudeInstallInfo -ResourcesDir $ManualInstallRoot -Version "manual"
        if (-not (Test-ClaudeInstallInfo -Install $manual)) {
            throw "Manual Claude resources directory is incomplete: $ManualInstallRoot"
        }
        return $manual
    }

    $candidates = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $WindowsAppsRoot -PathType Container) {
        foreach ($dir in Get-ChildItem -LiteralPath $WindowsAppsRoot -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue) {
            $versionText = Get-VersionFromClaudePackageName -Name $dir.Name
            if (-not $versionText) { continue }
            $install = New-ClaudeInstallInfo -ResourcesDir (Join-Path $dir.FullName "app\resources") -Version $versionText
            if (Test-ClaudeInstallInfo -Install $install) {
                [void]$candidates.Add($install)
            }
        }
    }

    if ($candidates.Count -gt 0) {
        return @($candidates | Sort-Object @{ Expression = { [version]$_.Version }; Descending = $true })[0]
    }

    $appxInstall = Find-ClaudeInstallFromAppx
    if ($null -ne $appxInstall) {
        return $appxInstall
    }

    throw "No usable Claude Desktop installation found in $WindowsAppsRoot or AppX packages."
}

function Resolve-ClaudeInstall {
    param($Config)
    $emptyDiscovery = @{}
    $discovery = Get-Value -Object $Config -Key "installDiscovery" -Default $emptyDiscovery
    $windowsAppsRoot = Get-Value -Object $discovery -Key "windowsAppsRoot" -Default "C:\Program Files\WindowsApps"
    $manualInstallRoot = Get-Value -Object $discovery -Key "manualInstallRoot" -Default $null
    return Find-ClaudeInstall -WindowsAppsRoot $windowsAppsRoot -ManualInstallRoot $manualInstallRoot
}

function Get-ApplyTargets {
    param($Install)
    return @{
        rootLocale = $Install.RootLocale
        ionLocale = $Install.IonLocale
        ionLocaleZst = $Install.IonLocaleZst
        ionOverrides = $Install.IonOverrides
        ionOverridesZst = $Install.IonOverridesZst
        statsigLocale = $Install.StatsigLocale
        statsigLocaleZst = $Install.StatsigLocaleZst
        assetsDir = $Install.AssetsDir
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-BackupRoot {
    param($Config)
    return Join-Path (Get-ProjectRoot) (Get-Value $Config "backupDirName" "backups")
}

function Get-Timestamp {
    return Get-Date -Format "yyyyMMdd-HHmmss"
}

function New-BackupRunDirectory {
    param($Config)
    $backupRoot = Get-BackupRoot -Config $Config
    Ensure-Directory -Path $backupRoot
    $runDir = Join-Path $backupRoot (Get-Timestamp)
    Ensure-Directory -Path $runDir
    return $runDir
}

function Get-LatestBackupDirectory {
    param($Config)
    $backupRoot = Get-BackupRoot -Config $Config
    Assert-PathExists -Path $backupRoot -Description "backup directory" -Directory
    $latest = Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object Name | Select-Object -Last 1
    if ($null -eq $latest) { throw "No backup directory is available for rollback." }
    return $latest.FullName
}

function Backup-File {
    param([string]$Source, [string]$BackupDir)
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    Ensure-Directory -Path $BackupDir
    $destination = Join-Path $BackupDir ([System.IO.Path]::GetFileName($Source))
    $sourceStream = [System.IO.File]::OpenRead($Source)
    try {
        $destinationStream = [System.IO.File]::Create($destination)
        try {
            $sourceStream.CopyTo($destinationStream)
        }
        finally {
            $destinationStream.Dispose()
        }
    }
    finally {
        $sourceStream.Dispose()
    }
    [System.IO.File]::SetAttributes($destination, [System.IO.FileAttributes]::Normal)
}

function Restore-DirectoryFiles {
    param([string]$SourceDir, [string]$DestinationDir)
    $restored = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) { return $restored }
    Ensure-Directory -Path $DestinationDir
    foreach ($item in Get-ChildItem -LiteralPath $SourceDir -File) {
        $destination = Join-Path $DestinationDir $item.Name
        Copy-Item -LiteralPath $item.FullName -Destination $destination -Force
        [void]$restored.Add($destination)
    }
    return $restored
}

function Grant-PathAccess {
    param([string]$Path)
    $target = $Path
    if (-not (Test-Path -LiteralPath $target)) {
        $target = Split-Path -Path $Path -Parent
    }
    if (-not (Test-Path -LiteralPath $target)) {
        throw "Cannot locate permission target: $Path"
    }

    $isDirectory = Test-Path -LiteralPath $target -PathType Container
    if ($isDirectory) {
        & takeown.exe /F $target /A /R /D Y | Out-Null
    } else {
        & takeown.exe /F $target /A | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "takeown failed: $target" }

    if ($isDirectory) {
        & icacls.exe $target /grant "*S-1-5-32-544:(OI)(CI)F" /C | Out-Null
    } else {
        & icacls.exe $target /grant "*S-1-5-32-544:F" /C | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "icacls failed: $target" }
}

function Decode-PatchText {
    param([string]$Value)
    return $Value
}

function Count-LiteralOccurrences {
    param([string]$Text, [string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return 0 }
    return [System.Text.RegularExpressions.Regex]::Matches(
        $Text,
        [System.Text.RegularExpressions.Regex]::Escape($Value)
    ).Count
}

function Get-AssetFiles {
    param([string]$AssetsDir)
    $files = New-Object System.Collections.ArrayList
    foreach ($pattern in @("*.js", "*.css")) {
        foreach ($file in Get-ChildItem -LiteralPath $AssetsDir -Filter $pattern -File -ErrorAction SilentlyContinue) {
            [void]$files.Add($file)
        }
    }
    return @($files | Sort-Object FullName)
}

function Get-CompressedAssetPath {
    param([string]$AssetPath)
    return "$AssetPath.zst"
}

function Analyze-PatchHits {
    param($Patches, $AssetFiles)
    $fileTexts = New-Object System.Collections.ArrayList
    foreach ($file in $AssetFiles) {
        [void]$fileTexts.Add([pscustomobject]@{
            FullName = $file.FullName
            Text = Read-Utf8Text -Path $file.FullName
        })
    }

    $results = New-Object System.Collections.ArrayList
    foreach ($patch in $Patches) {
        $find = Decode-PatchText -Value (Get-Value $patch "find")
        $replace = Decode-PatchText -Value (Get-Value $patch "replace")
        $matchedFiles = New-Object System.Collections.ArrayList
        $replacedFiles = New-Object System.Collections.ArrayList
        $totalHits = 0
        $totalReplacedHits = 0

        foreach ($fileText in $fileTexts) {
            $hitCount = Count-LiteralOccurrences -Text $fileText.Text -Value $find
            $replacedCount = Count-LiteralOccurrences -Text $fileText.Text -Value $replace
            if ($hitCount -gt 0) {
                [void]$matchedFiles.Add([pscustomobject]@{ file = $fileText.FullName; count = $hitCount })
                $totalHits += $hitCount
            }
            if ($replacedCount -gt 0) {
                [void]$replacedFiles.Add([pscustomobject]@{ file = $fileText.FullName; count = $replacedCount })
                $totalReplacedHits += $replacedCount
            }
        }

        [void]$results.Add([pscustomobject]@{
            description = Get-Value $patch "description"
            kind = Get-Value $patch "kind" "runtime"
            required = [bool](Get-Value $patch "required" $false)
            find = Get-Value $patch "find"
            replace = Get-Value $patch "replace"
            matched = $totalHits -gt 0
            alreadyPatched = $totalHits -eq 0 -and $totalReplacedHits -gt 0
            totalHits = $totalHits
            totalReplacedHits = $totalReplacedHits
            files = @($matchedFiles)
            replacedFiles = @($replacedFiles)
        })
    }
    return @($results)
}

function Get-PatchTargetFiles {
    param($PatchAnalysis)
    $targets = @{}
    foreach ($result in $PatchAnalysis) {
        foreach ($fileInfo in @($result.files) + @($result.replacedFiles)) {
            if ($null -ne $fileInfo -and $fileInfo.file) {
                $targets[$fileInfo.file] = $true
            }
        }
    }
    return @($targets.Keys)
}

function Apply-PatchesToFile {
    param([string]$Path, $Patches)
    $text = Read-Utf8Text -Path $Path
    $changes = New-Object System.Collections.ArrayList
    foreach ($patch in $Patches) {
        $find = Decode-PatchText -Value (Get-Value $patch "find")
        $replace = Decode-PatchText -Value (Get-Value $patch "replace")
        if ($find -eq $replace) { continue }
        $count = Count-LiteralOccurrences -Text $text -Value $find
        if ($count -gt 0) {
            $text = $text.Replace($find, $replace)
            [void]$changes.Add([pscustomobject]@{
                description = Get-Value $patch "description"
                count = $count
            })
        }
    }
    if ($changes.Count -gt 0) {
        Write-Utf8Text -Path $Path -Content $text
    }
    return @($changes)
}

function Get-RequiredPatchIssues {
    param($PatchAnalysis)
    $issues = New-Object System.Collections.ArrayList
    foreach ($result in $PatchAnalysis) {
        if ($result.required -and -not $result.matched -and -not $result.alreadyPatched) {
            [void]$issues.Add("Required patch did not match and needs maintenance: $($result.description)")
        }
    }
    return @($issues)
}

function Test-VisibleEnglishText {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value.Length -gt 80) { return $false }
    if ($Value -notmatch '[A-Za-z]') { return $false }
    if ($Value -cmatch '^[A-Z0-9_./:-]+$') { return $false }
    if ($Value -match 'https?://') { return $false }
    if ($Value -cmatch '^[a-z][a-z0-9-]*$') { return $false }
    if ($Value -cmatch '^[A-Za-z0-9]+(Route|Icon|Content|Layout|Provider|Context|Component|Props|State|Type|Code|List|Map)$') { return $false }
    if ($Value -cmatch '^[A-Za-z]+[A-Z][A-Za-z0-9]+$' -and $Value -notmatch '\s') { return $false }
    if ($Value -in @("div", "span", "section", "article", "button", "input", "textarea", "label", "form", "main", "nav", "header", "footer", "code")) { return $false }
    return $true
}

function Test-MissingTranslationCandidate {
    param([string]$Value, [string]$Kind)
    if (-not (Test-VisibleEnglishText -Value $Value)) { return $false }
    if ($Value -match '[\u4e00-\u9fff]') { return $false }
    if ($Value -match "[\r\n]") { return $false }
    if ($Value -in @("Bash", "Twilio", "Supavisor", "PostgREST", "Claude Code", "Excel", "Chrome", "GCP", "AWS", "Amazon S3", "Google Cloud Storage", "GitHub Token", "Clustal", "Clustal2", "Taylor", "Zappo", "Cinema", "Haiku", "Opus", "Sonnet", "Claude", "React", "VS Code", "Slack", "Android", "Plant", "Microphone", "Headphones", "Cat", "Camera", "Coffee", "Word", "Operon", "Markdown", "Tailwind", "Orbit", "Conway", "Unpaywall", "Elsevier", "Springer Nature", "Semantic Scholar", "Bearer", "AWS SigV4", "Basic")) { return $false }
    if ($Value -match '^[+-]\s') { return $false }
    if ($Value -match '^\$\{') { return $false }
    if ($Value -match '^\[.+\]$') { return $false }
    if ($Value -match '^(C \d+|CHE-|org_|ghp_|my_feature_name\b|user@hostname\b|~[/\\]|e\.g\.,|owner/repo\b|arn:aws:|projects/.+/cryptoKeys|1Z \d|-----BEGIN CERTIFICATE-----|Authorization=|deployment\.environment=|MIT, Apache)') { return $false }
    if ($Value -match '^(func\.def|use_strict|web_search|[a-z]+[._][a-z0-9_.]+)$') { return $false }
    if ($Value -match '^\d+_[a-z0-9_]+$') { return $false }
    if ($Value -match '(&nbsp;|BLAT|Blat|sequence|strand|gap |gap$|mate|genotype|circular view|CNVpytor|ROI Set|TLEN|snp|phenotype|soft-clipped|reference sequence|read order|mapping quality|discordant pairs|split reads|SVs|Chr$|yytext|node\|edge|minmax\()') { return $false }
    if ($Value -match '^(\[SECURITY TEST\]|If true,|Core schema meta-schema|Meta-schema for|text:|Esc$|X-Header-Name|Absolute path|Summary$|Export decrypted|Aria label|Button label|Text showing|List the user|Token for|Fetch a specific|The ID of|Free text|Maximum number|List of calendar|Get the user|Page token|Read a specific|Read a Gmail|Include the full|Section heading|Button label showing|A plan that|Interactive greeting|Confirmation message|Message indicating|Description of|Error message|Migrate settings|Settings modal|Refactor |Port |Draft RFC|TypeError|ChatInput|Add Storybook|Epitaxy Menu|Awaiting review demo)') { return $false }
    if ($Value -match '\.(ts|tsx|js|jsx|json|md|css|html|py|ps1|sh)\b') { return $false }
    if ($Value -match '\b[a-z0-9.-]+\.(com|org|net|dev|app|ai|io|co|uk)\b') { return $false }
    if ($Value -match '^(SELECT\s|npm\s|#!/|curl\s|@keyframes|go/|localStorage\b|enrolled=|github_authenticated\b|onboarding_complete\b|stream_event\b|cache_depth\b|Lockstep cache_depth|\u26A1 cache break|read \(actual\)|write \dm|write \dh|starts_at\b|ends_at\b|trial_metadata\b|cowork_onboarding|session_stale|xcode-select\b|\.value\b)') { return $false }
    if ($Value -match '^(Waterfront to|Ferry Building|Chocolate Lava Cake|Excessive Bash|Datadog MCP|Sentry tool|/deploy skill|Headless mode|This Object indicates|Supported formats:|CLICK HERE|ADMIT ONE|cd your-project|Buttery$|Airy$|Mellow$|Glassy$|Rounded$|Cartoon$|Stick$|Sphere$|Surface$|Line$|Human \(|Mouse \(|Edit Session$|Delete Session\?|Lineage Code|Matched:|Output unsatisfied|Child completed|No matching tools|No search results|Waiting for subagents|Agent asked|Agent''s choice|User asked|User requested|Failed to load archived|Compaction Summary|Save & Submit|Agent Failed|Applying edit|Edit applied|Failed to load image|Preview|Artifact unavailable|Hidden$|Uploads$|Dependencies$|Execution Plan|Scope and limits|Use .+ keys|Plan awaiting|Approve here|For Pro|Sign in with Console|For API|Design a CRISPR|Build a phylogenetic|Analyze scRNA|Rank enzyme|Operon is downloading|Welcome to Operon|Style:|Loading molecule|Drag to rotate|Loading structure|Loading genome|Genome:|Locus:|Note: Some file formats|Empty plan file|Python$|Packages$|Package$|Version$|Operations$|Operation$|Result$|Environment Snapshot|\\fbox|\\angl)') { return $false }
    if ($Value -match '^(Mock session|Fix race|Session polling|Add retry|Branch status|Cross-repo|Wire ccr|Desktop ccr|useSessionMetadata|Update CCR|CCR proto|Remove legacy|Legacy inbox|Bump Playwright|Playwright|Add aria|Filter panel|Implement orchestrator|Wire up create|Bootstrap remote|Add retry-on|Scaffold diff|Investigate flaky|Session board|Add BOARD|BOARD_COLUMN|Rename inbox|inboxStatus|Upgrade react-query|React Query|Look into why|WEB-412|Dropdown menu|Mobile dropdown|Address review|Command palette|INFRA-88|Nightly|Weekly dependency|Fix failing|Investigate clauditor|Generate tests|Rename all|Customer report|Sync Figma|Migrate remaining|Admin class|Why does useQuery|useQuery|Coordinator$|Bump agent|agent-sdk|Split proto|head_ref|Draft PR|Awaiting review|Pushed branch|Create-PR demo)') { return $false }
    if ($Value -match '(ant-only|internal_test_account|Debug share|Force gate|Force Show|Config preset|Ignore Live Signals|Reset NUX|CLAUDE\.md|Onboarding demo|Jump to trial ended|Enroll bit|Trial lifecycle|Day-4 reminder|Dev tools gate|Reset checklist state|Item Completion)') { return $false }
    if ($Value -match '^/[A-Za-z0-9_-]+$') { return $false }
    if ($Value -match '^\.[A-Za-z0-9_-]+$') { return $false }
    if ($Value -match '^[a-z_]+=(true|false)$') { return $false }
    if ($Kind -eq "description" -and $Value -match '^(Accessible label|Accessibility label for|Button to|Tooltip for|Label for|Label indicating|Shown when|Header for|Section header|Loading state|Error state|Error toast|Success message|Warning message|Title for|Placeholder for|Message shown|Description for|A description of|Separator between|Fallback label|Fallback entry|Count of|Empty state|Extension requirements|Onboarding first-chat|Ask a quick side question|Launch a remote|Rewind the conversation|Manage MCP|Set the model|Reload plugins)') {
        return $false
    }
    if ($Kind -eq "description" -and $Value -match '^(A field where|Which .* to apply\.|Line Feed only|Carriage Return|Specify the input filepath|Insert @format|Which parser to use\.|Add a plugin\.|The line length|Number of spaces|Indent with tabs|Control how Prettier|Format embedded code|Never automatically|Print spaces|Print semicolons|Use single quotes|How to wrap prose|Wrap prose|Do not wrap prose|Put >|Enforce single|Include parentheses|Always include parens|Omit parens|Change when properties|Only add quotes|If at least one property|Respect the input use|Print trailing commas|Trailing commas|No trailing commas|How to handle whitespaces|Respect the default value of CSS|Whitespaces are considered|Indent script)') {
        return $false
    }
    if ($Kind -eq "description" -and $Value -match '^(Flow|Less|JSON\.stringify|Markdown|Vue|Ember / Handlebars|Angular|Lightning Web Components|EC cryptography)$') {
        return $false
    }
    if ($Kind -eq "description" -and $Value -match '^(Standard process shape|Represents |Terminal point|Subprocess|Database storage|Starting point|Decision-making step|Preparation or condition step|Priority action|Text block|Lined process shape|Small starting point|Stop point|Fork or join|Adds a comment|Communication link|Direct access storage|Disk storage|Divided process shape|Extraction process|Internal storage|Junction point|Loop limit step|Manual file operation|Manual input step|Multiple documents|Multiple processes|Stored data|Tagged document|Tagged process|Paper tape|Odd shape|Lined document)') {
        return $false
    }
    if ($Kind -eq "description" -and $Value -match '^(This message is meant|Chip that expands|Subtotal as opposed|Seconds in countdown|Filter to one type|uuid from|Seat tier|Optional name prefix|Display name|Optional description|The .* UUID|New display name|New description|The account UUID|The member_id|Number of timescale|Allow |Enable |Hostnames |Template preset|Restrict |Require |Admin request|Default new connector|Domains to remove|Email address|New role|Whether to assign|Type of the principal|The principal_id)') {
        return $false
    }
    if ($Kind -eq "description" -and $Value -match '^(Move cursor|Scroll editor|Reveal the given line|Go to End|Type$|char-|unchanged lines|Fold Unchanged|Source Action|Trigger a code action|Go to locations|The text document|The position|An array of locations|Human readable message|Peek locations|Paste as|Open a new In-Editor|Unfold the content|Fold the content|Job name/title|Topic name in onboarding|Placeholder text|Hint shown above|Demonstrates MCP Apps|Name to greet|Initial counter value|Interactive counter|Which module|Renders SVG|Notification title|Optional body text|Free-text search|The text to speak|Conway plugin|Internal:|Free-text query|Max chunks|Contributed a bug|Building and open sourcing|Levelsio built|Button text|Error title|Loading message|Shows built-in|Section title|Warning text|Dropdown menu|Hint for installing|Provide |The URL to|The public homepage|A clear, concise|ExtraUsageUpsellBanner|UsageCreditsCard|Polling interval|Lower DB load|Current behavior|Review migration plan|Coordinates child)') {
        return $false
    }
    return $true
}

function Get-MessageIdNearMatch {
    param([string]$Text, $TextMatch)
    $remaining = $Text.Length - $TextMatch.Index
    if ($remaining -le 0) { return $null }
    $window = $Text.Substring($TextMatch.Index, [Math]::Min(240, $remaining))
    $idMatch = [System.Text.RegularExpressions.Regex]::Match($window, 'id:"([^"]+)"')
    if (-not $idMatch.Success) { return $null }
    return [System.Text.RegularExpressions.Regex]::Unescape($idMatch.Groups[1].Value)
}

function Scan-MissingTranslations {
    param([string]$AssetsDir, [string]$OutputPath)
    $seen = @{}
    $coveredTexts = @{}
    $knownTranslations = Get-RuntimeTranslations
    $knownLocaleIds = Get-KnownLocaleMessageIds
    $items = New-Object System.Collections.ArrayList
    $patterns = @(
        @{ kind = "defaultMessage"; regex = 'defaultMessage:"([^"]+)"' },
        @{ kind = "aria-label"; regex = 'aria-label:"([^"]+)"' },
        @{ kind = "label"; regex = 'label:"([^"]+)"' },
        @{ kind = "title"; regex = 'title:"([^"]+)"' },
        @{ kind = "cowork"; regex = 'cowork:"([^"]+)"' },
        @{ kind = "placeholder"; regex = 'placeholder:"([^"]+)"' },
        @{ kind = "group"; regex = 'group:"([^"]+)"' },
        @{ kind = "banner"; regex = 'banner:"([^"]+)"' },
        @{ kind = "body"; regex = 'body:"([^"]+)"' },
        @{ kind = "description"; regex = 'description:"([^"]+)"' },
        @{ kind = "description"; regex = "description:'((?:\\'|[^'])*)'" },
        @{ kind = "hint"; regex = 'hint:"([^"]+)"' },
        @{ kind = "children"; regex = 'children:"([^"]+)"' },
        @{ kind = "recents"; regex = 'recents:"([^"]+)"' },
        @{ kind = "shared"; regex = 'shared:"([^"]+)"' }
    )

    foreach ($file in (Get-AssetFiles -AssetsDir $AssetsDir)) {
        $text = Read-Utf8Text -Path $file.FullName
        foreach ($pattern in $patterns) {
            foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($text, $pattern.regex)) {
                $value = [System.Text.RegularExpressions.Regex]::Unescape($match.Groups[1].Value)
                if (-not (Test-MissingTranslationCandidate -Value $value -Kind $pattern.kind)) { continue }
                if ((Get-Value -Object $knownTranslations -Key $value -Default $null)) {
                    $coveredTexts[$value] = $true
                    continue
                }
                $messageId = Get-MessageIdNearMatch -Text $text -TextMatch $match
                if ($messageId -and $knownLocaleIds.ContainsKey($messageId)) {
                    $coveredTexts[$value] = $true
                    continue
                }
                $key = $value
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                [void]$items.Add([ordered]@{
                    text = $value
                    translation = ""
                    kind = $pattern.kind
                    file = $file.FullName
                })
            }
        }
    }

    Write-JsonFile -Path $OutputPath -Value @($items)
    return @($items)
}

function Get-VerificationIssues {
    param($Config, $Install = $null)
    if ($null -eq $Install) {
        $Install = Resolve-ClaudeInstall -Config $Config
    }
    $artifacts = Get-ProjectArtifacts
    Assert-ProjectArtifacts -Artifacts $artifacts
    $issues = New-Object System.Collections.ArrayList

    $assetFiles = Get-AssetFiles -AssetsDir $Install.AssetsDir
    $patchAnalysis = Analyze-PatchHits -Patches (Get-RequiredPatches) -AssetFiles $assetFiles
    foreach ($issue in Get-RequiredPatchIssues -PatchAnalysis $patchAnalysis) {
        [void]$issues.Add($issue)
    }
    return @($issues)
}
