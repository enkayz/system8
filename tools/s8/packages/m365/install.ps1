[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$source=Split-Path $PSCommandPath
$dest=Join-Path $PackageRoot 'm365'
$bin=Join-Path $env:ProgramFiles 'System8\bin'
New-Item -ItemType Directory -Path $dest,$bin -Force|Out-Null
Copy-Item (Join-Path $source 'm365.ps1') (Join-Path $dest 'm365.ps1') -Force
Copy-Item (Join-Path $source 'README.md') (Join-Path $dest 'README.md') -Force
Copy-Item (Join-Path $source 'uninstall.ps1') (Join-Path $dest 'uninstall.ps1') -Force
$cmd=Join-Path $bin 's8m365.cmd'
@'
@echo off
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%ProgramData%\System8\Packages\m365\m365.ps1" %*
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ProgramData%\System8\Packages\m365\m365.ps1" %*
)
'@|Set-Content $cmd -Encoding ASCII
Write-Host 'Installed command: s8m365' -ForegroundColor Green
