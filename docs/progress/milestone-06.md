# Milestone 06 — 3-axis CNC plan and operation editor

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `a58e7b4` (pushed) + new tests committed separately  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pending for new test commits

## Features completed

- **3-axis manufacturing plan** (already implemented): feature-to-operation mapping, setup grouping by dominant axis, time estimates (cutting, setup, tool change, inspection), accessibility warnings, 3-axis-only restriction.
- **Costing confidence threshold** (already implemented): features at/above 0.75 confidence are auto-costed (status=suggested); below 0.75 are needs_review and excluded from costing until confirmed.
- **Operation editor** (already implemented): PATCH endpoint lets users edit operation type, tool, setup, estimated time, rate, fixed cost, assumptions, warnings, status.
- **Plan validation** (already implemented): rejects non-3-axis machine counts, normalizes operation defaults.
- **Manufacturing plan UI** (already implemented): setups table, operations table with suggested vs needs_review distinction, edit/add/remove operations.

## New test coverage added for Milestone 06

| Test | What it verifies |
|---|---|
| `test_feature_to_operation_mapping` | All 12 feature types map to correct 3-axis operations |
| `test_high_confidence_operations_auto_costed` | Confidence >= 0.75 → status=suggested, auto_costed=True |
| `test_low_confidence_operations_needs_review` | Confidence < 0.75 → status=needs_review, auto_costed=False |
| `test_setup_grouping_by_axis` | Features grouped into S-Z, S-X, S-Y setups by dominant axis |
| `test_plan_validates_3axis_only` | validate_plan rejects non-3-axis machine counts |
| `test_plan_validation_normalizes_operations` | Missing operation fields filled with defaults |
| `test_estimated_time_includes_only_auto_costed` | Total cutting time excludes needs_review operations |
| `test_confidence_band_documentation` | Confidence 0–1, no precision/recall claims in warnings |

## What is visibly available in the Flutter app

1. **Manufacturing plan screen** (`/projects/:id/manufacturing`): setups table with axis orientation, operations table with type/tool/setup/time/status/confidence, suggested vs needs_review distinction.
2. **Operation editing**: popup menu on each operation row lets users edit type, tool, setup, time, rate, fixed cost, assumptions, warnings.
3. **Costing confidence**: operations below 0.75 confidence are flagged as needs_review and excluded from the estimate total.

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
Then: create project → upload STEP → run analysis → Manufacturing plan screen → inspect setups/operations → edit an operation → see estimate update.

Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

Input: Analysis with one through_hole (confidence 0.92, diameter 10mm, Z axis) and one chamfer (confidence 0.68)

Output:
- `plan.operations[0]`: type=drilling, status=suggested, auto_costed=True, confidence=0.92
- `plan.operations[1]`: type=chamfering, status=needs_review, auto_costed=False, confidence=0.68, warning="Confidence below costing threshold; confirm before costing."
- `plan.total_cutting_time_min` = drilling time only (chamfer excluded)
- `plan.machine_axis_count` = 3

## Tests run

- Backend: 60 passed, 0 failed (52 previous + 8 new manufacturing tests)
- Flutter: analyze no issues; 6 widget tests passed

## Known bugs and limitations

- Time estimates are planning assumptions, not validated cycle times.
- No collision simulation, gouge checking, or cutting-force model.
- Setup grouping is heuristic (dominant axis), not based on actual fixture constraints.
- Confidence is an evidence score, not measured precision/recall.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Previous commit: `a58e7b4` (pushed)
- New test commits: pending push
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)

## Next milestone's concrete tasks

- Milestone 07 (Material database, stock allowance, editable prices, cost estimate): already implemented; verify stock allowance UI, estimate line items, rounding, overrides.
- Milestone 08 (Reports, exports, optional LLM explanations): already implemented; verify report export formats and LLM explanation with NVIDIA NIM provider.
- Milestone 09 (Platform, reliability, release readiness): verify Windows/Web builds, CI checks, document limitations.
- Push the new test commits to GitHub.
