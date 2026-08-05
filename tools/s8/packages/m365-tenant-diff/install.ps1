[CmdletBinding()]param([Parameter(Mandatory)][string]$PackageRoot,[string]$BinPath=(Join-Path $env:ProgramFiles 'System8\bin'))
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$source=Split-Path $PSCommandPath;$dest=Join-Path $PackageRoot 'm365-tenant-diff';New-Item -ItemType Directory -Path $dest,$BinPath -Force|Out-Null
Copy-Item (Join-Path $source '*') $dest -Recurse -Force
Copy-Item (Join-Path (Split-Path $source) '_shared\S8.M365.psm1') (Join-Path $dest 'S8.M365.psm1') -Force
$launcher=Join-Path $BinPath 's8diff.cmd';"@echo off`r`nwhere pwsh.exe >nul 2>&1`r`nif %errorlevel%==0 (pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"%ProgramData%\System8\Packages\m365-tenant-diff\tenant-diff.ps1`" %*) else (powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%ProgramData%\System8\Packages\m365-tenant-diff\tenant-diff.ps1`" %*)"|Set-Content $launcher -Encoding ASCII
Write-Host 'Installed command: s8diff' -ForegroundColor Green
