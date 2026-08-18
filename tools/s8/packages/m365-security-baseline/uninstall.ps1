[CmdletBinding()]param([Parameter(Mandatory)][string]$PackageRoot,[string]$BinPath=(Join-Path $env:ProgramFiles 'System8\bin'))
Remove-Item (Join-Path $BinPath 's8baseline.cmd') -Force -ErrorAction SilentlyContinue;Remove-Item (Join-Path $PackageRoot 'm365-security-baseline') -Recurse -Force -ErrorAction SilentlyContinue
