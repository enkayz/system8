[CmdletBinding()]
param(
  [Parameter(Position=0)][ValidateSet('entra','apps','ca','stale','teams','sharepoint','drift','full','doctor')][string]$Command='full',
  [string]$OutputPath=(Join-Path $PWD ('s8-m365-governance-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))),
  [int]$StaleDays=90,
  [switch]$InstallDependencies
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
if($PSVersionTable.PSVersion.Major -lt 5){throw 'PowerShell 5.1 or 7+ required.'}
if($PSVersionTable.PSVersion.Major -eq 5){[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}

$Scopes=@(
 'Directory.Read.All','Policy.Read.All','Application.Read.All','AuditLog.Read.All',
 'User.Read.All','Group.Read.All','Sites.Read.All','Team.ReadBasic.All','Reports.Read.All'
)

function Ensure-Modules{
  $required=@('Microsoft.Graph.Authentication')
  foreach($m in $required){
    if(-not(Get-Module -ListAvailable $m)){
      if(-not $InstallDependencies){throw "Missing $m. Re-run with -InstallDependencies."}
      Install-Module $m -Scope CurrentUser -Force -AllowClobber
    }
  }
  Import-Module Microsoft.Graph.Authentication -Force
}
function Connect-S8Graph{
  Ensure-Modules
  $ctx=Get-MgContext -ErrorAction SilentlyContinue
  if(-not $ctx){Connect-MgGraph -Scopes $Scopes -NoWelcome}
}
function Get-AllPages([string]$Uri){
  $items=[Collections.Generic.List[object]]::new();$next=$Uri
  while($next){$r=Invoke-MgGraphRequest -Method GET -Uri $next;if($r.value){foreach($x in $r.value){$items.Add($x)}}else{$items.Add($r)};$next=$r.'@odata.nextLink'}
  @($items)
}
function Save-Data([string]$Name,$Data){
  New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
  $Data|ConvertTo-Json -Depth 20|Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8
  if($Data -is [System.Collections.IEnumerable] -and -not($Data -is [string])){try{$Data|Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8}catch{}}
}
function Safe([scriptblock]$Action,[string]$Name){try{&$Action}catch{[pscustomobject]@{Collection=$Name;Error=$_.Exception.Message}}}

function Get-EntraPosture{
  $org=Invoke-MgGraphRequest GET 'https://graph.microsoft.com/v1.0/organization?$select=id,displayName,createdDateTime,tenantType,verifiedDomains,securityComplianceNotificationMails,securityComplianceNotificationPhones'
  $roles=Get-AllPages 'https://graph.microsoft.com/v1.0/directoryRoles?$expand=members'
  $admins=@();foreach($r in $roles){foreach($m in @($r.members)){$admins+=[pscustomobject]@{Role=$r.displayName;Member=$m.displayName;UPN=$m.userPrincipalName;Type=$m.'@odata.type'}}}
  $domains=@($org.value[0].verifiedDomains|%{[pscustomobject]@{Domain=$_.name;Default=$_.isDefault;Initial=$_.isInitial;Verified=$_.isVerified;Capabilities=($_.capabilities -join ',')}})
  $summary=[pscustomobject]@{Tenant=$org.value[0].displayName;TenantId=$org.value[0].id;Created=$org.value[0].createdDateTime;RoleAssignments=$admins.Count;GlobalAdmins=@($admins|? Role -eq 'Global Administrator').Count;VerifiedDomains=$domains.Count}
  Save-Data entra-summary @($summary);Save-Data entra-admins $admins;Save-Data entra-domains $domains
  [pscustomobject]@{Summary=$summary;Admins=$admins;Domains=$domains}
}
function Get-AppExposure{
  $apps=Get-AllPages 'https://graph.microsoft.com/v1.0/servicePrincipals?$select=id,appId,displayName,accountEnabled,servicePrincipalType,publisherName,verifiedPublisher,appOwnerOrganizationId,oauth2PermissionScopes,appRoles,passwordCredentials,keyCredentials,preferredSingleSignOnMode,homepage'
  $grants=Get-AllPages 'https://graph.microsoft.com/v1.0/oauth2PermissionGrants'
  $high='Directory.ReadWrite.All|RoleManagement.ReadWrite.Directory|Application.ReadWrite.All|AppRoleAssignment.ReadWrite.All|Mail.ReadWrite|Files.ReadWrite.All|Sites.FullControl.All|User.ReadWrite.All|Group.ReadWrite.All'
  $rows=@();foreach($a in $apps){$g=@($grants|? clientId -eq $a.id);$scopes=($g.scope -join ' ');$rows+=[pscustomobject]@{Name=$a.displayName;AppId=$a.appId;Enabled=$a.accountEnabled;Type=$a.servicePrincipalType;Publisher=$a.publisherName;VerifiedPublisher=$a.verifiedPublisher.verifiedPublisherId;ConsentType=($g.consentType|Select-Object -Unique)-join ',';Scopes=$scopes;HighPrivilege=[bool]($scopes -match $high);Secrets=@($a.passwordCredentials).Count;Certificates=@($a.keyCredentials).Count;Homepage=$a.homepage}}
  Save-Data app-consent $rows;Save-Data app-consent-highrisk @($rows|? HighPrivilege)
  $rows
}
function Get-CAPosture{
  $policies=Get-AllPages 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
  $rows=@($policies|%{[pscustomobject]@{Name=$_.displayName;State=$_.state;Created=$_.createdDateTime;Modified=$_.modifiedDateTime;IncludeUsers=($_.conditions.users.includeUsers -join ',');ExcludeUsers=($_.conditions.users.excludeUsers -join ',');IncludeApps=($_.conditions.applications.includeApplications -join ',');GrantControls=($_.grantControls.builtInControls -join ',');SessionControls=($_.sessionControls.PSObject.Properties.Name -join ',');ClientAppTypes=($_.conditions.clientAppTypes -join ',')}})
  $summary=[pscustomobject]@{Total=$rows.Count;Enabled=@($rows|? State -eq 'enabled').Count;ReportOnly=@($rows|? State -eq 'enabledForReportingButNotEnforced').Count;Disabled=@($rows|? State -eq 'disabled').Count;MFA=@($rows|? GrantControls -match 'mfa').Count;Block=@($rows|? GrantControls -match 'block').Count}
  Save-Data conditional-access $rows;Save-Data conditional-access-summary @($summary)
  [pscustomobject]@{Summary=$summary;Policies=$rows}
}
function Get-StaleIdentity{
  $cut=(Get-Date).ToUniversalTime().AddDays(-$StaleDays)
  $users=Get-AllPages 'https://graph.microsoft.com/beta/users?$select=id,displayName,userPrincipalName,accountEnabled,userType,createdDateTime,signInActivity,assignedLicenses,passwordPolicies,onPremisesSyncEnabled'
  $rows=@($users|%{$last=$_.signInActivity.lastSuccessfulSignInDateTime;if(-not $last){$last=$_.signInActivity.lastSignInDateTime};[pscustomobject]@{DisplayName=$_.displayName;UPN=$_.userPrincipalName;Type=$_.userType;Enabled=$_.accountEnabled;Created=$_.createdDateTime;LastSignIn=$last;DaysSinceSignIn=if($last){[math]::Floor(((Get-Date)-[datetime]$last).TotalDays)}else{$null};NeverSignedIn=[bool](-not $last);Licensed=@($_.assignedLicenses).Count -gt 0;Hybrid=$_.onPremisesSyncEnabled;Stale=[bool]((-not $last)-or([datetime]$last -lt $cut))}})
  Save-Data stale-identities @($rows|?{$_.Enabled -and $_.Stale});Save-Data guest-identities @($rows|? Type -eq 'Guest');Save-Data identity-all $rows
  $rows
}
function Get-TeamsGovernance{
  $groups=Get-AllPages 'https://graph.microsoft.com/v1.0/groups?$filter=resourceProvisioningOptions/Any(x:x eq ''Team'')&$select=id,displayName,visibility,createdDateTime,renewedDateTime,expirationDateTime,mail,securityEnabled,mailEnabled,groupTypes,resourceProvisioningOptions'
  $rows=@();foreach($g in $groups){$owners=Safe {Get-AllPages "https://graph.microsoft.com/v1.0/groups/$($g.id)/owners?`$select=id,displayName,userPrincipalName"} 'owners';$members=Safe {Get-AllPages "https://graph.microsoft.com/v1.0/groups/$($g.id)/members?`$select=id"} 'members';$rows+=[pscustomobject]@{Team=$g.displayName;Id=$g.id;Visibility=$g.visibility;Created=$g.createdDateTime;Renewed=$g.renewedDateTime;Expires=$g.expirationDateTime;Owners=@($owners).Count;Members=@($members).Count;Ownerless=@($owners).Count -eq 0;SingleOwner=@($owners).Count -eq 1;Mail=$g.mail}}
  Save-Data teams-governance $rows;Save-Data teams-owner-risk @($rows|?{$_.Ownerless -or $_.SingleOwner})
  $rows
}
function Get-SharePointReadiness{
  $sites=Get-AllPages 'https://graph.microsoft.com/v1.0/sites?search=*&$select=id,displayName,name,webUrl,createdDateTime,lastModifiedDateTime,siteCollection'
  $rows=@($sites|%{[pscustomobject]@{Site=$_.displayName;Url=$_.webUrl;Hostname=$_.siteCollection.hostname;Created=$_.createdDateTime;Modified=$_.lastModifiedDateTime;DaysSinceModified=if($_.lastModifiedDateTime){[math]::Floor(((Get-Date)-[datetime]$_.lastModifiedDateTime).TotalDays)}else{$null};RootSite=[bool]$_.root;Personal=[bool]($_.webUrl -match '-my\.sharepoint\.com/personal/')}})
  Save-Data sharepoint-sites $rows;Save-Data sharepoint-stale @($rows|?{$_.DaysSinceModified -gt 365 -and -not $_.Personal})
  $rows
}
function Get-DriftSnapshot{
  $current=[ordered]@{Captured=(Get-Date -Format o);Tenant=(Get-MgContext).TenantId;ConditionalAccess=(Get-CAPosture).Summary;Entra=(Get-EntraPosture).Summary;Applications=@(Get-AppExposure|? HighPrivilege).Count;StaleEnabled=@(Get-StaleIdentity|?{$_.Enabled -and $_.Stale}).Count;TeamsOwnerRisk=@(Get-TeamsGovernance|?{$_.Ownerless -or $_.SingleOwner}).Count;SharePointStale=@(Get-SharePointReadiness|?{$_.DaysSinceModified -gt 365 -and -not $_.Personal}).Count}
  $path=Join-Path $OutputPath 'drift-snapshot.json';$current|ConvertTo-Json -Depth 8|Set-Content $path -Encoding UTF8
  $current
}
function Write-Html{
  $json=Get-ChildItem $OutputPath -Filter *.json|Sort-Object Name|%{"<li><a href='$($_.Name)'>$($_.BaseName)</a></li>"}
  $html=@"
<!doctype html><html><head><meta charset='utf-8'><title>System 8 M365 Governance</title><style>body{background:#050608;color:#d8e4e2;font:15px Segoe UI,Arial;margin:40px;max-width:1100px}h1,h2{color:#32f5c8}code,a{color:#8cfce5}.card{border:1px solid #263737;background:#0a0e0f;padding:22px;margin:18px 0}li{margin:8px 0}</style></head><body><h1>System 8 · Microsoft 365 Governance Evidence</h1><div class='card'><b>Captured:</b> $(Get-Date -Format o)<br><b>Tenant:</b> $((Get-MgContext).TenantId)<br><b>Mode:</b> read-only delegated assessment</div><h2>Evidence</h2><ul>$($json -join "`n")</ul><p>Carry the zero.</p></body></html>
"@
  $html|Set-Content (Join-Path $OutputPath 'index.html') -Encoding UTF8
}
function Doctor{
  [pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();GraphModule=[bool](Get-Module -ListAvailable Microsoft.Graph.Authentication);Connected=[bool](Get-MgContext -ErrorAction SilentlyContinue);OutputPath=$OutputPath;StaleDays=$StaleDays}|Format-List
}

if($Command -eq 'doctor'){Doctor;exit}
Connect-S8Graph
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
switch($Command){
 'entra'{Get-EntraPosture|Out-Null}
 'apps'{Get-AppExposure|Out-Null}
 'ca'{Get-CAPosture|Out-Null}
 'stale'{Get-StaleIdentity|Out-Null}
 'teams'{Get-TeamsGovernance|Out-Null}
 'sharepoint'{Get-SharePointReadiness|Out-Null}
 'drift'{Get-DriftSnapshot|Out-Null}
 'full'{Get-EntraPosture|Out-Null;Get-AppExposure|Out-Null;Get-CAPosture|Out-Null;Get-StaleIdentity|Out-Null;Get-TeamsGovernance|Out-Null;Get-SharePointReadiness|Out-Null;Get-DriftSnapshot|Out-Null}
}
Write-Html
[pscustomobject]@{Command=$Command;Output=$OutputPath;Tenant=(Get-MgContext).TenantId;Completed=(Get-Date -Format o)}|Format-List
