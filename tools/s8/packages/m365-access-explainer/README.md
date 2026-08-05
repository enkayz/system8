# M365 Access Explainer

Explains a user's transitive directory memberships, enterprise-application roles, owned objects and licence entitlements from live Graph evidence.

```powershell
s8 install m365-access-explainer
s8access explain -UserPrincipalName user@contoso.com -InstallDependencies
```

SharePoint item permissions, Exchange delegation and Teams private-channel membership require workload-specific evidence and are not silently inferred.
