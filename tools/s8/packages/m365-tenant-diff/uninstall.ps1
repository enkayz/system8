[CmdletBinding()]param([Parameter(Mandatory)][string]$PackageRoot)
Remove-Item (Join-Path $env:ProgramFiles 'System8\bin\s8tenantdiff.cmd') -Force -ErrorAction SilentlyContinue;Remove-Item (Join-Path $PackageRoot 'm365-tenant-diff') -Recurse -Force -ErrorAction SilentlyContinue
