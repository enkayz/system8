[CmdletBinding()]param([Parameter(Mandatory)][string]$PackageRoot,[string]$BinPath=(Join-Path $env:ProgramFiles 'System8\bin'))
Remove-Item (Join-Path $BinPath 's8diff.cmd') -Force -ErrorAction SilentlyContinue;Remove-Item (Join-Path $PackageRoot 'm365-tenant-diff') -Recurse -Force -ErrorAction SilentlyContinue
