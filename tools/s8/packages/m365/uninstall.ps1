[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot)
Remove-Item (Join-Path $env:ProgramFiles 'System8\bin\s8m365.cmd') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $PackageRoot 'm365') -Recurse -Force -ErrorAction SilentlyContinue
