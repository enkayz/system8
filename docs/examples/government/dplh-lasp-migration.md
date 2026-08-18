# DPLH LASP migration planning example

> **EXAMPLE — NOT PRODUCTION INSTRUCTIONS**
>
> This is a synthetic planning example for a possible Department of Planning, Lands and Heritage (DPLH) Land Asset Sales Program (LASP) migration. It is not DPLH data, does not identify the authoritative procurement or production design, and is not approved for execution. Validate the source platform, records obligations, security classification, integrations, volumes and acceptance criteria with authorised DPLH representatives.

## Purpose

Use the offline `m365-migration-estimator` to turn a provisional LASP workload inventory into a transparent first-pass effort model. The output supports discovery and migration-rehearsal planning; it is not a fixed quote or a migration engine.

## Assumptions to confirm

| ID | Planning assumption | Evidence required before use |
|---|---|---|
| LASP-01 | The source includes a customised SharePoint 2013 application. | Farm inventory, solution catalogue, IIS/ULS evidence and owner confirmation. |
| LASP-02 | Documents, lists, workflow state, permissions and audit-relevant metadata require preservation. | Records schedule, data dictionary, permission export and migration acceptance criteria. |
| LASP-03 | Cross-agency access requires explicit segregation and delegated ownership. | Agency/role matrix, identity model and approved target architecture. |
| LASP-04 | GIS, property identifiers and external interfaces require reconciliation rather than blind copy. | Interface contracts, authoritative-system owners and balancing rules. |
| LASP-05 | Synthetic sizes and counts in the sample CSV are placeholders. | Read-only source inventory and reconciled volume report. |

## Run the offline estimate

```powershell
s8 install m365-migration-estimator
s8migrate estimate `
  -InputPath .\docs\examples\government\dplh-lasp-migration-input.csv `
  -OutputPath .\evidence\lasp-migration-estimate `
  -HourlyRate 0 `
  -ThroughputGBPerDay 250
```

`-HourlyRate 0` deliberately suppresses an invented commercial price. Insert an approved rate only after procurement and commercial review.

## Evidence package

Retain together:

- source inventory timestamp, method and operator;
- the exact CSV input and its SHA-256;
- `migration-input-evidence.csv/json`;
- `migration-estimate.csv/json`;
- `migration-summary.csv/json`;
- estimator version/commit and execution log;
- unresolved assumptions, exclusions and failed collections.

## Controlled delivery gates

1. **Discovery:** inventory farms, custom solutions, databases, documents, lists, permissions, workflow state, interfaces and records constraints.
2. **Design:** map each source object to an approved target, owner, retention rule, security boundary and acceptance test.
3. **Rehearsal:** migrate a representative synthetic or approved non-production slice; reconcile counts, hashes, metadata and permissions.
4. **Pilot:** obtain business, records, privacy, cyber and service-owner approval for a bounded cohort.
5. **Cutover:** freeze authorised scope, capture final deltas, execute an approved runbook and preserve evidence.
6. **Closure:** obtain acceptance and disposal authority before any legacy decommissioning.

## Failure and rollback

- Stop if counts, hashes, metadata, permissions or interface balances exceed approved tolerance.
- Preserve the source as system of record until written acceptance.
- Revert routing and user access to the source service under the approved rollback runbook.
- Retain failed-run evidence; do not overwrite or silently repair discrepancies.
- Any destructive cleanup requires separate records, security and service-owner approval.
