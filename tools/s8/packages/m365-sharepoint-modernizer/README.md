# M365 SharePoint Modernizer

Read-only site, list and library discovery with stale-site, scale-risk and modernization planning outputs.

```powershell
s8 install m365-sharepoint-modernizer
s8spmodern full -InstallDependencies
s8spmodern plan -StaleDays 365 -LargeListThreshold 5000
```

Graph does not expose every classic SharePoint artifact. The report flags what it can prove and preserves collection failures; it never changes sites.
