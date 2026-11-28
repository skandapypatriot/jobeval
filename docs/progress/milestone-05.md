# Milestone 05 — Drawing/model cross-validation

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `3313e3f` (pushed) + new tests committed separately  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pending for new test commits

## Features completed

- **Cross-validation service** (already implemented): compares drawing annotations with model evidence using explicit tolerances. Statuses: match, mismatch, drawing_only, model_only, needs_review.
- **Dimension comparison** (already implemented): drawing vs model overall length/width/height with configurable tolerance (default 0.5 mm).
- **Hole count comparison** (already implemented): drawing hole callouts vs model hole features.
- **Hole diameter comparison** (already implemented): pairwise diameter comparison with tolerance.
- **Material comparison** (already implemented): drawing material note vs model material.
- **Tolerance detection** (already implemented): drawing tolerances flagged as drawing_only (STEP doesn't carry tolerance semantics).
- **Cross-validation UI** (already implemented): checks table with status, drawing value, model value, tolerance, explanation, review state; discrepancy review endpoint persists review state without deleting source evidence.

## New test coverage added for Milestone 05

| Test | What it verifies |
|---|---|
| `test_cross_validation_seeded_mismatch` | Drawing length 100 vs model 150 → mismatch, status=needs_review |
| `test_cross_validation_match` | Drawing and model agree on length/width/height/material → match |
| `test_cross_validation_drawing_only_dimension` | Drawing length with zero-length model → drawing_only |
| `test_cross_validation_model_only_dimension` | Model length with no drawing length → model_only |
| `test_cross_validation_hole_count_mismatch` | 2 drawing holes vs 1 model hole → mismatch |
| `test_cross_validation_material_mismatch` | STEEL drawing vs AL 6061 model → mismatch |

## What is visibly available in the Flutter app

1. **Cross-validation screen** (`/projects/:id/cross-validation`): checks table with match/mismatch/drawing_only/model_only/needs_review statuses, drawing and model values, tolerance, explanation, review state.
2. **Discrepancy review**: PATCH endpoint lets users mark discrepancies as reviewed/accepted/rejected without deleting source evidence.

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
Then: create project → upload STEP + PDF/DXF → run analysis → parse drawing → cross-validation → inspect matches/mismatches → review discrepancies.

Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

Input: drawing length=100.0 mm, model bbox length=150.0 mm, tolerance=0.5 mm

Output:
- `checks[overall_length].status` = "mismatch"
- `checks[overall_length].drawing` = 100.0
- `checks[overall_length].model` = 150.0
- `checks[overall_length].tolerance` = 0.5
- `result.status` = "needs_review"
- `result.summary.mismatch` >= 1

Input: drawing length=75.0 mm, model length=0.0 (degenerate)

Output:
- `checks[overall_length].status` = "drawing_only"
- `checks[overall_length].drawing` = 75.0
- `checks[overall_length].model` = None

## Tests run

- Backend: 52 passed, 0 failed (48 previous + 4 new cross-validation tests)
- Flutter: analyze no issues; 6 widget tests passed

## Known bugs and limitations

- Drawing-to-model association is evidence-limited; ambiguous dimensions are needs_review, never forced into a match.
- GD&T is presented as candidate review items, not standards-certified interpretations.
- Cross-validation only checks length/width/height from bbox; it does not compare feature-level positions or orientations.
- Reviewing a discrepancy persists the review state but does not delete source evidence.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Previous commit: `3313e3f` (pushed)
- New test commits: pending push
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)

## Next milestone's concrete tasks

- Milestone 06 (3-axis CNC plan and operation editor): verify feature-to-operation mapping, setup grouping, costing confidence threshold, user edits to operations.
- Milestone 07 (Material database, stock allowance, editable prices, cost estimate): already largely implemented; verify stock allowance UI and estimate line items.
- Milestone 08 (Reports, exports, optional LLM explanations): already implemented; verify report export and LLM explanation.
- Milestone 09 (Platform, reliability, release readiness): verify Windows/Web builds, add CI checks, document limitations.
- Push the new test commits to GitHub.
