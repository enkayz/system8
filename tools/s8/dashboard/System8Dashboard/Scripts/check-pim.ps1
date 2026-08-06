[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$SuggestedRole
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

function Write-PimResult {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [string[]]$EligibleRoles = @(),
        [Parameter(Mandatory = $true)][string]$Message
    )

    [pscustomobject]@{
        Status = $Status
        EligibleRoles = @($EligibleRoles)
        Message = $Message
    } | ConvertTo-Json -Compress -Depth 4
}

try {
    if (-not $env:S8_TOOLCHAIN_ROOT) {
        Write-PimResult -Status 'Unknown' -Message 'The isolated System 8 toolchain is not active. Re-run the dashboard installer.'
        exit 0
    }

    $expectedRoot = [IO.Path]::GetFullPath((Join-Path $env:S8_TOOLCHAIN_ROOT 'Modules'))
    $authentication = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $authentication -or -not [IO.Path]::GetFullPath($authentication.Path).StartsWith($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Write-PimResult -Status 'Unknown' -Message 'The isolated Microsoft Graph module is missing or invalid. Re-run the dashboard installer.'
        exit 0
    }

    Import-Module $authentication.Path -ErrorAction Stop
    $requiredScope = 'RoleEligibilitySchedule.Read.Directory'
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context -or $requiredScope -notin @($context.Scopes)) {
        Connect-MgGraph -Scopes @('User.Read', $requiredScope) -ContextScope CurrentUser -NoWelcome | Out-Null
    }

    $uri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleInstances/filterByCurrentUser(on='principal')?`$expand=roleDefinition"
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    $eligible = @($response.value | ForEach-Object { $_.roleDefinition.displayName } | Where-Object { $_ } | Sort-Object -Unique)
    $matches = @($eligible | Where-Object { $candidate = $_; @($SuggestedRole | Where-Object { $_ -eq $candidate }).Count -gt 0 })

    if ($matches.Count -gt 0) {
        Write-PimResult -Status 'Found' -EligibleRoles $matches -Message 'A matching eligible PIM role was found.'
    }
    elseif ($eligible.Count -gt 0) {
        Write-PimResult -Status 'NoMatch' -EligibleRoles $eligible -Message 'Eligible PIM roles were found, but none match the least-privilege suggestion.'
    }
    else {
        Write-PimResult -Status 'NoMatch' -Message 'No eligible Microsoft Entra PIM role was returned for the current user.'
    }
}
catch {
    $message = $_.Exception.Message -replace '[\r\n]+', ' '
    if ($message.Length -gt 400) { $message = $message.Substring(0, 400) + '…' }
    Write-PimResult -Status 'Unknown' -Message $message
}
