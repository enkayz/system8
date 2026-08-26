# Public land asset sales migration features

> **EXAMPLE — NOT PRODUCTION INSTRUCTIONS**
>
> This is a government-generic feature and migration pattern. It uses synthetic workloads and makes no claim about any agency's production architecture, procurement, data, approval or preferred platform. Confirm requirements, licensing, records obligations, security classification and source-system evidence with authorised owners.

## Product outcome

A portable public-facing service that lets people discover land assets, understand their status and history, inspect maps and documents, and follow a transparent sale or disposal process. The service should preserve an exportable government-owned data model while allowing different presentation and workflow platforms—including Power Pages—to be used as replaceable adapters.

## Features with immediate public value

### 1. Searchable public asset catalogue

- map and accessible list views with the same filters;
- parcel/property identifiers, address, locality, responsible agency and asset status;
- sale/disposal stage, key dates, public documents and contact/subscription options;
- saved links, stable public URLs, downloadable records and machine-readable APIs;
- WCAG-oriented keyboard, screen-reader, contrast and non-map alternatives;
- separation of publishable fields from internal evaluation, legal, personal and commercially sensitive data.

### 2. Australian GIS interoperability

- source adapters for Landgate and SLIP services where authorised and licensed;
- OGC API - Features, WMS, WFS, WMTS, GeoJSON, KML, CSV, ArcGIS REST and vector-tile ingestion;
- GDA2020/GDA94 transformation evidence and source coordinate-reference-system retention;
- dataset metadata compatible with NationalMap/TerriaJS catalogues and data.gov.au discovery patterns;
- parcel, planning, tenure, environment, infrastructure, heritage and imagery layers with source attribution;
- explicit source licence, freshness, scale, accuracy and authoritative-owner metadata.

### 3. Time-enabled map and decision history

- dated asset-state snapshots and immutable event history;
- a timeline slider for valid-from/valid-to layers, imagery dates and transaction milestones;
- side-by-side or swipe comparison for approved historical imagery;
- provenance for every snapshot, geometry and document version;
- replay from source events without overwriting the current state;
- no dependency on proprietary Google Maps history: use licensed time-enabled datasets and standard temporal metadata.

### 4. Portable platform boundary

Keep the durable record outside any presentation lock-in:

- canonical JSON/JSON Schema and relational/PostGIS model;
- stable IDs, explicit geometry/CRS, status vocabulary and event timestamps;
- OpenAPI endpoints plus bulk GeoJSON, CSV and JSON export;
- documents in government-controlled object storage with hashes and retention metadata;
- adapters for Power Pages/Dataverse, SharePoint, static/headless sites and custom web applications;
- repeatable full export, import, reconciliation and exit tests at every release gate.

Power Pages can remain a valid delivery option. The portability requirement is that data, documents, configuration, business rules and public URLs have tested export and replacement paths; it is not a claim that Power Pages is unsuitable.

### 5. Legacy estate and automation inventory

Inventory before deciding what to rewrite:

- IIS sites, bindings, certificates, application pools, .NET/runtime dependencies and scheduled tasks;
- SharePoint solutions, lists, workflows, forms, web parts and direct database/file-share dependencies;
- Excel/Access VBA projects, signed/unsigned macros, COM/ActiveX dependencies, filesystem/network calls and privileged actions;
- Power Platform solutions, Dataverse tables, flows, connectors, environment variables and portal configuration;
- integrations, service accounts, secrets, DNS, proxies, identity paths and support owners.

VBA is primarily Office desktop automation; it is not generally IIS application code. Classify the two separately. Office Scripts is a useful target for supported Excel-on-the-web automation, but VBA that uses forms, COM/ActiveX, local files, Windows APIs or unsupported object-model features needs redesign or manual rewrite—not a blind conversion. Preserve the original macro, test fixtures, expected outputs and approval evidence.

### 6. TLS, privacy and information protection

- certificate, DNS, proxy, cipher, Schannel/IIS and application-path evidence before change;
- public/private field classification and a publishability gate at the API boundary;
- DLP simulation and false-positive review before enforcement;
- malware scanning, document sanitisation, metadata stripping and downloadable-file controls;
- least-privilege administration, immutable audit trails and monitored export paths;
- approved rollback for TLS, policy, portal and data-publication changes.

See [TLS management](tls-management.md) and [DLP management](dlp-management.md).

## Runnable synthetic migration estimate

The System8 estimator is offline and non-destructive. From the repository root:

```powershell
s8 install m365-migration-estimator
s8migrate estimate `
  -InputPath .\docs\examples\government\land-asset-source-inventory.csv `
  -OutputPath .\evidence\land-asset-estimate `
  -HourlyRate 0 `
  -ThroughputGBPerDay 250
```

`-HourlyRate 0` suppresses invented commercial pricing. The sample estimates migration-planning effort only; it does not build the target portal or establish a fixed quote.

## Evidence gates

1. **Inventory:** authoritative owners, source versions, volumes, licences, classification, integrations and failed collections.
2. **Canonical model:** approved schema, publishability rules, geometry/CRS policy, stable IDs and event semantics.
3. **Adapters:** prove at least one source import and one complete platform-neutral export with reconciliation.
4. **Map proof:** test desktop, mobile, keyboard/list-only use, spatial accuracy, attribution, temporal layers and degraded-network operation.
5. **Automation proof:** compare macro/script outputs using approved fixtures; manually review unsupported VBA/IIS behaviour.
6. **Security proof:** test TLS path, public/private separation, DLP simulation, document handling, audit and incident response.
7. **Migration rehearsal:** reconcile counts, hashes, geometry, metadata, permissions, status and event history.
8. **Cutover approval:** service, data, GIS, records, privacy, cyber, accessibility and change owners sign the bounded runbook.

## Failure and rollback

- Keep the source system authoritative until written acceptance.
- Stop on unexplained count, hash, geometry, status, permission or event-history variance.
- Restore previous routing and public-page release from a tested deployment artifact.
- Restore prior TLS/DLP policy state from captured configuration; do not delete incident evidence.
- Preserve rejected records and failed transformations in an exception queue.
- Require separate approval before destructive legacy cleanup or records disposal.

## Supporting artefacts

- [Synthetic source inventory](land-asset-source-inventory.csv)
- [Machine-readable feature registry](land-asset-features.json)
- [GitHub and library discovery keywords](github-discovery-keywords.md)
