# M365 Recovery Readiness

Assesses privileged redundancy, inferred emergency-access candidates, Conditional Access exclusions, domain posture and application credential runway.

```powershell
s8 install m365-recovery-readiness
s8resilience full -InstallDependencies
```

Emergency-account naming is only a discovery signal. Operators must explicitly identify accounts, verify phishing-resistant authentication, test access in a controlled drill and maintain offline recovery documentation.
