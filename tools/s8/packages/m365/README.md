# System 8 Microsoft 365 Toolkit

Read-only Microsoft 365 assessment utilities with normalized JSON/CSV evidence and a dark System 8 HTML report.

## Install

```powershell
s8 install m365
```

## Commands

```powershell
s8m365 inventory -InstallDependencies
s8m365 licenses
s8m365 labels
s8m365 sharing
s8m365 full
s8m365 doctor
```

## Assessment surfaces

### Inventory

- tenant and verified-domain metadata
- users, account state, user type and sign-in evidence
- groups, visibility and group type
- activated directory roles

### Licensing

- subscribed SKU capacity and consumption
- utilization percentage and available units
- enabled member accounts without licences
- disabled accounts retaining licence assignments
- per-user SKU IDs for further mapping

### Information protection

- sensitivity-label discovery
- active-label readiness
- label policy API availability
- explicit collection errors where tenant permissions or API availability differ

### Collaboration and sharing

- SharePoint site inventory
- guest identities and account state
- external-domain concentration
- Microsoft 365 group visibility

## Evidence model

Every execution creates a timestamped evidence directory containing:

```text
manifest.json
report.html
*.json
*.csv
```

No configuration is modified. The package requests delegated Microsoft Graph read scopes and records partial-collection errors instead of fabricating results.
