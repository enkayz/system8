[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Command='help',
  [Parameter(Position=1)][string]$Package,
  [ValidateSet('stable','preview','nightly')][string]$Channel='stable',
  [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if($PSVersionTable.PSVersion.Major -lt 5){throw 'PowerShell 5.1 or 7+ required.'}
if($env:OS -ne 'Windows_NT'){throw 'Windows is required.'}
if($PSVersionTable.PSVersion.Major -eq 5){[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}
$Root=Join-Path $env:ProgramData 'System8\Packages'
$State=Join-Path $Root 'state.json'
$Cache=Join-Path $Root 'cache'
$Backups=Join-Path $Root 'backups'
$Base='https://raw.githubusercontent.com/enkayz/system8/main/tools/s8'
@($Root,$Cache,$Backups)|ForEach-Object{New-Item -ItemType Directory -Path $_ -Force|Out-Null}
function Get-State{if(Test-Path $State){Get-Content $State -Raw|ConvertFrom-Json}else{[pscustomobject]@{channel='stable';packages=[pscustomobject]@{}}}}
function Save-State($s){$s|ConvertTo-Json -Depth 12|Set-Content $State -Encoding UTF8}
function Get-Manifest{param([string]$c)$u="$Base/manifests/$c.json";Invoke-RestMethod -UseBasicParsing -Uri $u}
function Get-PackageDef{param($m,[string]$n)$p=@($m.packages|Where-Object name -eq $n);if(-not $p){throw "Unknown package: $n"};$p[0]}
function Ensure-Admin{
 $id=[Security.Principal.WindowsIdentity]::GetCurrent();$p=[Security.Principal.WindowsPrincipal]::new($id)
 if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run this command in an elevated PowerShell session.'}
}
function Download-Verified{param($def)
 $zip=Join-Path $Cache ("$($def.name)-$($def.version).zip")
 Invoke-WebRequest -UseBasicParsing -Uri $def.url -OutFile $zip
 $hash=(Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
 if($def.sha256 -and $def.sha256 -ne 'development' -and $hash -ne $def.sha256.ToLowerInvariant()){Remove-Item $zip -Force;throw "SHA256 mismatch for $($def.name)"}
 $zip
}
function Install-Package{param([string]$n,[string]$c,[switch]$reinstall)
 Ensure-Admin;$m=Get-Manifest $c;$d=Get-PackageDef $m $n;$s=Get-State;$existing=$s.packages.PSObject.Properties[$n]
 if($existing -and -not $reinstall -and $existing.Value.version -eq $d.version){Write-Host "$n $($d.version) already installed.";return}
 if($existing){Backup-Package $n}
 $zip=Download-Verified $d;$tmp=Join-Path $env:TEMP ('s8-'+[guid]::NewGuid().ToString('N'));Expand-Archive $zip $tmp -Force
 $installer=Join-Path $tmp $d.installScript;if(-not(Test-Path $installer)){throw "Installer missing: $($d.installScript)"}
 & $installer -PackageRoot $Root
 if($LASTEXITCODE){throw "Package installer exited $LASTEXITCODE"}
 $s=Get-State;$record=[pscustomobject]@{version=$d.version;channel=$c;installed=(Get-Date -Format o);source=$d.url}
 $s.packages|Add-Member -NotePropertyName $n -NotePropertyValue $record -Force;$s.channel=$c;Save-State $s
 Remove-Item $tmp -Recurse -Force;Write-Host "Installed $n $($d.version)." -ForegroundColor Green
}
function Backup-Package{param([string]$n)
 $s=Get-State;$p=$s.packages.PSObject.Properties[$n];if(-not $p){return}
 $src=Join-Path $Root $n;if(Test-Path $src){$id=Get-Date -Format 'yyyyMMdd-HHmmss';$dest=Join-Path $Backups "$n\$id";New-Item -ItemType Directory $dest -Force|Out-Null;Copy-Item $src (Join-Path $dest 'payload') -Recurse -Force;$p.Value|ConvertTo-Json -Depth 5|Set-Content (Join-Path $dest 'state.json') -Encoding UTF8}
}
function Remove-Package{param([string]$n)
 Ensure-Admin;$s=Get-State;$p=$s.packages.PSObject.Properties[$n];if(-not $p){Write-Host "$n is not installed.";return};Backup-Package $n
 $dir=Join-Path $Root $n;$un=Join-Path $dir 'uninstall.ps1';if(Test-Path $un){& $un -PackageRoot $Root};Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
 $s.packages.PSObject.Properties.Remove($n);Save-State $s;Write-Host "Removed $n."
}
function Rollback-Package{param([string]$n)
 Ensure-Admin;$base=Join-Path $Backups $n;$snap=Get-ChildItem $base -Directory -ErrorAction SilentlyContinue|Sort-Object Name -Descending|Select-Object -First 1;if(-not $snap){throw "No rollback snapshot for $n"}
 $dir=Join-Path $Root $n;Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue;Copy-Item (Join-Path $snap.FullName 'payload') $dir -Recurse -Force
 $meta=Get-Content (Join-Path $snap.FullName 'state.json') -Raw|ConvertFrom-Json;$s=Get-State;$s.packages|Add-Member -NotePropertyName $n -NotePropertyValue $meta -Force;Save-State $s;Write-Host "Rolled back $n to $($meta.version)." -ForegroundColor Yellow
}
function Show-List{$s=Get-State;if(-not $s.packages.PSObject.Properties){Write-Host 'No packages installed.';return};$s.packages.PSObject.Properties|ForEach-Object{[pscustomobject]@{Package=$_.Name;Version=$_.Value.version;Channel=$_.Value.channel;Installed=$_.Value.installed}}|Format-Table -AutoSize}
function Search-Packages{param([string]$q)$m=Get-Manifest $Channel;$m.packages|Where-Object{$_.name -like "*$q*" -or $_.description -like "*$q*"}|Select-Object name,version,description|Format-Table -AutoSize}
function Doctor{Write-Host "PowerShell: $($PSVersionTable.PSVersion)";Write-Host "Root: $Root";Write-Host "State: $(Test-Path $State)";try{$null=Get-Manifest $Channel;Write-Host 'Manifest: OK'}catch{Write-Host "Manifest: FAIL - $($_.Exception.Message)" -ForegroundColor Red};Show-List}
switch($Command.ToLowerInvariant()){
 'install'{if(-not $Package){throw 'Usage: s8 install <package>'};Install-Package $Package $Channel -reinstall:$Force}
 'update'{if($Package){Install-Package $Package $Channel -reinstall:$true}else{$s=Get-State;$s.packages.PSObject.Properties.Name|ForEach-Object{Install-Package $_ $Channel -reinstall:$true}}}
 'upgrade'{& $PSCommandPath update $Package -Channel $Channel}
 'remove'{if(-not $Package){throw 'Usage: s8 remove <package>'};Remove-Package $Package}
 'rollback'{if(-not $Package){throw 'Usage: s8 rollback <package>'};Rollback-Package $Package}
 'list'{Show-List}
 'search'{Search-Packages $Package}
 'doctor'{Doctor}
 'help'{Write-Host @'
System 8 Package Manager

s8 install <package> [-Channel stable|preview|nightly]
s8 update [package]
s8 remove <package>
s8 rollback <package>
s8 list
s8 search [term]
s8 doctor
'@}
 default{throw "Unknown command: $Command"}
}
