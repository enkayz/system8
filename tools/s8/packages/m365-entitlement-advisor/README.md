# M365 Entitlement Advisor

Maps operator-defined personas and capabilities to the tenant's live service-plan assignments. This complements visual licensing references without copying a matrix that can become stale.

```powershell
s8 install m365-entitlement-advisor
s8entitlement template -OutputPath .\entitlement
s8entitlement assess -RequirementsPath .\entitlement\requirements-template.csv -InstallDependencies
```

The requirements CSV is explicit evidence. Results do not constitute Microsoft licensing advice; confirm commercial terms with Microsoft or your licensing provider.
