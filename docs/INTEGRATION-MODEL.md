# System 8 Integration Model

## Purpose

System 8 treats an integration as an operational system rather than a collection of API calls. The unit of design is the complete path from human intent to observable outcome, including identity, interfaces, data contracts, platform behavior, infrastructure and recovery.

## Layer model

| Layer | Concern | Examples |
|---:|---|---|
| 8 | Operator interface | dashboards, desktop GUI, web, mobile, voice, DTMF, kiosk |
| 7 | Application behavior | Microsoft 365, SaaS, line-of-business applications |
| 6 | Automation and orchestration | agents, workflows, jobs, queues, scheduled execution |
| 5 | Platform services | identity, policy, storage, search, messaging, telemetry |
| 4 | Transport contract | HTTPS, TLS, sessions, retries, throttling |
| 3 | Addressing and routing | IP, DNS, proxies, gateways, service discovery |
| 2 | Local delivery | Ethernet, Wi-Fi, VLANs, switching |
| 1 | Physical execution | devices, power, cabling, radios, compute |
| 0 | Human context | ownership, authority, incentives, capability, culture |

Layer 0 is not metaphorical decoration. It captures the conditions under which the system is requested, operated, trusted and repaired.

## Integration contract

Every boundary should define:

- source and destination
- transport and authentication
- schema and version
- ownership
- latency and consistency expectations
- retry and idempotency semantics
- observability
- failure behavior
- rollback or compensation
- data classification and retention

## Change transaction

A production change should approximate this sequence:

```text
inspect → validate → plan → snapshot → apply → verify → commit
                                  ↘ failure → restore
```

For systems without native transactions, use compensating operations and record enough state to replay or reverse the change deterministically.

## Adapter rule

Vendor-specific behavior remains behind an adapter. Domain logic should not depend directly on:

- proprietary identifiers
- transient API response shapes
- UI selectors
- tenant-specific paths
- environment-specific secrets
- vendor retry behavior

This limits replacement cost and creates a defined test boundary.

## Observability minimum

An integration is not complete unless an operator can answer:

1. What was requested?
2. Who or what requested it?
3. What inputs were accepted?
4. Which operations ran?
5. What changed?
6. What failed or was skipped?
7. What is the current state?
8. How is the change reversed?

## Delivery classes

### Utility

A focused administrative tool with local state, logs, validation and rollback.

### Service

A persistent API, worker or agent with health checks, identity, telemetry and controlled deployment.

### Platform

A multi-user operational surface with roles, workflow state, audit history, integrations and lifecycle management.

## Definition of done

An integration is done when:

- the happy path is implemented
- failure paths are explicit
- credentials are externalized
- deployment is repeatable
- current state is observable
- documentation matches runtime behavior
- the operator can validate and recover the system
- Layer 0 ownership is clear
