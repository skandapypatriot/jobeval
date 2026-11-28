# Milestone 08 — Reports, exports, and optional LLM explanations

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `14f5ec0` (pushed) + new tests committed separately  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pending for new test commits

## Features completed

- **Report export** (already implemented): GET /projects/{id}/reports?format=json|html|csv returns structured report with project details, source files, geometry, features, drawing comparisons, manufacturing plan, stock assumptions, cost breakdown, warnings, confidence.
- **JSON report** (already implemented): application/json content type, full report structure.
- **HTML report** (already implemented): text/html content type, printable report.
- **CSV report** (already implemented): text/csv content type, tabular line-item export.
- **Optional LLM explanations** (already implemented): POST /projects/{id}/explanation with optional provider field (openrouter/nvidia_nim). Returns labelled prose grounded only in structured results. Cannot change geometry, dimensions, feature data, operations, times, prices, or confidence. Disabled without API key (HTTP 503).
- **Dual LLM provider** (already implemented): OpenRouter (default) and NVIDIA NIM, selected via LLM_PROVIDER env var or per-request provider field.
- **Privacy gate** (already implemented): privacy_mode=local blocks all cloud LLM calls. Original CAD binaries never sent to LLM.

## New test coverage added for Milestone 08

| Test | What it verifies |
|---|---|
| `test_report_json_export` | JSON report contains project, analysis, plan, estimate data; content type application/json |
| `test_report_html_export` | HTML report returns text/html content type |
| `test_report_csv_export` | CSV report returns text/csv content type |

## What is visibly available in the Flutter app

1. **Report screen** (`/projects/:id/report`): report preview with project details, geometry summary, features, manufacturing plan, pricing estimate, warnings, export buttons for JSON/HTML/CSV.
2. **Export buttons**: JSON, HTML, CSV export options on the report screen.
3. **LLM explanation**: available when server has API key configured; labelled as optional/explanatory only.

## Exact steps to reproduce

Backend:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
Verify:
```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/v1/health | ConvertTo-Json
```

Frontend:
```powershell
cd C:\Users\casmm\jobeval\frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```
Then: create project → upload STEP → run analysis → save estimate → Report screen → export JSON/HTML/CSV.

Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

Input: completed project with STEP analysis and saved estimate

Output (JSON report):
```json
{
  "project": { "id": "...", "name": "...", ... },
  "analysis": { "geometry_summary": {...}, "features": [...], "units": {...} },
  "plan": { "setups": [...], "operations": [...], "warnings": [...] },
  "estimate": { "lines": [...], "total": ..., "currency": "INR", ... },
  "stock": { "required_stock": {...}, "allowances": {...} },
  "warnings": [...]
}
```

## Tests run

- Backend: 64 passed, 0 failed (61 previous + 3 new report tests)
- Flutter: analyze no issues; 6 widget tests passed

## Known bugs and limitations

- Report content reflects the latest saved estimate; older estimates require re-selecting.
- LLM explanations are opt-in and require server-side API key configuration.
- LLM output is labelled advisory only; cannot modify deterministic values.
- Original CAD binaries are never sent to LLM providers.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Previous commit: `14f5ec0` (pushed)
- New test commits: pending push
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)

## Next milestone's concrete tasks

- Milestone 09 (Platform, reliability, release readiness): verify Windows/Web builds, CI checks, document limitations, add regression/integration tests, finalize README and release checklist.
- Push the new test commits to GitHub.
