[CmdletBinding()]
param(
  [Parameter(Position=0)][ValidateSet('inventory','licenses','labels','sharing','full','doctor','help')][string]$Command='help',
  [string]$OutputPath=(Join-Path (Get-Location) ('s8-m365-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))),
  [switch]$InstallDependencies,
  [switch]$NoHtml
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if($PSVersionTable.PSVersion.Major -lt 5){throw 'PowerShell 5.1 or 7+ required.'}
if($PSVersionTable.PSVersion.Major -eq 5){[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}

$required=@('Microsoft.Graph.Authentication','Microsoft.Graph.Users','Microsoft.Graph.Groups','Microsoft.Graph.Identity.DirectoryManagement','Microsoft.Graph.Sites')
function Ensure-Modules{
  $missing=@($required|Where-Object{-not(Get-Module -ListAvailable $_)})
  if($missing -and -not $InstallDependencies){throw "Missing modules: $($missing -join ', '). Re-run with -InstallDependencies."}
  foreach($m in $missing){Install-Module $m -Scope CurrentUser -Force -AllowClobber -Repository PSGallery}
  foreach($m in $required){Import-Module $m -ErrorAction Stop}
}
function Connect-S8Graph{
  Ensure-Modules
  $scopes=@('Directory.Read.All','User.Read.All','Group.Read.All','Organization.Read.All','Policy.Read.All','Sites.Read.All','Reports.Read.All','InformationProtectionPolicy.Read.All')
  Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
}
function New-OutputRoot{New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null}
function Export-Data{
  param([string]$Name,[object[]]$Data)
  $json=Join-Path $OutputPath "$Name.json";$csv=Join-Path $OutputPath "$Name.csv"
  @($Data)|ConvertTo-Json -Depth 12|Set-Content $json -Encoding UTF8
  @($Data)|Export-Csv $csv -NoTypeInformation -Encoding UTF8
}
function Write-HtmlReport{
  param([hashtable]$Sections)
  if($NoHtml){return}
  $cards='';foreach($k in $Sections.Keys){$rows=@($Sections[$k]);$cards+="<section><h2>$k</h2><p class='count'>$($rows.Count) records</p>";if($rows.Count){$cards+=($rows|Select-Object -First 200|ConvertTo-Html -Fragment)};$cards+='</section>'}
  $html=@"
<!doctype html><html><head><meta charset='utf-8'><title>System 8 Microsoft 365 Assessment</title><style>
body{background:#07090d;color:#dbe7ea;font:14px Segoe UI,Arial;margin:0;padding:32px}main{max-width:1500px;margin:auto}h1{font-size:40px;letter-spacing:.08em}h1 span{color:#32f5c8}h2{color:#32f5c8;border-bottom:1px solid #26343c;padding-bottom:8px}section{background:#0d1218;border:1px solid #26343c;border-radius:14px;padding:22px;margin:18px 0;overflow:auto}.count{color:#8ba0aa}table{border-collapse:collapse;width:100%;font-size:12px}th,td{border-bottom:1px solid #26343c;padding:7px;text-align:left;vertical-align:top}th{color:#32f5c8;position:sticky;top:0;background:#0d1218}code{color:#32f5c8}</style></head><body><main><h1>SYSTEM <span>8</span> / M365 ASSESSMENT</h1><p>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz') · read-only evidence collection</p>$cards</main></body></html>
"@
  $html|Set-Content (Join-Path $OutputPath 'report.html') -Encoding UTF8
}
function Get-Inventory{
  $org=@(Get-MgOrganization -All | Select-Object Id,DisplayName,CreatedDateTime,VerifiedDomains)
  $users=@(Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType,CreatedDateTime,AssignedLicenses,SignInActivity | ForEach-Object{[pscustomobject]@{Id=$_.Id;DisplayName=$_.DisplayName;UPN=$_.UserPrincipalName;Enabled=$_.AccountEnabled;Type=$_.UserType;Created=$_.CreatedDateTime;LicenseCount=@($_.AssignedLicenses).Count;LastSignIn=$_.SignInActivity.LastSignInDateTime}})
  $groups=@(Get-MgGroup -All -Property Id,DisplayName,GroupTypes,SecurityEnabled,MailEnabled,Visibility,CreatedDateTime | ForEach-Object{[pscustomobject]@{Id=$_.Id;DisplayName=$_.DisplayName;Types=($_.GroupTypes -join ',');Security=$_.SecurityEnabled;Mail=$_.MailEnabled;Visibility=$_.Visibility;Created=$_.CreatedDateTime}})
  $roles=@(Get-MgDirectoryRole -All | Select-Object Id,DisplayName,Description)
  Export-Data organization $org;Export-Data users $users;Export-Data groups $groups;Export-Data directory-roles $roles
  @{Organization=$org;Users=$users;Groups=$groups;'Directory roles'=$roles}
}
function Get-LicenseAssessment{
  $skus=@(Get-MgSubscribedSku -All)
  $rows=@($skus|ForEach-Object{[pscustomobject]@{SkuId=$_.SkuId;SkuPartNumber=$_.SkuPartNumber;Enabled=$_.PrepaidUnits.Enabled;Warning=$_.PrepaidUnits.Warning;Suspended=$_.PrepaidUnits.Suspended;Consumed=$_.ConsumedUnits;Available=([int]$_.PrepaidUnits.Enabled-[int]$_.ConsumedUnits);UtilizationPct=if($_.PrepaidUnits.Enabled){[math]::Round(100*$_.ConsumedUnits/$_.PrepaidUnits.Enabled,1)}else{0};CapabilityStatus=$_.CapabilityStatus}})
  $users=@(Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType,AssignedLicenses | ForEach-Object{[pscustomobject]@{UPN=$_.UserPrincipalName;DisplayName=$_.DisplayName;Enabled=$_.AccountEnabled;Type=$_.UserType;SkuIds=(@($_.AssignedLicenses.SkuId)-join ';');LicenseCount=@($_.AssignedLicenses).Count}})
  $unlicensed=@($users|Where-Object{$_.Enabled -and $_.Type -eq 'Member' -and $_.LicenseCount -eq 0})
  $disabledLicensed=@($users|Where-Object{-not $_.Enabled -and $_.LicenseCount -gt 0})
  Export-Data license-skus $rows;Export-Data user-licenses $users;Export-Data unlicensed-enabled-users $unlicensed;Export-Data disabled-licensed-users $disabledLicensed
  @{'SKU utilization'=$rows;'Enabled unlicensed users'=$unlicensed;'Disabled licensed users'=$disabledLicensed}
}
function Invoke-GraphBeta{
  param([string]$Uri)
  Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
}
function Get-LabelAssessment{
  $labels=@();$policies=@();$errors=@()
  try{$r=Invoke-GraphBeta 'https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels';$labels=@($r.value|ForEach-Object{[pscustomobject]@{Id=$_.id;Name=$_.name;Description=$_.description;Color=$_.color;Sensitivity=$_.sensitivity;Tooltip=$_.tooltip;IsActive=$_.isActive}})}catch{$errors+=[pscustomobject]@{Area='Sensitivity labels';Error=$_.Exception.Message}}
  try{$r=Invoke-GraphBeta 'https://graph.microsoft.com/beta/security/informationProtection/labelPolicySettings';$policies=@($r.value)}catch{$errors+=[pscustomobject]@{Area='Label policy settings';Error=$_.Exception.Message}}
  $readiness=@([pscustomobject]@{Check='Sensitivity labels discoverable through Graph';Status=if($labels.Count){'PASS'}else{'REVIEW'};Evidence="$($labels.Count) labels returned"},[pscustomobject]@{Check='At least one active label';Status=if(@($labels|Where-Object IsActive).Count){'PASS'}else{'REVIEW'};Evidence="$(@($labels|Where-Object IsActive).Count) active labels"},[pscustomobject]@{Check='Graph permissions/API availability';Status=if($errors.Count){'REVIEW'}else{'PASS'};Evidence=if($errors.Count){$errors.Error -join ' | '}else{'Queries completed'}})
  Export-Data sensitivity-labels $labels;Export-Data label-policy-settings $policies;Export-Data label-readiness $readiness;Export-Data label-errors $errors
  @{'Sensitivity labels'=$labels;'Label readiness'=$readiness;'Collection errors'=$errors}
}
function Get-SharingAssessment{
  $sites=@();$errors=@()
  try{$sites=@(Get-MgSite -All -Property Id,DisplayName,WebUrl,CreatedDateTime,LastModifiedDateTime | ForEach-Object{[pscustomobject]@{Id=$_.Id;DisplayName=$_.DisplayName;WebUrl=$_.WebUrl;Created=$_.CreatedDateTime;Modified=$_.LastModifiedDateTime}})}catch{$errors+=[pscustomobject]@{Area='Sites';Error=$_.Exception.Message}}
  $guests=@(Get-MgUser -All -Filter "userType eq 'Guest'" -Property Id,DisplayName,UserPrincipalName,AccountEnabled,CreatedDateTime,ExternalUserState,ExternalUserStateChangeDateTime | ForEach-Object{[pscustomobject]@{Id=$_.Id;DisplayName=$_.DisplayName;UPN=$_.UserPrincipalName;Enabled=$_.AccountEnabled;Created=$_.CreatedDateTime;State=$_.ExternalUserState;StateChanged=$_.ExternalUserStateChangeDateTime}})
  $guestDomains=@($guests|ForEach-Object{if($_.UPN -match '#EXT#@'){($_.UPN -split '#EXT#@')[0] -replace '_','@'}else{$_.UPN}}|ForEach-Object{($_ -split '@')[-1]}|Group-Object|Sort-Object Count -Descending|ForEach-Object{[pscustomobject]@{Domain=$_.Name;GuestCount=$_.Count}})
  $groups=@(Get-MgGroup -All -Property Id,DisplayName,Visibility,GroupTypes,MailEnabled,SecurityEnabled | Where-Object{$_.Visibility -in @('Public','Private')} | ForEach-Object{[pscustomobject]@{Id=$_.Id;DisplayName=$_.DisplayName;Visibility=$_.Visibility;Types=($_.GroupTypes -join ',');MailEnabled=$_.MailEnabled;SecurityEnabled=$_.SecurityEnabled}})
  Export-Data sites $sites;Export-Data guests $guests;Export-Data guest-domains $guestDomains;Export-Data collaboration-groups $groups;Export-Data sharing-errors $errors
  @{Sites=$sites;Guests=$guests;'Guest domains'=$guestDomains;'Collaboration groups'=$groups;'Collection errors'=$errors}
}
function Invoke-Assessment{
  param([string]$Mode)
  New-OutputRoot;Connect-S8Graph
  $sections=[ordered]@{}
  if($Mode -in @('inventory','full')){(Get-Inventory).GetEnumerator()|ForEach-Object{$sections[$_.Key]=$_.Value}}
  if($Mode -in @('licenses','full')){(Get-LicenseAssessment).GetEnumerator()|ForEach-Object{$sections[$_.Key]=$_.Value}}
  if($Mode -in @('labels','full')){(Get-LabelAssessment).GetEnumerator()|ForEach-Object{$sections[$_.Key]=$_.Value}}
  if($Mode -in @('sharing','full')){(Get-SharingAssessment).GetEnumerator()|ForEach-Object{$sections[$_.Key]=$_.Value}}
  Write-HtmlReport $sections
  [pscustomobject]@{Generated=(Get-Date -Format o);Command=$Mode;Output=$OutputPath;Tenant=(Get-MgContext).TenantId;Sections=@($sections.Keys)}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutputPath 'manifest.json') -Encoding UTF8
  Write-Host "Assessment complete: $OutputPath" -ForegroundColor Green
}
function Doctor{
  [pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();Edition=$PSVersionTable.PSEdition;GraphModulesPresent=(@($required|Where-Object{Get-Module -ListAvailable $_}).Count -eq $required.Count);RequiredModules=($required -join ', ');OutputPath=$OutputPath}|Format-List
}
switch($Command){
 'inventory'{Invoke-Assessment inventory}
 'licenses'{Invoke-Assessment licenses}
 'labels'{Invoke-Assessment labels}
 'sharing'{Invoke-Assessment sharing}
 'full'{Invoke-Assessment full}
 'doctor'{Doctor}
 default{Write-Host @'
System 8 Microsoft 365 Toolkit

s8m365 inventory [-OutputPath <path>] [-InstallDependencies]
s8m365 licenses  [-OutputPath <path>] [-InstallDependencies]
s8m365 labels    [-OutputPath <path>] [-InstallDependencies]
s8m365 sharing   [-OutputPath <path>] [-InstallDependencies]
s8m365 full      [-OutputPath <path>] [-InstallDependencies]
s8m365 doctor

All assessment commands are read-only. Output includes JSON, CSV and an HTML evidence report.
'@}
}
