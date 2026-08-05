[CmdletBinding()]
param(
 [Parameter(Position=0)][ValidateSet('capture','compare','doctor')][string]$Command='capture',
 [string]$OutputPath=(Join-Path $PWD ('s8-tenant-diff-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))),
 [string]$BaselinePath,[string]$CurrentPath,[switch]$InstallDependencies
)
$modulePath=Join-Path $PSScriptRoot 'S8.M365.psm1';if(-not(Test-Path $modulePath)){$modulePath=Join-Path (Split-Path $PSScriptRoot) '_shared\S8.M365.psm1'};Import-Module $modulePath -Force;Initialize-S8Runtime
if($Command -eq 'doctor'){[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();GraphModule=[bool](Get-Module -ListAvailable Microsoft.Graph.Authentication);OutputPath=$OutputPath}|Format-List;exit}
function Flatten($name,$items,$key){@($items|ForEach-Object{$id=[string]$_.$key;[pscustomobject]@{Collection=$name;Key=$id;Fingerprint=($_|ConvertTo-Json -Depth 20 -Compress);Value=$_}})}
if($Command -eq 'compare'){
 if(-not $BaselinePath -or -not $CurrentPath){throw 'compare requires -BaselinePath and -CurrentPath.'}
 New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
 $before=@(Get-Content $BaselinePath -Raw|ConvertFrom-Json);$after=@(Get-Content $CurrentPath -Raw|ConvertFrom-Json)
 $b=@{};$a=@{};foreach($x in $before){$b["$($x.Collection)|$($x.Key)"]=$x};foreach($x in $after){$a["$($x.Collection)|$($x.Key)"]=$x}
 $diff=@();foreach($k in @($b.Keys+$a.Keys|Sort-Object -Unique)){$status=if(-not $b.ContainsKey($k)){'Added'}elseif(-not $a.ContainsKey($k)){'Removed'}elseif($b[$k].Fingerprint -ne $a[$k].Fingerprint){'Changed'}else{'Unchanged'};if($status-ne'Unchanged'){$diff+=[pscustomobject]@{Collection=($k-split'\|')[0];Key=($k-split'\|',2)[1];Change=$status;Before=if($b.ContainsKey($k)){$b[$k].Fingerprint}else{$null};After=if($a.ContainsKey($k)){$a[$k].Fingerprint}else{$null}}}}
 Export-S8Data $OutputPath 'tenant-diff' $diff;Write-S8Report $OutputPath 'System 8 · M365 Tenant Diff' ([ordered]@{'Changes'=$diff}) 'Offline, read-only comparison';$diff|Group-Object Change|Select-Object Name,Count|Format-Table;exit
}
$evidence=New-Object System.Collections.ArrayList;$context=Connect-S8Graph @('Directory.Read.All','Policy.Read.All','Application.Read.All','Organization.Read.All','Group.Read.All') -InstallDependencies:$InstallDependencies
$collections=[ordered]@{
 Organization=@('https://graph.microsoft.com/v1.0/organization?$select=id,displayName,tenantType,verifiedDomains','id');
 Domains=@('https://graph.microsoft.com/v1.0/domains','id');
 ConditionalAccess=@('https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies','id');
 Applications=@('https://graph.microsoft.com/v1.0/servicePrincipals?$select=id,appId,displayName,accountEnabled,servicePrincipalType,publisherName,verifiedPublisher','id');
 Groups=@('https://graph.microsoft.com/v1.0/groups?$select=id,displayName,groupTypes,securityEnabled,mailEnabled,visibility','id')
}
$snapshot=@();foreach($name in $collections.Keys){$spec=$collections[$name];$data=Invoke-S8Collection $name {Get-S8GraphCollection $spec[0]} $evidence;$snapshot+=Flatten $name $data $spec[1]}
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null;Export-S8Data $OutputPath 'tenant-snapshot' $snapshot;Complete-S8Run $OutputPath 'm365-tenant-diff' capture $context $evidence;Write-S8Report $OutputPath 'System 8 · M365 Tenant Snapshot' ([ordered]@{'Snapshot records'=$snapshot;'Collection evidence'=@($evidence)})
[pscustomobject]@{Output=$OutputPath;Snapshot=(Join-Path $OutputPath 'tenant-snapshot.json');Records=$snapshot.Count;Mode='Read-only'}|Format-List
