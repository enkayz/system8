# M365 License Optimizer

Read-only SKU utilization, dormant/disabled licensed-user analysis and customer-priced savings estimates.

```powershell
s8 install m365-license-optimizer
s8license full -InstallDependencies
s8license savings -PriceFile .\prices.csv -DormantDays 90
```

The optional price CSV has `SkuPartNumber,MonthlyUnitPrice` columns. Prices are never invented. Output is CSV, JSON and HTML with collection evidence.
