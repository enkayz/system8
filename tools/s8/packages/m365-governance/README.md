# System 8 Microsoft 365 Governance Toolkit

Read-only Microsoft Graph assessment commands for operational governance and migration discovery.

## Install

```powershell
s8 install m365-governance
```

## Commands

```powershell
s8gov entra
s8gov apps
s8gov ca
s8gov stale -StaleDays 90
s8gov teams
s8gov sharepoint
s8gov drift
s8gov full
s8gov doctor
```

## Assessment surfaces

- Entra tenant, domains, directory roles and privileged membership
- enterprise applications, delegated consent and high-privilege scopes
- Conditional Access policy state and control coverage
- stale users, guests, licensed dormant accounts and hybrid identities
- Teams owner/member posture and ownerless or single-owner teams
- SharePoint site inventory and stale-site candidates
- point-in-time governance snapshots suitable for drift comparison

Every run emits JSON, CSV and a System 8 HTML evidence index. Collection errors are preserved as evidence rather than silently discarded.
