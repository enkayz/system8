# M365 Change Impact

Turns Microsoft 365 service health and Message Center notices into an evidence-backed, tenant-scaled operator register.

```powershell
s8 install m365-change-impact
s8changes full -InstallDependencies -LookAheadDays 90
```

The score prioritizes review; it does not predict outages or make tenant changes. Messages, tenant scale and failed collections remain available as evidence.
