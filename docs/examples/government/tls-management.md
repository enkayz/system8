# Government TLS management example

> **EXAMPLE — NOT PRODUCTION INSTRUCTIONS**
>
> This is an evidence-led operational pattern for a government public land-asset service. It does not establish the root cause of an outage and is not approval to change protocols, cipher suites, certificates, proxies, IIS, .NET or Windows policy.

## Outcome

Establish an auditable TLS baseline, diagnose compatibility from evidence, stage the smallest safe correction, and retain a tested rollback. Do not infer that TLS 1.3 is required merely because a service using TLS 1.2 is inaccessible; certificate trust, cipher overlap, SNI, proxy behaviour, application protocol support and identity flows must also be tested.

## Read-only baseline

Run from an authorised administration workstation and store output in an approved evidence location.

```powershell
$Evidence = Join-Path $PWD ("tls-evidence-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $Evidence | Out-Null

Get-ChildItem Cert:\LocalMachine\My |
  Select-Object Subject, Thumbprint, NotBefore, NotAfter, HasPrivateKey |
  Export-Csv (Join-Path $Evidence 'machine-certificates.csv') -NoTypeInformation

Get-TlsCipherSuite |
  Select-Object Name, Protocols, Cipher, Hash, Exchange |
  Export-Csv (Join-Path $Evidence 'cipher-suites.csv') -NoTypeInformation

Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Schannel'; StartTime=(Get-Date).AddDays(-7)} |
  Select-Object TimeCreated, Id, LevelDisplayName, Message |
  Export-Csv (Join-Path $Evidence 'schannel-events.csv') -NoTypeInformation
```

Also capture, without exposing private keys or secrets:

- DNS resolution and load-balancer/proxy route;
- presented certificate chain, SANs, issuer and expiry;
- client/server protocol and cipher overlap;
- IIS binding, SNI and application-pool runtime;
- outbound proxy and inspection points;
- HTTP status, Schannel, IIS and application correlation IDs;
- identity path, including claims or application-proxy dependencies.

## Decision record

For each proposed change record:

| Field | Required content |
|---|---|
| Symptom | User-visible and machine-observed failure with timestamp. |
| Evidence | Logs, handshake trace, certificate chain and configuration snapshots. |
| Hypothesis | One falsifiable cause; avoid changing multiple layers at once. |
| Scope | Exact service, endpoint, client cohort and maintenance window. |
| Security review | Impact of enabling/disabling protocol or cipher support. |
| Test | Success, failure and monitoring criteria. |
| Rollback | Exact prior values, owner and maximum decision time. |
| Approval | Service owner, cyber/security and change authority references. |

## Staged change pattern

1. Reproduce the failure from an approved test client.
2. Snapshot relevant registry, IIS, proxy, certificate and policy configuration.
3. Test the proposed correction in non-production or a bounded canary.
4. Validate TLS 1.2 interoperability, certificate trust, application behaviour and authentication—not only a successful socket handshake.
5. Obtain change approval before production mutation.
6. Deploy one bounded change, monitor Schannel/IIS/application telemetry and verify user workflow.
7. Close only when evidence and service-owner acceptance are recorded.

## Failure and rollback

- Trigger rollback on increased handshake failures, authentication regression, unexpected client exclusion, certificate mismatch or application errors.
- Restore the captured prior configuration using the approved platform-specific runbook.
- Restore the previous certificate binding only if its private key, validity and trust chain remain approved.
- Re-run baseline and user-journey tests after rollback.
- Preserve before/change/after evidence and incident timestamps for assurance review.
