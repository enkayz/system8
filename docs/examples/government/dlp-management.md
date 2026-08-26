# Government DLP management example

> **EXAMPLE — NOT PRODUCTION INSTRUCTIONS**
>
> This example describes a Microsoft Purview Data Loss Prevention (DLP) management pattern for a government tenant. It does not define any agency's policy, legal obligations, information classifications or approved control configuration. Policy creation, enforcement and deletion require tenant-owner, records, privacy, cyber and change approval.

## Outcome

Move from an evidenced information-risk scenario to a simulated, measured and approved DLP control without silently blocking legitimate government work.

## Example scenario

A public land-asset workflow may contain personal information, commercial negotiations, culturally or environmentally sensitive material, legal advice and cross-agency documents. Before configuring DLP, confirm:

- authoritative classification and handling rules;
- in-scope users, agencies, guests, sites, teams, devices and endpoints;
- lawful sharing pathways and approved exceptions;
- records retention and investigation requirements;
- operational owners and incident response responsibilities;
- licensing and Microsoft Purview workload coverage.

## Read-only baseline

The following commands inventory policy metadata after approved Microsoft Purview PowerShell authentication. They do not create or enforce a policy.

```powershell
Connect-IPPSSession

$Evidence = Join-Path $PWD ("dlp-evidence-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $Evidence | Out-Null

Get-DlpCompliancePolicy |
  Select-Object Name, Mode, Enabled, Workload, DistributionStatus |
  Export-Csv (Join-Path $Evidence 'dlp-policies.csv') -NoTypeInformation

Get-DlpComplianceRule |
  Select-Object Name, Policy, Disabled, Priority, ContentContainsSensitiveInformation |
  Export-Csv (Join-Path $Evidence 'dlp-rules.csv') -NoTypeInformation
```

Record authentication identity, delegated role, timestamp, tenant ID, collection failures and the command/module versions. Do not export matched sensitive content into an uncontrolled project folder.

## Policy design record

| Field | Example planning entry |
|---|---|
| Risk statement | Unapproved disclosure of restricted land-asset working documents to external recipients. |
| Locations | Named SharePoint/Teams pilot locations only; tenant-wide scope requires separate approval. |
| Detection | Approved sensitivity labels and validated sensitive-information types. |
| Initial mode | Simulation with policy tips disabled until false-positive review. |
| User impact | No blocking during evidence collection. |
| Exceptions | Named business process, owner, expiry and review date; no permanent informal bypass. |
| Alerts | Approved SOC/compliance queue with severity and response SLA. |
| Evidence | Aggregate match counts, false-positive reasons, workload and rule identifiers. |
| Acceptance | Privacy, records, cyber, legal, service owner and change authority. |

## Staged management pattern

1. **Discover:** establish classification, data flows, existing labels/policies, sharing routes and legitimate exceptions.
2. **Design:** create a narrow rule hypothesis with explicit locations, conditions, actions, notices and alert ownership.
3. **Simulation:** run Microsoft Purview simulation against an approved pilot scope. Collect aggregate evidence and false-positive/false-negative samples through approved handling channels.
4. **Tune:** adjust conditions and exceptions; record every departure and expiry.
5. **Notify:** enable policy tips or user notifications only after content and support routes are approved.
6. **Enforce:** move to blocking or override controls incrementally, with named cohorts and acceptance criteria.
7. **Operate:** review incidents, overrides, stale exceptions, rule effectiveness and Microsoft service changes on a defined cadence.

## Minimum evidence and metrics

- items evaluated and matches by rule/workload;
- false-positive and false-negative review outcomes;
- policy-tip views and user-reported issues;
- overrides by reason, owner and expiry;
- blocked events and incident disposition;
- processing/distribution errors;
- unresolved workload gaps and unsupported data paths;
- change approval and release timestamps.

## Failure and rollback

- Pause progression if simulation coverage is incomplete or false positives exceed the approved threshold.
- For an enforcement regression, return the affected policy to the previously approved simulation/audit mode rather than deleting evidence.
- Restore prior scope, actions and exception values from the approved configuration snapshot.
- Confirm policy distribution status and run representative user journeys after rollback.
- Preserve alerts, incidents, overrides and change evidence under approved records handling.
- Policy deletion or broad disablement requires explicit tenant-owner and change approval.
