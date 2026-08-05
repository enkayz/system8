# Contributing to System 8

## Change standard

Contributions should be small enough to review independently and complete enough to operate safely.

A change should include:

- a precise problem statement
- the affected integration boundary
- expected behavior
- failure behavior
- validation performed
- rollback or compatibility impact
- documentation updates where runtime behavior changed

## Branches and commits

Use a focused branch and imperative commit messages.

```text
feat/admx-release-verification
fix/s8-path-registration
 docs/integration-contracts
```

Prefer one coherent behavior change per commit.

## PowerShell

Windows administration tooling should support PowerShell 5.1 and PowerShell 7 unless a dependency makes that impossible.

Required practices:

- `Set-StrictMode -Version Latest`
- terminating error handling for transactional operations
- explicit parameter validation
- no embedded credentials
- TLS 1.2 handling where Windows PowerShell 5.1 requires it
- idempotent installation and removal
- dry-run support for destructive or broad changes
- logs containing action, target, result and timestamp
- rollback or compensating behavior

## Integration reviews

Review changes against these questions:

1. Is the external contract explicit?
2. Are environment assumptions isolated?
3. Can the operation be repeated safely?
4. Is partial failure recoverable?
5. Can an operator determine current state?
6. Are credentials and sensitive data excluded?
7. Does the documentation match the code?
8. Is ownership clear at Layer 0?

## Pull requests

Include:

- what changed
- why it changed
- operator impact
- tests or validation
- rollback procedure
- screenshots for visible UI changes

Do not combine unrelated formatting, refactoring and behavioral changes unless they are inseparable.
