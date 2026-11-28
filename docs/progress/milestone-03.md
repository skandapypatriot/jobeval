# Milestone 03 — Feature recognition and review UI

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `b5749c7` (pushed) + new tests committed separately  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pending for new test commits

## Features completed

- **Feature recognition** (backend, already implemented): topology- and analytic-surface-based detection of through/blind holes, counterbores, countersinks, fillets, chamfers, pockets, and steps. Each feature carries stable ID, dimensions, axis, position, evidence, accessibility, confidence (0–1), and warnings. Raw detection is immutable; review state is stored separately.
- **Feature review UI** (frontend, already implemented): features table with confidence bands, evidence, accessibility, review status filters, confirm/correct/manual actions, source/provenance labels. Low-confidence features (< 0.50) are visibly marked and excluded from automatic costing.
- **3D highlighting linkage** (already implemented): selecting a feature row in the geometry screen highlights the corresponding faces/body/vertices in the triangulated mesh viewer.
- **Manual correction** (already implemented): PATCH endpoint updates `reviewed_features` separately from `raw_features`; raw detection is never overwritten.

## New test coverage added for Milestone 03

| Test | What it verifies |
|---|---|
| `test_plain_block_has_no_spurious_features` | Negative case: plain Box produces zero hole/pocket detections |
| `test_no_duplicate_detections_for_same_feature` | Single cylindrical bore → exactly one feature record (no per-face duplicates) |
| `test_counterbore_detection` | Stepped bore → counterbore with major + secondary diameter |
| `test_blind_hole_detection` | Non-through hole → blind_hole with depth_type="blind" |
| `test_fillet_chamfer_on_edged_block` | Filleted/chamfered edges → fillet/chamfer candidates, no crash |
| `test_confidence_band_documentation` | Confidence 0–1, band classification, no precision/recall claims in warnings |

## What is visibly available in the Flutter app

1. **Feature review screen** (`/projects/:id/features`): table of detected features with ID, type, dimensions, depth type, axis, confidence band, evidence, review status, source/provenance. Filter by low confidence (< 0.50) or review status (all/needs_review/confirmed/corrected/manual).
2. **Geometry & 3D review screen** (`/projects/:id/geometry`): triangulated mesh viewer with orbit/pan/zoom/fit, axes, bounding box, body dropdown. Feature mapping table lets you select a row to highlight its faces/body/vertices in the viewer.
3. **Confirm/correct/manual actions**: popup menu on each feature row lets you confirm as reviewed, correct values, or mark as manual. Changes persist via PATCH to `/projects/{id}/features/{feature_id}`.
4. **Low-confidence exclusion**: features below 0.50 confidence are flagged and excluded from automatic costing in the manufacturing plan and pricing.

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
Then: create project → upload STEP → run analysis → Features screen → select a row → see 3D highlight in Geometry screen → confirm/correct a feature.

Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

Input: `Box(40, 30, 20).cut(Cylinder(6, 25))` — 40×30×20 mm block with 12 mm diameter through-hole

- Geometry: 1 body, volume ≈ 21738 mm³, units mm (confidence 0.98)
- Feature: `F-THROUGH_HOLE-<hash>`, type `through_hole`, confidence 0.92, diameter 12.0 mm, depth 20.0 mm, through=true
- Evidence: `surface=cylinder`, `material_side=out`, `adjacent_face_ids=[...]`, `analysis=analytic cylinder with adjacency checks`
- Accessibility: `collision_risk=good`
- Review state: `raw` (not yet confirmed)

Input: plain `Box(40, 30, 20)` (negative case)
- Hole/pocket features: 0 (no spurious detections)

Input: `Box(50, 40, 30).cut(Cylinder(8, 30)).cut(Cylinder(4, 35))` (counterbore)
- Feature: `counterbore`, confidence ≥ 0.5, major_diameter and secondary_diameter populated

## Tests run

- Backend: 43 passed, 0 failed (37 previous + 6 new feature recognition tests)
- Flutter: analyze no issues; 6 widget tests passed

## Known bugs and limitations

- Feature recognition works on solid B-Rep (STEP) only; mesh-only inputs (STL) cannot produce topology-aware features.
- Counterbore detection requires the smaller cylinder to be fully coaxial with the larger; offset counterbores may be missed.
- Fillet/chamfer detection on build123d filleted edges may fail if edge selection is empty; the recognizer falls back gracefully.
- Confidence is an evidence score, not a measured precision/recall probability.
- No duplicate feature IDs across different feature types (stable IDs are type-scoped).

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Previous commit: `b5749c7` (pushed)
- New test commits: pending push
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)

## Next milestone's concrete tasks

- Milestone 04 (Drawing parser and annotation review): add PDF/DXF upload tests, verify text/vector extraction, dimension/tolerance parsing, title block detection, OCR availability reporting.
- Milestone 05 (Drawing/model cross-validation): verify seeded mismatch detection, configurable tolerances, review-state persistence.
- Push the new test commits to GitHub.
