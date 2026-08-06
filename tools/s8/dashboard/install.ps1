[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '1.0.0',
    [switch]$Uninstall,
    [switch]$RemoveCertificate,
    [switch]$RemoveToolchain,
    [string]$PackageRoot,
    [string]$SourceDirectory,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'PowerShell 5.1 or later is required.' }
if ($PSVersionTable.PSVersion.Major -eq 5) { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 }
if (-not [Environment]::Is64BitOperatingSystem) { throw 'System 8 Dashboard requires 64-bit Windows.' }

$certificateThumbprint = 'BCA699084A9DD2B3F3B5D39FB1A57C2F95EA9053'
$releaseBase = "https://github.com/enkayz/system8/releases/download/dashboard-v$Version"
$packageFile = "System8Dashboard-$Version-win-x64.zip"
$releaseHashes = @{
    '1.0.0' = '2ED693E38B95F5A2F511B466B3A0B65A518AD83C6B7CB45BE9569BD2077003B8'
}
if (-not $releaseHashes.ContainsKey($Version)) { throw "No trusted dashboard checksum is embedded for version $Version." }
$trustedPackageHash = $releaseHashes[$Version]
$installRoot = Join-Path $env:LOCALAPPDATA 'System8\dashboard'
$toolchainRoot = Join-Path $env:LOCALAPPDATA 'System8\Toolchain'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'System 8 Dashboard.lnk'
$expectedInstallRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'System8\dashboard')).TrimEnd('\')
$expectedToolchainRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'System8\Toolchain')).TrimEnd('\')
if ([IO.Path]::GetFullPath($installRoot).TrimEnd('\') -ne $expectedInstallRoot) { throw 'The dashboard install path is outside the current user profile.' }
if ([IO.Path]::GetFullPath($toolchainRoot).TrimEnd('\') -ne $expectedToolchainRoot) { throw 'The toolchain install path is outside the current user profile.' }
$resolvedPackageRoot = if ($PackageRoot) { [IO.Path]::GetFullPath($PackageRoot) } else { $null }

if ($Uninstall) {
    if ((Test-Path -LiteralPath $installRoot) -and $PSCmdlet.ShouldProcess($installRoot, 'Remove System 8 Dashboard from the current user profile')) {
        Remove-Item -LiteralPath $installRoot -Recurse -Force
    }
    if ((Test-Path -LiteralPath $shortcutPath) -and $PSCmdlet.ShouldProcess($shortcutPath, 'Remove System 8 Dashboard shortcut')) {
        Remove-Item -LiteralPath $shortcutPath -Force
        Write-Host 'System 8 Dashboard was removed from this Windows profile.' -ForegroundColor Green
    }
    if ($RemoveToolchain -and (Test-Path -LiteralPath $toolchainRoot) -and $PSCmdlet.ShouldProcess($toolchainRoot, 'Remove the isolated System 8 PowerShell toolchain')) {
        Remove-Item -LiteralPath $toolchainRoot -Recurse -Force
    }

    if ($RemoveCertificate) {
        $certificates = @(Get-ChildItem Cert:\CurrentUser\Root, Cert:\CurrentUser\TrustedPeople | Where-Object Thumbprint -eq $certificateThumbprint)
        if ($certificates -and $PSCmdlet.ShouldProcess($certificateThumbprint, 'Remove System 8 package certificate from current-user trust stores')) {
            $certificates | Remove-Item
        }
    }
    return
}

if (-not $PSCmdlet.ShouldProcess('System 8 Dashboard for the current user', "Download, verify and install version $Version")) { return }

$temporaryDirectory = Join-Path $env:TEMP ('system8-dashboard-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
try {
    $packagePath = Join-Path $temporaryDirectory $packageFile
    $hashPath = "$packagePath.sha256"
    $extractPath = Join-Path $temporaryDirectory 'extract'
    if ($SourceDirectory) {
        $sourceRoot = [IO.Path]::GetFullPath($SourceDirectory)
        Copy-Item -LiteralPath (Join-Path $sourceRoot $packageFile) -Destination $packagePath
        Copy-Item -LiteralPath (Join-Path $sourceRoot "$packageFile.sha256") -Destination $hashPath
    }
    else {
        Invoke-WebRequest -UseBasicParsing "$releaseBase/$packageFile" -OutFile $packagePath
        Invoke-WebRequest -UseBasicParsing "$releaseBase/$packageFile.sha256" -OutFile $hashPath
    }

    $expectedHash = ((Get-Content $hashPath -Raw).Trim() -split '\s+')[0]
    if ($expectedHash -ne $trustedPackageHash) { throw 'The published dashboard checksum does not match the checksum embedded in this installer.' }
    $actualHash = (Get-FileHash $packagePath -Algorithm SHA256).Hash
    if ($actualHash -ne $trustedPackageHash) { throw 'The dashboard package hash does not match the checksum embedded in this installer.' }

    Expand-Archive -LiteralPath $packagePath -DestinationPath $extractPath -Force
    $executable = Join-Path $extractPath 'System8Dashboard.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'The dashboard archive does not contain System8Dashboard.exe at its root.' }
    $bundledPowerShell = Join-Path $extractPath 'Toolchain\PowerShell\pwsh.exe'
    $bundledGraph = Join-Path $extractPath 'Toolchain\Modules\Microsoft.Graph.Authentication\2.38.1\Microsoft.Graph.Authentication.psd1'
    if (-not (Test-Path -LiteralPath $bundledPowerShell -PathType Leaf) -or -not (Test-Path -LiteralPath $bundledGraph -PathType Leaf)) {
        throw 'The dashboard archive does not contain the complete isolated System 8 toolchain.'
    }

    $system8Root = Split-Path $installRoot -Parent
    New-Item -ItemType Directory -Path $system8Root,$installRoot -Force | Out-Null
    $transactionId = [guid]::NewGuid().ToString('N')
    $stagingPath = Join-Path $system8Root ('.dashboard-staging-' + $transactionId)
    $appBackup = Join-Path $system8Root ('.dashboard-backup-' + $transactionId)
    $toolchainBackup = Join-Path $system8Root ('.toolchain-backup-' + $transactionId)
    Move-Item -LiteralPath $extractPath -Destination $stagingPath

    $stagedPowerShell = Join-Path $stagingPath 'Toolchain\PowerShell\pwsh.exe'
    $stagedGraph = Join-Path $stagingPath 'Toolchain\Modules\Microsoft.Graph.Authentication\2.38.1\Microsoft.Graph.Authentication.psd1'
    if (-not (Test-Path -LiteralPath $stagedPowerShell -PathType Leaf) -or -not (Test-Path -LiteralPath $stagedGraph -PathType Leaf)) {
        throw 'The staged dashboard is missing its isolated PowerShell or Microsoft Graph dependency.'
    }
    $stagedPowerShellVersion = & $stagedPowerShell -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
    if ($LASTEXITCODE -ne 0 -or $stagedPowerShellVersion -ne '7.6.4') { throw 'The staged System 8 PowerShell runtime did not pass validation.' }

    $installPath = Join-Path $installRoot $Version
    try {
        if (Test-Path -LiteralPath $installPath) { Move-Item -LiteralPath $installPath -Destination $appBackup }
        if (Test-Path -LiteralPath $toolchainRoot) { Move-Item -LiteralPath $toolchainRoot -Destination $toolchainBackup }
        Move-Item -LiteralPath $stagingPath -Destination $installPath
        Move-Item -LiteralPath (Join-Path $installPath 'Toolchain') -Destination $toolchainRoot

        $installedExecutable = Join-Path $installPath 'System8Dashboard.exe'
        $installedPowerShell = Join-Path $toolchainRoot 'PowerShell\pwsh.exe'
        $installedModuleRoot = Join-Path $toolchainRoot 'Modules'
        $isolatedModulePath = "$installedModuleRoot;$toolchainRoot\PowerShell\Modules"
        $toolchainVersion = & $installedPowerShell -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
        if ($LASTEXITCODE -ne 0 -or $toolchainVersion -ne '7.6.4') { throw 'The installed System 8 PowerShell runtime did not pass validation.' }

        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $installedExecutable
        $shortcut.WorkingDirectory = $installPath
        $shortcut.IconLocation = "$installedExecutable,0"
        $shortcut.Description = 'System 8 Microsoft 365 operator dashboard'
        $shortcut.Save()

        [ordered]@{
            version = $Version
            installedAt = [DateTimeOffset]::Now.ToString('o')
            executable = $installedExecutable
            sha256 = $actualHash
            powerShell = $toolchainVersion
            modulePath = $isolatedModulePath
            packageManagerRoot = $resolvedPackageRoot
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $installRoot 'install.json') -Encoding UTF8
    }
    catch {
        if (Test-Path -LiteralPath $installPath) { Remove-Item -LiteralPath $installPath -Recurse -Force }
        if (Test-Path -LiteralPath $toolchainRoot) { Remove-Item -LiteralPath $toolchainRoot -Recurse -Force }
        if (Test-Path -LiteralPath $appBackup) { Move-Item -LiteralPath $appBackup -Destination $installPath }
        if (Test-Path -LiteralPath $toolchainBackup) { Move-Item -LiteralPath $toolchainBackup -Destination $toolchainRoot }
        throw
    }

    if (Test-Path -LiteralPath $appBackup) { Remove-Item -LiteralPath $appBackup -Recurse -Force }
    if (Test-Path -LiteralPath $toolchainBackup) { Remove-Item -LiteralPath $toolchainBackup -Recurse -Force }

    Write-Host "Installed System 8 Dashboard $Version for $env:USERNAME without administrator rights." -ForegroundColor Green
    if (-not $NoLaunch) { Start-Process -FilePath $installedExecutable }
}
finally {
    Remove-Item $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
