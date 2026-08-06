[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactDirectory,

    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '1.0.0',

    [switch]$Published
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Assert-FileHash {
    param([string]$Path, [string]$ExpectedHash)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Release artifact is missing: $Path" }
    $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actualHash -ne $ExpectedHash) { throw "SHA256 mismatch for $Path. Expected $ExpectedHash, found $actualHash." }
}

$artifactRoot = [IO.Path]::GetFullPath($ArtifactDirectory)
$manifestPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\manifests\stable.json'))
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$dashboardDefinition = @($manifest.packages | Where-Object name -eq 'dashboard') | Select-Object -First 1
$operatorDefinitions = @($manifest.packages | Where-Object name -ne 'dashboard')
if (-not $dashboardDefinition -or -not $operatorDefinitions) { throw 'The stable manifest is missing dashboard or operator package definitions.' }
if (@($manifest.packages | Where-Object { -not $_.sha256 -or $_.sha256 -eq 'development' }).Count -ne 0) { throw 'Stable packages must use release SHA-256 values.' }

$operatorUrls = @($operatorDefinitions.url | Select-Object -Unique)
$operatorHashes = @($operatorDefinitions.sha256 | Select-Object -Unique)
if ($operatorUrls.Count -ne 1 -or $operatorHashes.Count -ne 1) { throw 'Operator packages must resolve to one immutable, checksum-locked bundle.' }
$operatorBundle = Join-Path $artifactRoot ([IO.Path]::GetFileName(([Uri]$operatorUrls[0]).AbsolutePath))
Assert-FileHash $operatorBundle $operatorHashes[0]

$installerBundle = Join-Path $artifactRoot ([IO.Path]::GetFileName(([Uri]$dashboardDefinition.url).AbsolutePath))
Assert-FileHash $installerBundle $dashboardDefinition.sha256

$dashboardArchive = Join-Path $artifactRoot "System8Dashboard-$Version-win-x64.zip"
$dashboardChecksum = "$dashboardArchive.sha256"
if (-not (Test-Path -LiteralPath $dashboardChecksum -PathType Leaf)) { throw "Dashboard checksum is missing: $dashboardChecksum" }
$expectedDashboardHash = ((Get-Content -LiteralPath $dashboardChecksum -Raw).Trim() -split '\s+')[0]
Assert-FileHash $dashboardArchive $expectedDashboardHash

$temporaryDirectory = Join-Path $env:TEMP ('system8-release-verification-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
try {
    $operatorExtract = Join-Path $temporaryDirectory 'operator'
    Expand-Archive -LiteralPath $operatorBundle -DestinationPath $operatorExtract -Force
    foreach ($definition in $operatorDefinitions) {
        $entry = Join-Path $operatorExtract $definition.installScript
        if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw "Verified bundle is missing $($definition.installScript)." }
    }

    $installerExtract = Join-Path $temporaryDirectory 'installer'
    Expand-Archive -LiteralPath $installerBundle -DestinationPath $installerExtract -Force
    $installerPath = Join-Path $installerExtract $dashboardDefinition.installScript
    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) { throw 'Dashboard package-manager installer entry is missing.' }
    $installerCommand = Get-Command $installerPath
    if (-not $installerCommand.Parameters.ContainsKey('PackageRoot')) { throw 'Dashboard installer does not accept the package manager -PackageRoot contract.' }
    $installerSource = Get-Content -LiteralPath $installerPath -Raw
    if (-not $installerSource.Contains($expectedDashboardHash)) { throw 'Dashboard installer does not embed the trusted dashboard archive checksum.' }
    & $installerPath -PackageRoot (Join-Path $temporaryDirectory 'package-manager-root') -SourceDirectory $artifactRoot -NoLaunch -WhatIf

    $dashboardExtract = Join-Path $temporaryDirectory 'dashboard'
    Expand-Archive -LiteralPath $dashboardArchive -DestinationPath $dashboardExtract -Force
    $requiredFiles = @(
        'System8Dashboard.exe',
        'System8Dashboard.pri',
        'Toolchain\PowerShell\pwsh.exe',
        'Toolchain\invoke-isolated.ps1',
        'Toolchain\Modules\Microsoft.Graph.Authentication\2.38.1\Microsoft.Graph.Authentication.psd1',
        'Packages\stable.json',
        "Packages\$([IO.Path]::GetFileName($operatorBundle))"
    )
    foreach ($relativePath in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $dashboardExtract $relativePath) -PathType Leaf)) { throw "Dashboard archive is missing $relativePath." }
    }

    $bundledManifest = Get-Content -LiteralPath (Join-Path $dashboardExtract 'Packages\stable.json') -Raw | ConvertFrom-Json
    $bundledHash = @($bundledManifest.packages | Where-Object name -ne 'dashboard' | Select-Object -ExpandProperty sha256 -Unique)
    if ($bundledHash.Count -ne 1 -or $bundledHash[0] -ne $operatorHashes[0]) { throw 'Dashboard package manifest does not match the verified operator bundle.' }
}
finally {
    $resolvedTemporaryDirectory = [IO.Path]::GetFullPath($temporaryDirectory)
    $resolvedTempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if ($resolvedTemporaryDirectory.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Published) {
    $urls = @($dashboardDefinition.url, $operatorUrls[0], "https://github.com/enkayz/system8/releases/download/dashboard-v$Version/System8Dashboard-$Version-win-x64.zip")
    foreach ($url in $urls) {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $url -Method Head
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) { throw "Published artifact is unavailable: $url" }
    }
}

[pscustomobject]@{
    DashboardArchive = $dashboardArchive
    DashboardSha256 = $expectedDashboardHash
    OperatorBundle = $operatorBundle
    OperatorSha256 = $operatorHashes[0]
    PackageManagerInstaller = $installerBundle
    PackageManagerSha256 = $dashboardDefinition.sha256
    Published = [bool]$Published
    Result = 'PASS'
} | Format-List
