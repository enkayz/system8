[CmdletBinding()]
param(
  [Parameter(Position=0)][ValidateSet('analyze','users','skus','savings','full','doctor')][string]$Command='full',
  [string]$OutputPath=(Join-Path $PWD ('s8-license-optimizer-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))),
  [string]$PriceFile,
  [int]$DormantDays=90,
  [switch]$InstallDependencies
)
$modulePath=Join-Path $PSScriptRoot 'S8.M365.psm1';if(-not(Test-Path $modulePath)){$modulePath=Join-Path (Split-Path $PSScriptRoot) '_shared\S8.M365.psm1'};Import-Module $modulePath -Force
Initialize-S8Runtime
$scopes=@('User.Read.All','Organization.Read.All','AuditLog.Read.All','Directory.Read.All')
if($Command -eq 'doctor') {[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();GraphModule=[bool](Get-Module -ListAvailable Microsoft.Graph.Authentication);PriceFile=$PriceFile;OutputPath=$OutputPath}|Format-List;exit}
$evidence=New-Object System.Collections.ArrayList
$context=Connect-S8Graph $scopes -InstallDependencies:$InstallDependencies
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$skus=Invoke-S8Collection 'Subscribed SKUs' {Get-S8GraphCollection 'https://graph.microsoft.com/v1.0/subscribedSkus'} $evidence
$users=Invoke-S8Collection 'Users and license details' {Get-S8GraphCollection 'https://graph.microsoft.com/beta/users?$select=id,displayName,userPrincipalName,accountEnabled,userType,assignedLicenses,assignedPlans,signInActivity,createdDateTime'} $evidence
$prices=@{}
if($PriceFile){Import-Csv $PriceFile|ForEach-Object{$prices[$_.SkuPartNumber]=[decimal]$_.MonthlyUnitPrice}}
$skuMap=@{};foreach($sku in $skus){$skuMap[[string]$sku.skuId]=$sku.skuPartNumber}
$userRows=@($users|ForEach-Object{
  $last=$_.signInActivity.lastSuccessfulSignInDateTime;if(-not $last){$last=$_.signInActivity.lastSignInDateTime}
  $names=@($_.assignedLicenses|ForEach-Object{$skuMap[[string]$_.skuId]})
  [pscustomobject]@{DisplayName=$_.displayName;UPN=$_.userPrincipalName;Enabled=$_.accountEnabled;UserType=$_.userType;Created=$_.createdDateTime;LastSignIn=$last;DaysSinceSignIn=if($last){[math]::Floor(((Get-Date)-[datetime]$last).TotalDays)}else{$null};NeverSignedIn=[bool](-not $last);LicenseCount=$names.Count;Licenses=($names -join ';');CandidateReason=if(-not $_.accountEnabled -and $names.Count){'Disabled licensed account'}elseif($names.Count -and ((-not $last)-or((Get-Date)-[datetime]$last).TotalDays -ge $DormantDays)){'Dormant licensed account'}else{''}}
})
$skuRows=@($skus|ForEach-Object{[pscustomobject]@{SkuPartNumber=$_.skuPartNumber;SkuId=$_.skuId;Enabled=$_.prepaidUnits.enabled;Consumed=$_.consumedUnits;Available=([int]$_.prepaidUnits.enabled-[int]$_.consumedUnits);UtilizationPct=if($_.prepaidUnits.enabled){[math]::Round(100*[int]$_.consumedUnits/[int]$_.prepaidUnits.enabled,1)}else{0};MonthlyUnitPrice=if($prices.ContainsKey($_.skuPartNumber)){$prices[$_.skuPartNumber]}else{$null}}})
$candidates=@($userRows|Where-Object CandidateReason)
$savings=@($candidates|ForEach-Object{$row=$_;$monthly=0;foreach($name in @($row.Licenses -split ';')){if($prices.ContainsKey($name)){$monthly+=$prices[$name]}};[pscustomobject]@{UPN=$row.UPN;Reason=$row.CandidateReason;Licenses=$row.Licenses;EstimatedMonthlySavings=$monthly;EstimatedAnnualSavings=12*$monthly;PricingStatus=if($PriceFile){'Customer-supplied price file'}else{'Not calculated - provide -PriceFile'}}})
$sections=[ordered]@{'SKU utilization'=$skuRows;'User license posture'=$userRows;'Optimization candidates'=$candidates;'Estimated savings'=$savings;'Collection evidence'=@($evidence)}
Export-S8Data $OutputPath 'sku-utilization' $skuRows;Export-S8Data $OutputPath 'user-license-posture' $userRows;Export-S8Data $OutputPath 'optimization-candidates' $candidates;Export-S8Data $OutputPath 'estimated-savings' $savings
Complete-S8Run $OutputPath 'm365-license-optimizer' $Command $context $evidence
Write-S8Report $OutputPath 'System 8 · M365 License Optimizer' $sections
[pscustomobject]@{Output=$OutputPath;Users=$userRows.Count;Candidates=$candidates.Count;EstimatedAnnualSavings=($savings|Measure-Object EstimatedAnnualSavings -Sum).Sum;Mode='Read-only'}|Format-List
