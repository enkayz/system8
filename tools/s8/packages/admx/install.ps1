[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageDir=Join-Path $PackageRoot 'admx'
New-Item -ItemType Directory -Path $packageDir -Force|Out-Null
$installer='https://raw.githubusercontent.com/enkayz/system8/main/tools/admx-manager/install.ps1'
$temp=Join-Path $env:TEMP ('s8-admx-install-'+[guid]::NewGuid().ToString('N')+'.ps1')
Invoke-WebRequest -UseBasicParsing -Uri $installer -OutFile $temp
& $temp -NoLaunch
Copy-Item $PSCommandPath (Join-Path $packageDir 'install.ps1') -Force
$uninstallSource=Join-Path $PSScriptRoot 'uninstall.ps1'
if(Test-Path $uninstallSource){Copy-Item $uninstallSource (Join-Path $packageDir 'uninstall.ps1') -Force}
[pscustomobject]@{name='admx';version='1.1.0';installed=(Get-Date -Format o);appPath="$env:ProgramFiles\System8 ADMX Manager"}|ConvertTo-Json|Set-Content (Join-Path $packageDir 'package.json') -Encoding UTF8
Remove-Item $temp -Force -ErrorAction SilentlyContinue
