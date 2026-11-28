# Milestone 01 — Runnable application: backend analysis layer, frontend screens, deterministic pricing

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `4310250`  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** pending (network not yet used for this commit)

## Features completed

- **Backend:** real FastAPI + SQLite backend with persisted projects, source files, jobs (queued/processing/completed/failed/cancelled), geometry analysis, features, drawings, cross-validation, manufacturing plan, pricing/estimates, and reports.
- **STEP import:** build123d/OCP reads `.step`/`.stp`, detects source units (mm/cm/m/inch/foot ambiguity tracked), computes topology counts, bbox, volume, surface area, center of mass, per-face tessellated mesh, and validity warnings. Original upload is never modified.
- **Feature recognition:** topology- and analytic-surface-based detection of through/blind holes, counterbores, countersinks, pockets, fillets, chamfers — each with stable ID, dimensions, axis, position, evidence, accessibility, confidence (0–1), and warnings. Raw detection is immutable; review state is stored separately.
- **Drawing extraction:** PDF (PyMuPDF text/vector) and DXF (ezdxf) parsing with page/source bbox evidence, dimensions, tolerances, title-block/material/finish/GDT candidates, and OCR availability reporting.
- **Cross-validation:** drawing-vs-model comparison with explicit tolerances and statuses `match`/`mismatch`/`drawing_only`/`model_only`/`needs_review`.
- **Manufacturing plan:** 3-axis only, feature-to-operation mapping, setup grouping, time estimates, warnings, and a 0.75 costing-confidence threshold. Low-confidence operations are marked `needs_review` and excluded from costing until confirmed.
- **Pricing & estimate:** configurable per-side stock allowance (default 2.0 mm, editable to zero/asymmetric), finished vs raw-stock dimensions kept separate, blank fit (excess/shortage, no double-add), material price basis (kg/piece/cm³/m³/sheet), machine/labour/setup/tool/programming/inspection/finishing rates, operation rate and fixed overrides, quantity/minimum, overhead/margin/contingency/tax, missing-rate warnings (never hidden zeros), deterministic ROUND_HALF_UP rounding, and immutable estimate snapshots.
- **Frontend:** dashboard with live `/health` (not hardcoded), project create/list/demo, project workspace with tabs for files/upload, geometry + mesh viewer, features, drawings, cross-validation, manufacturing plan, pricing/estimate, report, and settings with editable global pricing.
- **Tests:** 32 backend tests pass (project CRUD, upload validation, known STEP geometry volume/dimensions, pricing stock allowances/rounding/overrides/quantity/missing-rate warnings, drawing extraction, cross-validation seeded mismatch). 6 Flutter widget tests pass; `flutter analyze` reports no issues.

## What is visibly available in the Flutter app

1. **Dashboard** — shows live backend connection state from the real `/health` endpoint (online/offline/degraded with retry), app version, recent projects, and recent jobs. Create project or create demo project buttons work.
2. **Project workspace** — upload STEP/PDF/DXF files with progress, run CAD analysis, view measured geometry (bodies, bbox, volume, surface area, units) and a triangulated mesh viewer with orbit/pan/zoom/fit/axes/body selection.
3. **Feature review** — table of detected features with confidence bands, evidence, and accessibility; row selection links to viewer highlighting; confirm/correct/exclude without overwriting raw detection; low-confidence features visibly marked.
4. **Drawing review** — pages, extracted text, dimensions, tolerances, title-block/material/finish/GDT candidates with source page/bbox and confidence.
5. **Cross-validation** — match/mismatch/drawing_only/model_only/needs_review table; discrepancies can be reviewed without deleting source evidence.
6. **Manufacturing plan** — suggested setups/operations for 3-axis milling; low-confidence ops flagged `needs_review` and excluded from costing; edit/add/remove/reorder operations.
7. **Pricing & estimate** — finished-part dimensions vs stock allowance (default 2.0 mm/side), raw-stock envelope, blank fit, material price/rate overrides, per-line rate/formula/override/subtotal, per-part and batch totals. Changes persist via PUT/POST.
8. **Settings** — global pricing defaults (currency, density, rates, allowances) saved and reloadable.
9. **Reports** — JSON/HTML/CSV export from saved estimate.
10. **Optional LLM explanation** — disabled without `OPENROUTER_API_KEY`; labelled prose only; cannot change calculations.

## Exact steps to reproduce

Backend:
```
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pip install --upgrade pip
.\.venv\Scripts\python -m pip install -e ".[dev]"
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
Frontend:
```
cd C:\Users\casmm\jobeval\frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```
Tests:
```
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

Input: `testdata\step\PO-SG158971-142759-Part81460-Qnt2-MEC-X0047-01_X01_20261022.STEP` (a 124 x 44 x 2 mm bracket with holes, countersinks, pockets, fillets, chamfers)

- Health: `{"status":"healthy","service":"jobeval-backend","version":"0.2.0-local","database":"ok","storage":"ok"}`
- Job: completed, progress 1.0
- Geometry: 1 body, 696 faces, volume 9533.3 mm³, surface area 10909.2 mm², bbox [-62,-22,0] to [62,22,2], units mm (confidence 0.98)
- Features: 172 candidates detected (through_hole 0.92, blind_hole 0.82, countersink 0.86, chamfer 0.68, rectangular_pocket 0.70) each with evidence, accessibility, review_state "raw"
- Manufacturing plan: 172 operations; 32 auto-costed (confidence ≥0.75), 140 `needs_review`; cutting time 50.3 min
- Pricing: with default 2.0 mm/side allowance, stock = finished + 4 mm per axis; changing allowance to zero makes stock equal finished dimensions; missing material price produces "Material price is missing" warning, not zero cost

## Tests run

- Backend: 32 passed, 0 failed
- Flutter: analyze no issues; 6 widget tests passed (dashboard online/offline/create-project, pricing save→estimate→error-retry)

## Known bugs and limitations

- Backend ruff has 51 remaining mostly pre-existing style issues in scaffold files (not blocking functionality).
- STEP import takes ~66 s for a 7 MB fixture on this i3-1115G4 (documented timing).
- No OCR engine installed by default; PDF text/vector extraction works, raster-only OCR reports unavailable.
- LLM explanation requires `OPENROUTER_API_KEY`; core app works without it.
- Windows desktop build requires Visual Studio C++ workload (not installed in this environment); Web target works.
- Android not yet device-tested.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Commit: `4310250`
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)
- Push status: not yet pushed for this commit

## Next milestone's concrete tasks

- Milestone 02 (project workflow/upload/persistence): add project rename/delete confirmation, duplicate-file handling, file download, persisted analysis across backend restart, upload progress UI, and backend restart persistence test.
- Milestone 03 (CAD import/viewer): add more STEP fixtures (5+ validation cases), known-dimension tolerance checks, viewer error/empty states, and import-warning display.
- Push `feat/incremental-jobeval-build` to GitHub and update `CHANGELOG.md`.
