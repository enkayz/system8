# M365 Tenant Diff

Captures normalized, read-only tenant configuration snapshots and compares them offline.

```powershell
s8 install m365-tenant-diff
s8tenantdiff capture -InstallDependencies -OutputPath .\baseline
s8tenantdiff compare -BaselinePath .\baseline\tenant-snapshot.json -CurrentPath .\current\tenant-snapshot.json
```

Comparison reports added, removed and changed objects in CSV, JSON and HTML.
