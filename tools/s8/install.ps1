[CmdletBinding()]
param([switch]$NoAdmx,[ValidateSet('stable','preview','nightly')][string]$Channel='stable')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if($PSVersionTable.PSVersion.Major -lt 5){throw 'PowerShell 5.1 or PowerShell 7+ is required.'}
if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
if($PSVersionTable.PSVersion.Major -eq 5){[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}
$id=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($id)
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  $exe=if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'}
  $tmp=Join-Path $env:TEMP ('s8-bootstrap-'+[guid]::NewGuid().ToString('N')+'.ps1')
  $MyInvocation.MyCommand.ScriptBlock.ToString()|Set-Content $tmp -Encoding UTF8
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$tmp+'"'),'-Channel',$Channel);if($NoAdmx){$args+='-NoAdmx'}
  Start-Process $exe -Verb RunAs -ArgumentList ($args -join ' ') -Wait;exit
}
$bin=Join-Path $env:ProgramFiles 'System8\bin'
New-Item -ItemType Directory -Path $bin -Force|Out-Null
$cliUrl='https://raw.githubusercontent.com/enkayz/system8/main/tools/s8/s8.ps1'
$cli=Join-Path $bin 's8.ps1'
Invoke-WebRequest -UseBasicParsing -Uri $cliUrl -OutFile $cli
$cmd=Join-Path $bin 's8.cmd'
@'
@echo off
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0s8.ps1" %*
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0s8.ps1" %*
)
'@|Set-Content $cmd -Encoding ASCII
$machine=[Environment]::GetEnvironmentVariable('Path','Machine')
if(($machine -split ';') -notcontains $bin){[Environment]::SetEnvironmentVariable('Path',(($machine.TrimEnd(';')+';'+$bin)),'Machine')}
$env:Path="$env:Path;$bin"
Write-Host "Installed System 8 Package Manager to $bin" -ForegroundColor Green
Write-Host 'Command available: s8' -ForegroundColor Green
if(-not $NoAdmx){& $cli install admx -Channel $Channel}
