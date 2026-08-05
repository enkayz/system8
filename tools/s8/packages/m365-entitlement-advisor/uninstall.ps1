[CmdletBinding()]param([Parameter(Mandatory)][string]$PackageRoot)
Remove-Item (Join-Path $env:ProgramFiles 'System8\bin\s8entitlement.cmd') -Force -ErrorAction SilentlyContinue;Remove-Item (Join-Path $PackageRoot 'm365-entitlement-advisor') -Recurse -Force -ErrorAction SilentlyContinue
