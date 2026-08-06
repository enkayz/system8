# System 8 Dashboard

The System 8 Dashboard is the non-admin Windows front end for the Microsoft 365 operator toolkit. It runs each package with the signed-in user's existing Windows and Microsoft 365 access, keeps partial collection failures as evidence, and never bypasses tenant authorization.

## Install for the current Windows user

Run from Windows PowerShell 5.1 or PowerShell 7. Administrator rights are not required.

```powershell
& ([scriptblock]::Create((irm https://github.com/enkayz/system8/releases/download/dashboard-v1.0.0/install-dashboard.ps1)))
```

The versioned installer downloads the self-contained x64 dashboard archive, validates its published SHA-256 checksum, stages and validates the replacement before switching, installs it under `%LOCALAPPDATA%\System8\dashboard`, adds a Start menu shortcut, and opens it. The same archive installs System 8's pinned portable PowerShell 7.6.4 and Microsoft Graph 2.38.1 modules under `%LOCALAPPDATA%\System8\Toolchain`. Tool runs reset `PSModulePath` inside that private runtime, so Graph modules from the Windows profile or machine are not loaded. The installer does not request UAC, change machine PATH, or write outside the current user profile.

Operator packages are shipped in one immutable `System8Packages-1.0.0.zip` release asset. The dashboard carries that archive and the stable manifest locally, verifies its exact SHA-256 before every install, and never downloads executable package content from the mutable `main` branch. Existing administrators can also install the dashboard through `s8 install dashboard`; the package-manager adapter is checksum-locked to the release installer archive.

Preview the install without changing anything:

```powershell
& ([scriptblock]::Create((irm https://github.com/enkayz/system8/releases/download/dashboard-v1.0.0/install-dashboard.ps1))) -WhatIf
```

Remove the app from the current user profile:

```powershell
& ([scriptblock]::Create((irm https://github.com/enkayz/system8/releases/download/dashboard-v1.0.0/install-dashboard.ps1))) -Uninstall
```

Installed operator command-line tools share the private runtime, so the toolchain is retained by default. Remove both the dashboard and toolchain only when those commands are no longer needed:

```powershell
& ([scriptblock]::Create((irm https://github.com/enkayz/system8/releases/download/dashboard-v1.0.0/install-dashboard.ps1))) -Uninstall -RemoveToolchain
```

## Access behavior

- Tools run in the current user context and request only their documented delegated read scopes.
- PowerShell and Microsoft Graph dependencies come from the version-locked System 8 toolchain, not profile or machine module locations.
- Successful and failed collections remain visible in the output and evidence files.
- When access is denied, the dashboard maps the failure to a least-privilege role and creates a reusable Markdown request.
- **Check PIM** uses the current Microsoft Graph context to look for matching eligible Entra roles. If it finds one, it copies the evidence-backed justification and opens My roles for a time-bound activation request.
- If PIM cannot be checked, has no match, or Graph PowerShell is unavailable, the dashboard opens a pre-filled administrator or service-desk email instead.
- No role is activated and no email is sent silently; the signed-in user confirms both actions.

## Operator workflow

1. Choose an installed package or select **Install for me** to place it under `%LOCALAPPDATA%\System8`.
2. Run a command such as `doctor` or `full`.
3. Open the evidence folder for CSV, JSON and HTML output.
4. If a collection is denied, select **Request the access I need**, then use **Check PIM** or the administrator email route.
5. Use **Get support** at any point to open the System 8 support issue form.

## Build

```powershell
dotnet test .\System8Dashboard.Core.Tests\System8Dashboard.Core.Tests.csproj -c Release
dotnet build .\System8Dashboard\System8Dashboard.csproj -c Release -p:Platform=x64
dotnet publish .\System8Dashboard\System8Dashboard.csproj -c Release -p:Platform=x64 -p:RuntimeIdentifier=win-x64 -p:WindowsPackageType=None -p:WindowsAppSDKSelfContained=true -p:EnableMsixTooling=false -p:SelfContained=true
.\build-toolchain.ps1 -Destination .\System8Dashboard\bin\Release\Toolchain
.\verify-release.ps1 -ArtifactDirectory <release-artifact-directory>
```

`toolchain.lock.json` pins every upstream URL and SHA-256 hash. The builder downloads archives directly instead of trusting `Install-Module`, PowerShellGet, or a pre-existing module installation. `verify-release.ps1` validates the dashboard archive, its checksum, the operator bundle, every stable manifest entry, the package-manager adapter and the bundled private toolchain before publication; add `-Published` after the GitHub release is live.

The project targets WinUI 3 on .NET 10. The supported public release is the non-admin, self-contained ZIP used by the PowerShell installer. A self-signed MSIX is retained as build/signature evidence only: Windows does not accept its current-user certificate as a public non-admin trust path, and it is not published as a supported installer until a managed publisher pipeline can bootstrap the same private toolchain.
