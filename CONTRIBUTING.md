# Contributing to JobEval

## Before changing code

1. Fetch and inspect `origin/main` without discarding local work.
2. Create a focused feature branch.
3. Record the supported input, expected deterministic result, and user-visible path for the change.
4. Keep original CAD/drawing data out of Git unless it is a small documented redistributable fixture.

## Development rules

- Keep API handlers thin and domain calculations deterministic.
- Validate external input and preserve provenance (source, inferred, default, user-edited).
- Do not turn missing data into a fake success, zero price, or fabricated confidence.
- Add or update a test with each behavior change.
- Update the relevant API/architecture/limitations documentation.
- Never commit `.env`, API keys, runtime databases, uploads, generated reports, or customer files.

## Verification

Run the focused test while developing, then the full checks before committing:

```powershell
.\scripts\check.ps1
```

Also verify the affected Flutter flow against a running backend. If a platform cannot be built in the current environment, record the exact unverified command and reason rather than claiming success.

## Commit and pull request guidance

Use small logical commits, for example:

- `feat: persist project and source file metadata`
- `feat: import STEP geometry and expose viewer mesh`
- `feat: add reviewed feature candidates`
- `feat: calculate transparent stock and machining estimate`
- `fix: preserve user pricing overrides during re-analysis`

A pull request should identify the visible workflow, tests run, sample input/output, limitations, and whether a screenshot was captured from the running application.
