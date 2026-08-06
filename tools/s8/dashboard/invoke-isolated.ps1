Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = $env:S8_TARGET_SCRIPT
if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw 'The isolated System 8 runner did not receive a valid script path.' }
$scriptArguments = @($args)
$toolchainRoot = $PSScriptRoot
$moduleRoot = Join-Path $toolchainRoot 'Modules'
$powerShellModuleRoot = Join-Path $toolchainRoot 'PowerShell\Modules'
$env:S8_TOOLCHAIN_ROOT = $toolchainRoot
$env:PSModulePath = "$moduleRoot;$powerShellModuleRoot"
$env:POWERSHELL_TELEMETRY_OPTOUT = '1'
$env:POWERSHELL_UPDATECHECK = 'Off'

& ([IO.Path]::GetFullPath($scriptPath)) @scriptArguments
$scriptSucceeded = $?
$nativeExitCode = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
if ($nativeExitCode) { exit $nativeExitCode }
if (-not $scriptSucceeded) { exit 1 }
