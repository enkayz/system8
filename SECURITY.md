# Security Policy

## Reporting

Do not disclose suspected vulnerabilities, exposed credentials or exploitable deployment details through public issues.

Report privately to:

```text
lord.nk@gmail.com
```

Include:

- affected component and version or commit
- reproduction steps
- expected and observed behavior
- likely impact
- relevant logs with credentials and personal data removed
- any known mitigation

## Scope

Security reports are particularly relevant for:

- bootstrap and package installation
- download integrity and update channels
- privilege elevation
- path or command injection
- credential handling
- unsafe archive extraction
- ADMX Central Store modification
- rollback integrity
- tenant or identity boundary violations

## Distribution trust

Production release artifacts should use immutable versioned URLs and published SHA-256 checksums. Scripts fetched directly from a mutable branch are considered development-channel distribution until release signing and immutable manifests are implemented.

## Supported versions

Only the current `main` implementation and the most recent published stable package versions are supported unless otherwise documented.
