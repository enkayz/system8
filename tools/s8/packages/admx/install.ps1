[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageDir=Join-Path $PackageRoot 'admx'
New-Item -ItemType Directory -Path $packageDir -Force|Out-Null
$installer='https://raw.githubusercontent.com/enkayz/system8/120a14e61a86a693545f1709e35cafd483b2e175/tools/admx-manager/install.ps1'
$installerSha256='5d41da8dace23cdc0e7bbf26b044cd47859e0647a418f8a2cb1d13bdb9b3ec47'
$temp=Join-Path $env:TEMP ('s8-admx-install-'+[guid]::NewGuid().ToString('N')+'.ps1')
Invoke-WebRequest -UseBasicParsing -Uri $installer -OutFile $temp
$actual=(Get-FileHash $temp -Algorithm SHA256).Hash.ToLowerInvariant()
if($actual -ne $installerSha256){Remove-Item $temp -Force;throw 'ADMX installer SHA256 mismatch; installation stopped.'}
& $temp -NoLaunch
Copy-Item $PSCommandPath (Join-Path $packageDir 'install.ps1') -Force
$uninstallSource=Join-Path $PSScriptRoot 'uninstall.ps1'
if(Test-Path $uninstallSource){Copy-Item $uninstallSource (Join-Path $packageDir 'uninstall.ps1') -Force}
[pscustomobject]@{name='admx';version='1.1.0';installed=(Get-Date -Format o);appPath="$env:ProgramFiles\System8 ADMX Manager"}|ConvertTo-Json|Set-Content (Join-Path $packageDir 'package.json') -Encoding UTF8
Remove-Item $temp -Force -ErrorAction SilentlyContinue
