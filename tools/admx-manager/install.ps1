[CmdletBinding()]
param([string]$InstallPath="$env:ProgramFiles\System8 ADMX Manager",[switch]$NoLaunch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if($PSVersionTable.PSVersion.Major -lt 5){throw 'PowerShell 5.1 or PowerShell 7+ is required.'}
$isWindows=($env:OS -eq 'Windows_NT')
if(-not $isWindows){throw 'Windows is required.'}
if($PSVersionTable.PSVersion.Major -eq 5){[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}
$id=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($id)
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  $exe=if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'}
  $tmp=Join-Path $env:TEMP ('s8-admx-'+[guid]::NewGuid().ToString('N')+'.ps1')
  $MyInvocation.MyCommand.ScriptBlock.ToString()|Set-Content $tmp -Encoding UTF8
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$tmp+'"'),'-InstallPath',('"'+$InstallPath+'"'));if($NoLaunch){$args+='-NoLaunch'}
  Start-Process $exe -Verb RunAs -ArgumentList ($args -join ' ') -Wait;exit
}

$app=@'
#requires -Version 5.1
param([switch]$NoElevation)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $NoElevation){
 $id=[Security.Principal.WindowsIdentity]::GetCurrent();$p=[Security.Principal.WindowsPrincipal]::new($id)
 if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
  $exe=if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'}
  Start-Process $exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -NoElevation";exit
 }
}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root='C:\ProgramData\System8\ADMXRepository'
$pkg=Join-Path $root 'packages';$snap=Join-Path $root 'snapshots';$log=Join-Path $root 'logs'
@($root,$pkg,$snap,$log)|%{New-Item -ItemType Directory $_ -Force|Out-Null}
$configFile=Join-Path $root 'config.json'
if(Test-Path $configFile){$cfg=Get-Content $configFile -Raw|ConvertFrom-Json}else{$cfg=[pscustomobject]@{Target='C:\Windows\PolicyDefinitions';Languages=@('en-US');Retention=20}}
function Save-Cfg{$cfg|ConvertTo-Json -Depth 4|Set-Content $configFile -Encoding UTF8}
function Write-Log([string]$m){$script:txtLog.AppendText("[$(Get-Date -Format HH:mm:ss)] $m`r`n");$script:txtLog.ScrollToEnd();Add-Content (Join-Path $log 'manager.log') "$(Get-Date -Format o) $m"}
function Hash-Tree([string]$path){if(-not(Test-Path $path)){return @()};@(Get-ChildItem $path -File -Recurse|%{[pscustomobject]@{Path=$_.FullName.Substring($path.Length).TrimStart('\');Hash=(Get-FileHash $_.FullName -Algorithm SHA256).Hash;Length=$_.Length}})}
function Validate-Store([string]$path){$r=[Collections.Generic.List[string]]::new();$ok=$true;if(-not(Test-Path $path)){$r.Add("Not found: $path");return [pscustomobject]@{Ok=$false;Messages=$r}};$files=@(Get-ChildItem $path -Filter *.admx -File);$r.Add("ADMX: $($files.Count)");foreach($f in $files){try{[xml](Get-Content $f.FullName -Raw)|Out-Null}catch{$ok=$false;$r.Add("Invalid ADMX: $($f.Name)")}};foreach($lang in $cfg.Languages){$lp=Join-Path $path $lang;if(-not(Test-Path $lp)){$r.Add("Missing language folder: $lang");continue};foreach($f in Get-ChildItem $lp -Filter *.adml -File){try{[xml](Get-Content $f.FullName -Raw)|Out-Null}catch{$ok=$false;$r.Add("Invalid ADML: $lang\$($f.Name)")}}};[pscustomobject]@{Ok=$ok;Messages=$r}}
function Snapshot([string]$reason){$id=Get-Date -Format 'yyyyMMdd-HHmmss';$d=Join-Path $snap $id;New-Item -ItemType Directory (Join-Path $d 'PolicyDefinitions') -Force|Out-Null;if(Test-Path $cfg.Target){Copy-Item (Join-Path $cfg.Target '*') (Join-Path $d 'PolicyDefinitions') -Recurse -Force -ErrorAction SilentlyContinue};[pscustomobject]@{Id=$id;Created=(Get-Date -Format o);Reason=$reason;Files=(Hash-Tree (Join-Path $d 'PolicyDefinitions'))}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $d 'snapshot.json') -Encoding UTF8;$all=@(Get-ChildItem $snap -Directory|Sort-Object Name -Descending);if($all.Count -gt $cfg.Retention){$all|Select-Object -Skip $cfg.Retention|Remove-Item -Recurse -Force};$id}
function Refresh-Snapshots{$script:gridSnap.ItemsSource=@(Get-ChildItem $snap -Directory -ErrorAction SilentlyContinue|Sort-Object Name -Descending|%{$m=Join-Path $_.FullName 'snapshot.json';if(Test-Path $m){$j=Get-Content $m -Raw|ConvertFrom-Json;[pscustomobject]@{Id=$j.Id;Created=$j.Created;Reason=$j.Reason;Path=$_.FullName}}})}
function Find-PD([string]$root){$d=Get-ChildItem $root -Directory -Recurse -ErrorAction SilentlyContinue|?{$_.Name -eq 'PolicyDefinitions' -and (Get-ChildItem $_.FullName -Filter *.admx -File -ErrorAction SilentlyContinue)}|Select-Object -First 1;if($d){return $d.FullName};$f=Get-ChildItem $root -Filter *.admx -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($f){return $f.Directory.FullName};throw 'No ADMX files found.'}
function Import-Package([string]$file){$name=([IO.Path]::GetFileNameWithoutExtension($file)-replace '[^a-zA-Z0-9._-]','-');$tmp=Join-Path $env:TEMP ('admx-'+[guid]::NewGuid());New-Item -ItemType Directory $tmp|Out-Null;switch([IO.Path]::GetExtension($file).ToLower()){'.zip'{Expand-Archive $file $tmp -Force}'.msi'{$p=Start-Process msiexec.exe -ArgumentList "/a `"$file`" /qn TARGETDIR=`"$tmp`"" -Wait -PassThru;if($p.ExitCode){throw "MSI extraction failed: $($p.ExitCode)"}}default{throw 'Import ZIP or MSI packages.'}};$pd=Find-PD $tmp;$dest=Join-Path $pkg $name;Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue;New-Item -ItemType Directory $dest -Force|Out-Null;Copy-Item (Join-Path $pd '*') $dest -Recurse -Force;Remove-Item $tmp -Recurse -Force;Write-Log "Imported $name";Refresh-Packages}
function Refresh-Packages{$script:gridPkg.ItemsSource=@(Get-ChildItem $pkg -Directory -ErrorAction SilentlyContinue|%{[pscustomobject]@{Use=$false;Name=$_.Name;Path=$_.FullName;Files=@(Get-ChildItem $_.FullName -Filter *.admx -File).Count}})}
function Deploy([switch]$Dry){$selected=@($gridPkg.ItemsSource|? Use);if(-not $selected){[Windows.MessageBox]::Show('Select at least one package.');return};$stage=Join-Path $env:TEMP ('admx-stage-'+[guid]::NewGuid());New-Item -ItemType Directory $stage|Out-Null;if(Test-Path $cfg.Target){Copy-Item (Join-Path $cfg.Target '*') $stage -Recurse -Force -ErrorAction SilentlyContinue};foreach($p in $selected){Copy-Item (Join-Path $p.Path '*') $stage -Recurse -Force};$v=Validate-Store $stage;$v.Messages|%{Write-Log $_};if(-not $v.Ok){Remove-Item $stage -Recurse -Force;throw 'Validation failed.'};$a=Hash-Tree $cfg.Target;$b=Hash-Tree $stage;$am=@{};$a|%{$am[$_.Path]=$_.Hash};$bm=@{};$b|%{$bm[$_.Path]=$_.Hash};$add=@($bm.Keys|?{-not $am.ContainsKey($_)}).Count;$del=@($am.Keys|?{-not $bm.ContainsKey($_)}).Count;$chg=@($bm.Keys|?{$am.ContainsKey($_)-and $am[$_] -ne $bm[$_]}).Count;Write-Log "Plan: +$add ~$chg -$del";if($Dry){Write-Log 'Dry run complete.';Remove-Item $stage -Recurse -Force;return};$sid=Snapshot 'Before deployment';Write-Log "Snapshot: $sid";$incoming="$($cfg.Target).__incoming";$old="$($cfg.Target).__old";Remove-Item $incoming,$old -Recurse -Force -ErrorAction SilentlyContinue;Move-Item $stage $incoming;if(Test-Path $cfg.Target){Move-Item $cfg.Target $old};try{Move-Item $incoming $cfg.Target;$post=Validate-Store $cfg.Target;if(-not $post.Ok){throw 'Post-validation failed.'};Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue;Write-Log 'Deployment committed.'}catch{Remove-Item $cfg.Target -Recurse -Force -ErrorAction SilentlyContinue;if(Test-Path $old){Move-Item $old $cfg.Target};throw};Refresh-Snapshots}
function Rollback{if(-not $gridSnap.SelectedItem){[Windows.MessageBox]::Show('Select a snapshot.');return};$s=$gridSnap.SelectedItem;$src=Join-Path $s.Path 'PolicyDefinitions';$null=Snapshot "Before rollback to $($s.Id)";$incoming="$($cfg.Target).__rollback";$old="$($cfg.Target).__old";Remove-Item $incoming,$old -Recurse -Force -ErrorAction SilentlyContinue;Copy-Item $src $incoming -Recurse -Force;if(Test-Path $cfg.Target){Move-Item $cfg.Target $old};try{Move-Item $incoming $cfg.Target;Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue;Write-Log "Rolled back to $($s.Id)"}catch{if(Test-Path $old){Move-Item $old $cfg.Target};throw};Refresh-Snapshots}
[xml]$x=@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="System 8 ADMX Manager" Height="720" Width="1100" WindowStartupLocation="CenterScreen"><Grid Margin="12"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="180"/><RowDefinition Height="Auto"/></Grid.RowDefinitions><StackPanel Orientation="Horizontal"><Button Name="Import" Content="Import ZIP/MSI…" Width="130" Margin="0,0,8,8"/><Button Name="Dry" Content="Dry run" Width="90" Margin="0,0,8,8"/><Button Name="Deploy" Content="Deploy" Width="90" Margin="0,0,8,8"/><Button Name="Validate" Content="Validate" Width="90" Margin="0,0,8,8"/><Button Name="Rollback" Content="Rollback" Width="90" Margin="0,0,8,8"/><TextBlock Text="Target:" Margin="18,5,5,0"/><TextBox Name="Target" Width="390" Height="25"/></StackPanel><TabControl Grid.Row="1"><TabItem Header="Packages"><DataGrid Name="Packages" AutoGenerateColumns="False" CanUserAddRows="False"><DataGrid.Columns><DataGridCheckBoxColumn Header="Use" Binding="{Binding Use}" Width="55"/><DataGridTextColumn Header="Package" Binding="{Binding Name}" Width="*"/><DataGridTextColumn Header="ADMX" Binding="{Binding Files}" Width="80"/><DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="430"/></DataGrid.Columns></DataGrid></TabItem><TabItem Header="Snapshots"><DataGrid Name="Snapshots" AutoGenerateColumns="False" IsReadOnly="True"><DataGrid.Columns><DataGridTextColumn Header="Snapshot" Binding="{Binding Id}" Width="180"/><DataGridTextColumn Header="Created" Binding="{Binding Created}" Width="220"/><DataGridTextColumn Header="Reason" Binding="{Binding Reason}" Width="*"/></DataGrid.Columns></DataGrid></TabItem></TabControl><GroupBox Grid.Row="2" Header="Activity" Margin="0,8,0,8"><TextBox Name="Log" IsReadOnly="True" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" FontFamily="Consolas"/></GroupBox><TextBlock Grid.Row="3" Text="Repository: C:\ProgramData\System8\ADMXRepository"/></Grid></Window>
"@
$w=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($x));$script:gridPkg=$w.FindName('Packages');$script:gridSnap=$w.FindName('Snapshots');$script:txtLog=$w.FindName('Log');$target=$w.FindName('Target');$target.Text=$cfg.Target
$w.FindName('Import').Add_Click({$d=New-Object Microsoft.Win32.OpenFileDialog;$d.Filter='ADMX packages (*.zip;*.msi)|*.zip;*.msi';if($d.ShowDialog()){try{Import-Package $d.FileName}catch{Write-Log "ERROR: $($_.Exception.Message)"}}})
$w.FindName('Dry').Add_Click({$cfg.Target=$target.Text;Save-Cfg;try{Deploy -Dry}catch{Write-Log "ERROR: $($_.Exception.Message)"}})
$w.FindName('Deploy').Add_Click({$cfg.Target=$target.Text;Save-Cfg;if([Windows.MessageBox]::Show("Deploy to $($cfg.Target)? A snapshot will be created.",'Confirm','YesNo','Warning') -eq 'Yes'){try{Deploy}catch{Write-Log "ERROR: $($_.Exception.Message)"}}})
$w.FindName('Validate').Add_Click({$cfg.Target=$target.Text;Save-Cfg;$v=Validate-Store $cfg.Target;$v.Messages|%{Write-Log $_};[Windows.MessageBox]::Show($(if($v.Ok){'Validation passed.'}else{'Validation failed.'}))})
$w.FindName('Rollback').Add_Click({try{Rollback}catch{Write-Log "ERROR: $($_.Exception.Message)"}})
Refresh-Packages;Refresh-Snapshots;Write-Log 'Ready.';$null=$w.ShowDialog()
'@

New-Item -ItemType Directory -Path $InstallPath -Force|Out-Null
$appPath=Join-Path $InstallPath 'System8.ADMX.Manager.ps1'
$app|Set-Content -LiteralPath $appPath -Encoding UTF8
$launcher=Join-Path $InstallPath 'Launch-ADMX-Manager.cmd'
'@echo off
where pwsh.exe >nul 2>&1
if %errorlevel%==0 (start "System 8 ADMX Manager" pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0System8.ADMX.Manager.ps1") else (start "System 8 ADMX Manager" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0System8.ADMX.Manager.ps1")'|Set-Content $launcher -Encoding ASCII
$ws=New-Object -ComObject WScript.Shell
foreach($link in @((Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'System 8 ADMX Manager.lnk'),(Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\System 8 ADMX Manager.lnk'))){$s=$ws.CreateShortcut($link);$s.TargetPath=$launcher;$s.WorkingDirectory=$InstallPath;$s.IconLocation="$env:SystemRoot\System32\imageres.dll,109";$s.Save()}
Write-Host "Installed System 8 ADMX Manager to $InstallPath" -ForegroundColor Green
if(-not $NoLaunch){Start-Process $launcher}
