[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'PowerShell 5.1 or later is required.' }
if ($PSVersionTable.PSVersion.Major -eq 5) { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 }

$destinationPath = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $destinationPath) { throw "Toolchain destination already exists: $destinationPath" }

$lockPath = Join-Path $PSScriptRoot 'toolchain.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
$temporaryDirectory = Join-Path $env:TEMP ('system8-toolchain-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryDirectory,$destinationPath | Out-Null

function Get-VerifiedArchive {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Sha256,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $archivePath = Join-Path $temporaryDirectory $Name
    Invoke-WebRequest -UseBasicParsing $Url -OutFile $archivePath
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $Sha256) { throw "Hash verification failed for $Name." }
    Unblock-File -LiteralPath $archivePath -ErrorAction SilentlyContinue
    $archivePath
}

try {
    $powerShellArchive = Get-VerifiedArchive -Url $lock.powerShell.url -Sha256 $lock.powerShell.sha256 -Name 'powershell.zip'
    $powerShellPath = Join-Path $destinationPath 'PowerShell'
    Expand-Archive -LiteralPath $powerShellArchive -DestinationPath $powerShellPath -Force
    if (-not (Test-Path -LiteralPath (Join-Path $powerShellPath 'pwsh.exe'))) { throw 'The portable PowerShell archive is incomplete.' }

    $moduleRoot = Join-Path $destinationPath 'Modules'
    foreach ($module in $lock.modules) {
        $packagePath = Get-VerifiedArchive -Url $module.url -Sha256 $module.sha256 -Name ($module.name + '.nupkg')
        $zipPath = "$packagePath.zip"
        Copy-Item -LiteralPath $packagePath -Destination $zipPath
        $modulePath = Join-Path (Join-Path $moduleRoot $module.name) $module.version
        New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
        Expand-Archive -LiteralPath $zipPath -DestinationPath $modulePath -Force
        if (-not (Test-Path -LiteralPath (Join-Path $modulePath ($module.name + '.psd1')))) { throw "Module manifest is missing for $($module.name)." }
    }

    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'invoke-isolated.ps1') -Destination (Join-Path $destinationPath 'invoke-isolated.ps1')

    [ordered]@{
        schemaVersion = 1
        createdAt = [DateTimeOffset]::Now.ToString('o')
        powerShellVersion = $lock.powerShell.version
        moduleVersions = [ordered]@{}
        sourceLock = 'toolchain.lock.json'
    } | ForEach-Object {
        foreach ($module in $lock.modules) { $_.moduleVersions[$module.name] = $module.version }
        $_
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $destinationPath 'manifest.json') -Encoding UTF8

    Write-Host "Built isolated System 8 toolchain at $destinationPath" -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
