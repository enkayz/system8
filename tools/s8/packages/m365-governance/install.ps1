[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$source=Split-Path $PSCommandPath
$dest=Join-Path $PackageRoot 'm365-governance'
$bin=Join-Path $env:ProgramFiles 'System8\bin'
New-Item -ItemType Directory -Path $dest,$bin -Force|Out-Null
Copy-Item (Join-Path $source 'governance.ps1') (Join-Path $dest 'governance.ps1') -Force
Copy-Item (Join-Path $source 'README.md') (Join-Path $dest 'README.md') -Force
Copy-Item (Join-Path $source 'uninstall.ps1') (Join-Path $dest 'uninstall.ps1') -Force
$cmd=Join-Path $bin 's8gov.cmd'
@'
@echo off
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%ProgramData%\System8\Packages\m365-governance\governance.ps1" %*
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ProgramData%\System8\Packages\m365-governance\governance.ps1" %*
)
'@|Set-Content $cmd -Encoding ASCII
Write-Host 'Installed command: s8gov' -ForegroundColor Green
