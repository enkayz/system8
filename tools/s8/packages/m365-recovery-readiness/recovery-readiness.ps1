[CmdletBinding()]
param([Parameter(Position=0)][ValidateSet('assess','identity','applications','full','doctor')][string]$Command='full',[string]$OutputPath=(Join-Path $PWD ('s8-recovery-readiness-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))),[switch]$InstallDependencies)
$modulePath=Join-Path $PSScriptRoot 'S8.M365.psm1';if(-not(Test-Path $modulePath)){$modulePath=Join-Path (Split-Path $PSScriptRoot) '_shared\S8.M365.psm1'};Import-Module $modulePath -Force;Initialize-S8Runtime
if($Command-eq'doctor'){[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();GraphModule=[bool](Get-Module -ListAvailable Microsoft.Graph.Authentication);OutputPath=$OutputPath}|Format-List;exit}
$evidence=New-Object System.Collections.ArrayList;$context=Connect-S8Graph @('Directory.Read.All','Policy.Read.All','Application.Read.All','Domain.Read.All','AuditLog.Read.All') -InstallDependencies:$InstallDependencies
$roles=Invoke-S8Collection 'Directory roles and members' {Get-S8GraphCollection 'https://graph.microsoft.com/v1.0/directoryRoles?$expand=members'} $evidence;$ca=Invoke-S8Collection 'Conditional Access policies' {Get-S8GraphCollection 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'} $evidence;$domains=Invoke-S8Collection 'Domains' {Get-S8GraphCollection 'https://graph.microsoft.com/v1.0/domains'} $evidence;$apps=Invoke-S8Collection 'Application credentials' {Get-S8GraphCollection 'https://graph.microsoft.com/v1.0/applications?$select=id,appId,displayName,passwordCredentials,keyCredentials'} $evidence
$admins=@();foreach($role in $roles){foreach($member in @($role.members)){$admins+=[pscustomobject]@{Role=$role.displayName;DisplayName=$member.displayName;UPN=$member.userPrincipalName;UserId=$member.id;CloudOnly=[bool](-not$member.onPremisesSyncEnabled);EmergencyNameSignal=[bool]("$($member.displayName) $($member.userPrincipalName)"-match'emergency|break.?glass')}}};$ga=@($admins|Where-Object Role-eq'Global Administrator')
$excluded=@();foreach($policy in $ca){foreach($id in @($policy.conditions.users.excludeUsers)){$excluded+=[pscustomobject]@{Policy=$policy.displayName;State=$policy.state;ExcludedObjectId=$id}}}
$candidateIds=@($ga|Where-Object{$_.CloudOnly -and $_.EmergencyNameSignal}|ForEach-Object UserId)
$coverage=@($candidateIds|ForEach-Object{
 $id=$_
 $excludedCount=@($excluded|Where-Object{$_.ExcludedObjectId -eq $id -and $_.State -eq 'enabled'}).Count
 $enabledCount=@($ca|Where-Object{$_.state -eq 'enabled'}).Count
 [pscustomobject]@{UserId=$id;ExcludedFromEnabledPolicies=$excludedCount;EnabledPolicies=$enabledCount;Status='Candidate only - test sign-in and authentication method manually'}
})
$credentials=@();foreach($app in $apps){
 foreach($secret in @($app.passwordCredentials)){$credentials+=[pscustomobject]@{Application=$app.displayName;AppId=$app.appId;Type='Secret';Credential=$secret.displayName;End=$secret.endDateTime;DaysRemaining=[math]::Floor(([datetime]$secret.endDateTime-(Get-Date)).TotalDays)}}
 foreach($cert in @($app.keyCredentials)){$credentials+=[pscustomobject]@{Application=$app.displayName;AppId=$app.appId;Type='Certificate';Credential=$cert.displayName;End=$cert.endDateTime;DaysRemaining=[math]::Floor(([datetime]$cert.endDateTime-(Get-Date)).TotalDays)}}
}
$coveredCandidates=@($coverage|Where-Object{$_.ExcludedFromEnabledPolicies -gt 0}).Count;$verifiedDefaults=@($domains|Where-Object{$_.isVerified -and $_.isDefault}).Count;$expiringCredentials=@($credentials|Where-Object{$_.DaysRemaining -lt 30}).Count
$findings=@(
 [pscustomobject]@{Check='Global Administrator redundancy';Status=if($ga.Count-ge2){'Pass'}else{'Fail'};Evidence="$($ga.Count) active Global Administrators";Action='Maintain sufficient privileged recovery coverage with least privilege'},
 [pscustomobject]@{Check='Emergency access candidates';Status=if($candidateIds.Count-ge2){'Review'}else{'ManualEvidenceRequired'};Evidence="$($candidateIds.Count) cloud-only Global Administrators matched naming signals";Action='Explicitly identify at least two emergency accounts; naming inference is not proof'},
 [pscustomobject]@{Check='Conditional Access exclusions';Status=if($coveredCandidates-ge2){'Review'}else{'ManualEvidenceRequired'};Evidence="$coveredCandidates inferred candidates appear in enabled-policy exclusions";Action='Validate exclusions across every blocking/restrictive policy and perform a controlled sign-in drill'},
 [pscustomobject]@{Check='Verified default domain';Status=if($verifiedDefaults){'Pass'}else{'Fail'};Evidence="$verifiedDefaults verified default domains";Action='Confirm domain and DNS recovery ownership'},
 [pscustomobject]@{Check='Application credential runway';Status=if($expiringCredentials){'Review'}else{'Pass'};Evidence="$expiringCredentials credentials expired or expiring within 30 days";Action='Assign owners and rotate before outage risk materializes'}
)
New-Item -ItemType Directory $OutputPath -Force|Out-Null;Export-S8Data $OutputPath 'recovery-findings' $findings;Export-S8Data $OutputPath 'privileged-admins' $admins;Export-S8Data $OutputPath 'conditional-access-exclusions' $excluded;Export-S8Data $OutputPath 'emergency-candidate-coverage' $coverage;Export-S8Data $OutputPath 'application-credential-runway' $credentials;Complete-S8Run $OutputPath 'm365-recovery-readiness' $Command $context $evidence;Write-S8Report $OutputPath 'System 8 · M365 Recovery Readiness' ([ordered]@{'Recovery findings'=$findings;'Privileged administrators'=$admins;'Emergency candidate coverage'=$coverage;'Application credential runway'=$credentials;'Collection evidence'=@($evidence)})
[pscustomobject]@{Output=$OutputPath;Findings=$findings.Count;GlobalAdmins=$ga.Count;EmergencyCandidates=$candidateIds.Count;Mode='Read-only recovery posture; controlled drills remain manual'}|Format-List
