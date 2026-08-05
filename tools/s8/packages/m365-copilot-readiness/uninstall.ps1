[CmdletBinding()]param([Parameter(Mandatory)][string]$PackageRoot)
Remove-Item (Join-Path $env:ProgramFiles 'System8\bin\s8copilot.cmd') -Force -ErrorAction SilentlyContinue;Remove-Item (Join-Path $PackageRoot 'm365-copilot-readiness') -Recurse -Force -ErrorAction SilentlyContinue
