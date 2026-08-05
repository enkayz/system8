# M365 Migration Estimator

Offline rough-order-of-magnitude planning for SharePoint, file shares, Exchange, Google Workspace, Dropbox and other inventoried workloads.

```powershell
s8 install m365-migration-estimator
s8migrate template -OutputPath .\estimate
s8migrate estimate -InputPath .\estimate\migration-input-template.csv -HourlyRate 185
```

The estimator records assumptions and emits CSV, JSON and HTML. It does not connect to or modify a tenant.
