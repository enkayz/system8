[CmdletBinding()]param([Parameter(Mandatory)][string]$PackageRoot)
Remove-Item (Join-Path $env:ProgramFiles 'System8\bin\s8spmodern.cmd') -Force -ErrorAction SilentlyContinue;Remove-Item (Join-Path $PackageRoot 'm365-sharepoint-modernizer') -Recurse -Force -ErrorAction SilentlyContinue
