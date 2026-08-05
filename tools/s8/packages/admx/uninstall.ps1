[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$app="$env:ProgramFiles\System8 ADMX Manager"
$links=@(
  (Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'System 8 ADMX Manager.lnk'),
  (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\System 8 ADMX Manager.lnk')
)
$links|ForEach-Object{Remove-Item $_ -Force -ErrorAction SilentlyContinue}
Remove-Item $app -Recurse -Force -ErrorAction SilentlyContinue
