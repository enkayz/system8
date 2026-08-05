# M365 Leaver Readiness

Discovers ownership, reporting-line, membership and OneDrive dependencies before an approved offboarding change.

```powershell
s8 install m365-leaver-readiness
s8leaver assess -UserPrincipalName leaver@contoso.com -InstallDependencies
```

The package never blocks sign-in, revokes sessions, removes licences or changes ownership. Those actions require separate authorization and workload-specific runbooks.
