[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'list', 'doctor')]
    [string]$Command = 'install',

    [Parameter(Position = 1)]
    [string]$Package,

    [ValidateSet('stable')]
    [string]$Channel = 'stable',

    [string]$BundleRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'PowerShell 5.1 or later is required.' }

$root = Join-Path $env:LOCALAPPDATA 'System8\Packages'
$bin = Join-Path $env:LOCALAPPDATA 'System8\bin'
$toolchain = Join-Path $env:LOCALAPPDATA 'System8\Toolchain'
$pwsh = Join-Path $toolchain 'PowerShell\pwsh.exe'
$modules = Join-Path $toolchain 'Modules'
$state = Join-Path $root 'user-state.json'
if (-not $BundleRoot) { $BundleRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'Packages' }
$BundleRoot = [IO.Path]::GetFullPath($BundleRoot)
New-Item -ItemType Directory -Path $root,$bin -Force | Out-Null

$commands = @{
    'm365' = 's8m365'
    'm365-governance' = 's8gov'
    'm365-license-optimizer' = 's8license'
    'm365-tenant-diff' = 's8tenantdiff'
    'm365-sharepoint-modernizer' = 's8spmodern'
    'm365-security-baseline' = 's8secure'
    'm365-migration-estimator' = 's8migrate'
    'm365-entitlement-advisor' = 's8entitlement'
    'm365-change-impact' = 's8changes'
    'm365-copilot-readiness' = 's8copilot'
    'm365-access-explainer' = 's8access'
    'm365-leaver-readiness' = 's8leaver'
    'm365-recovery-readiness' = 's8resilience'
}

if ($Command -eq 'doctor') {
    $manifestPath = Join-Path $BundleRoot "$Channel.json"
    [pscustomobject]@{
        BootstrapPowerShell = $PSVersionTable.PSVersion.ToString()
        ToolchainReady = [bool]((Test-Path $pwsh) -and (Test-Path (Join-Path $modules 'Microsoft.Graph.Authentication\2.38.1\Microsoft.Graph.Authentication.psd1')))
        PackageBundleReady = [bool](Test-Path $manifestPath)
        IsolatedPowerShell = $pwsh
        IsolatedModuleRoot = $modules
        PackageBundleRoot = $BundleRoot
        UserRoot = $root
        Bin = $bin
        BinOnUserPath = [bool](([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') -contains $bin)
    } | Format-List
    exit
}

if ($Command -eq 'list') {
    Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object Name -NotLike '.*' | Select-Object Name,LastWriteTime | Format-Table
    exit
}

if (-not $Package -or -not $commands.ContainsKey($Package)) { throw "Unknown or missing package: $Package" }
if (-not (Test-Path $pwsh -PathType Leaf)) { throw 'The isolated System 8 toolchain is missing. Install or repair the System 8 Dashboard first.' }

$manifestPath = Join-Path $BundleRoot "$Channel.json"
if (-not (Test-Path $manifestPath -PathType Leaf)) { throw "The signed System 8 package manifest is missing: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$definition = @($manifest.packages | Where-Object { $_.name -eq $Package }) | Select-Object -First 1
if (-not $definition) { throw "Package not found in $Channel manifest: $Package" }
if (-not $definition.sha256 -or $definition.sha256 -eq 'development') { throw "Package $Package does not have a release checksum." }

$bundleName = [IO.Path]::GetFileName(([Uri]$definition.url).AbsolutePath)
$bundlePath = Join-Path $BundleRoot $bundleName
if (-not (Test-Path $bundlePath -PathType Leaf)) { throw "The verified System 8 package bundle is missing: $bundlePath" }
$actualHash = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash
if ($actualHash -ne $definition.sha256) { throw "SHA256 mismatch for $Package. The local package bundle was not executed." }

$temporaryDirectory = Join-Path $env:TEMP ('s8-user-' + [guid]::NewGuid().ToString('N'))
$expanded = Join-Path $temporaryDirectory 'expanded'
$staging = Join-Path $root ('.staging-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $root ('.backup-' + [guid]::NewGuid().ToString('N'))
$destination = Join-Path $root $Package
New-Item -ItemType Directory -Path $temporaryDirectory,$staging | Out-Null
try {
    Expand-Archive -LiteralPath $bundlePath -DestinationPath $expanded -Force
    $installer = Join-Path $expanded $definition.installScript
    if (-not (Test-Path $installer -PathType Leaf)) { throw "Package entry is missing from the verified bundle: $($definition.installScript)" }
    $source = Split-Path $installer -Parent
    Copy-Item (Join-Path $source '*') $staging -Recurse -Force

    $shared = Join-Path $expanded 'system8-main\tools\s8\packages\_shared\S8.M365.psm1'
    if (Test-Path $shared -PathType Leaf) { Copy-Item -LiteralPath $shared -Destination $staging -Force }
    $entry = Get-ChildItem $staging -Filter *.ps1 | Where-Object { $_.Name -notin @('install.ps1', 'uninstall.ps1') } | Select-Object -First 1
    if (-not $entry) { throw 'Package entry script was not found in the verified bundle.' }
    $entryName = $entry.Name

    try {
        if (Test-Path $destination) { Move-Item -LiteralPath $destination -Destination $backup }
        Move-Item -LiteralPath $staging -Destination $destination

        $installedEntry = Join-Path $destination $entryName
        $commandPath = Join-Path $bin ($commands[$Package] + '.cmd')
        $wrapper = Join-Path $toolchain 'invoke-isolated.ps1'
        "@echo off`r`nset `"S8_TARGET_SCRIPT=$installedEntry`"`r`n`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$wrapper`" %*" | Set-Content $commandPath -Encoding ASCII

        $userPath = [string][Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not (($userPath -split ';') -contains $bin)) {
            [Environment]::SetEnvironmentVariable('Path', (($userPath.TrimEnd(';') + ';' + $bin).Trim(';')), 'User')
        }

        [pscustomobject]@{
            Package = $Package
            Version = $definition.version
            InstalledFor = $env:USERNAME
            Root = $destination
            Command = $commands[$Package]
            BundleSha256 = $actualHash
            AdministratorRequired = $false
        } | ConvertTo-Json | Set-Content $state -Encoding UTF8
    }
    catch {
        if (Test-Path $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
        if (Test-Path $backup) { Move-Item -LiteralPath $backup -Destination $destination }
        throw
    }

    if (Test-Path $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    Write-Host "Installed $Package $($definition.version) for $env:USERNAME from verified bundle $actualHash. Command: $($commands[$Package])" -ForegroundColor Green
}
finally {
    if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $temporaryDirectory) { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue }
}
