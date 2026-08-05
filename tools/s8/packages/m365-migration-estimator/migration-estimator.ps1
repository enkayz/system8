[CmdletBinding()]
param(
 [Parameter(Position=0)][ValidateSet('template','estimate','doctor')][string]$Command='estimate',
 [string]$InputPath,[string]$OutputPath=(Join-Path $PWD ('s8-migration-estimator-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))),
 [decimal]$HourlyRate=0,[decimal]$ThroughputGBPerDay=250,[int]$WorkHoursPerDay=8
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';if($PSVersionTable.PSVersion.Major-lt5){throw'PowerShell 5.1 or 7+ required.'}
function Export-Data($name,$data){@($data)|ConvertTo-Json -Depth 20|Set-Content (Join-Path $OutputPath "$name.json") -Encoding UTF8;@($data)|Export-Csv (Join-Path $OutputPath "$name.csv") -NoTypeInformation -Encoding UTF8}
if($Command-eq'doctor'){[pscustomobject]@{PowerShell=$PSVersionTable.PSVersion.ToString();OutputPath=$OutputPath;HourlyRate=$HourlyRate;ThroughputGBPerDay=$ThroughputGBPerDay}|Format-List;exit}
New-Item -ItemType Directory $OutputPath -Force|Out-Null
if($Command-eq'template'){
 $template=@([pscustomobject]@{Workload='SharePoint';Name='Intranet';Objects=25;SizeGB=500;Complexity='Medium';UnsupportedItems=3;PermissionSets=80;Users=400;Notes='Example - replace with discovery data'},[pscustomobject]@{Workload='FileShare';Name='Department shares';Objects=120000;SizeGB=1800;Complexity='High';UnsupportedItems=0;PermissionSets=300;Users=400;Notes='Example - replace with discovery data'})
 $template|Export-Csv (Join-Path $OutputPath 'migration-input-template.csv') -NoTypeInformation -Encoding UTF8;Write-Host "Template: $(Join-Path $OutputPath 'migration-input-template.csv')" -ForegroundColor Green;exit
}
if(-not$InputPath){throw 'estimate requires -InputPath. Run template first to create an example CSV.'};if(-not(Test-Path $InputPath)){throw "Input not found: $InputPath"}
$input=@(Import-Csv $InputPath);$rows=@();foreach($item in $input){
 $factor=switch($item.Complexity){'Low'{1.0}'Medium'{1.35}'High'{1.8}'Critical'{2.4}default{1.35}}
 $objects=[decimal]$item.Objects;$size=[decimal]$item.SizeGB;$unsupported=[decimal]$item.UnsupportedItems;$permissions=[decimal]$item.PermissionSets;$users=[decimal]$item.Users
 $objectBatches=[math]::Min(80,[math]::Ceiling($objects/1000)*2);$discovery=[math]::Ceiling(4+$objectBatches+$permissions*.03);$remediation=[math]::Ceiling(($unsupported*4+$permissions*.04)*$factor);$execution=[math]::Ceiling(($size/$ThroughputGBPerDay)*$WorkHoursPerDay*$factor);$validation=[math]::Ceiling((4+[math]::Min(40,[math]::Ceiling($objects/5000))+[math]::Sqrt([double]$users))*$factor);$pm=[math]::Ceiling(($discovery+$remediation+$execution+$validation)*.15);$hours=$discovery+$remediation+$execution+$validation+$pm
 $risk=if($factor-ge2-or$unsupported-gt20){'Critical'}elseif($factor-ge1.8-or$unsupported-gt5){'High'}elseif($factor-ge1.35){'Medium'}else{'Low'}
 $rows+=[pscustomobject]@{Workload=$item.Workload;Name=$item.Name;Objects=$objects;SizeGB=$size;Complexity=$item.Complexity;Risk=$risk;DiscoveryHours=$discovery;RemediationHours=$remediation;MigrationHours=$execution;ValidationHours=$validation;ProjectHours=$pm;TotalHours=$hours;EstimatedCost=if($HourlyRate-gt0){$hours*$HourlyRate}else{$null};TransferDays=[math]::Ceiling($size/$ThroughputGBPerDay);Assumptions="Throughput $ThroughputGBPerDay GB/day; $WorkHoursPerDay work hours/day; customer input not live telemetry"}
}
$summary=@([pscustomobject]@{Workloads=$rows.Count;TotalSizeGB=($rows|Measure-Object SizeGB -Sum).Sum;TotalHours=($rows|Measure-Object TotalHours -Sum).Sum;EstimatedCost=if($HourlyRate-gt0){($rows|Measure-Object EstimatedCost -Sum).Sum}else{$null};HourlyRate=if($HourlyRate-gt0){$HourlyRate}else{$null};EstimatedElapsedWorkDays=[math]::Ceiling((($rows|Measure-Object TotalHours -Sum).Sum)/$WorkHoursPerDay);Confidence='ROM estimate; validate with pilot and source-system telemetry';Mode='Offline and non-destructive'})
Export-Data 'migration-estimate' $rows;Export-Data 'migration-summary' $summary;Export-Data 'migration-input-evidence' $input
$tables=($summary|ConvertTo-Html -Fragment)+($rows|ConvertTo-Html -Fragment);@"
<!doctype html><html><head><meta charset='utf-8'><title>System 8 Migration Estimate</title><style>body{background:#050608;color:#d8e4e2;font:14px Segoe UI;margin:32px}h1,h2{color:#32f5c8}table{border-collapse:collapse;width:100%;margin:20px 0}th,td{border:1px solid #263737;padding:8px;text-align:left}th{color:#32f5c8}</style></head><body><h1>System 8 · M365 Migration Estimator</h1><p>Generated $(Get-Date -Format o) · Rough order of magnitude · No tenant changes</p>$tables</body></html>
"@|Set-Content (Join-Path $OutputPath 'index.html') -Encoding UTF8
[pscustomobject]@{Output=$OutputPath;Workloads=$rows.Count;TotalHours=$summary[0].TotalHours;EstimatedCost=$summary[0].EstimatedCost;Mode='Offline and non-destructive'}|Format-List
