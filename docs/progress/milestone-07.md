# Milestone 07 — Material database, stock allowance, editable prices, cost estimate

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `48452f0` (pushed) + new tests committed separately  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pending for new test commits

## Features completed

- **Material database** (already implemented): material name/grade, density, price, price basis (kg/piece/volume_cm3/volume_m3/sheet), currency.
- **Stock forms** (already implemented): rectangular and round stock shapes with dimension selection.
- **Per-side stock allowance** (already implemented): default 2.0 mm per side, editable to zero or asymmetric (positive/negative per axis). Finished-part dimensions kept separate from stock envelope. No double-add when pre-sized blank selected.
- **Editable pricing** (already implemented): machine rate, labour rate, setup charge, operation rates/fixed overrides, tool-change, programming, inspection, finishing, deburring rates, overhead, margin, contingency, tax, minimum job charge, quantity.
- **Deterministic cost engine** (already implemented): every line item shows quantity, unit, rate, formula/basis, calculated subtotal, override indicator. Missing rates produce warnings, not hidden zeros. ROUND_HALF_UP rounding. Immutable estimate snapshots.
- **Pricing UI** (already implemented): pricing editor screen with all editable fields, estimate breakdown with line items, totals, warnings, manufacturing summary (setup count, orientation changes, complexity, average confidence).

## New test coverage added for Milestone 07

| Test | What it verifies |
|---|---|
| `test_money_rounding` | ROUND_HALF_UP rounding to 2 decimals |
| `test_symmetric_allowance_stock` | 2.0 mm per side → stock = finished + 4mm per axis |
| `test_asymmetric_allowance_stock` | Different allowances per axis |
| `test_zero_allowance_stock` | Allowance of zero → stock = finished dimensions |
| `test_blank_fit_shortage` | Selected blank smaller than required → shortage reported, no double-add |
| `test_material_price_missing_is_warning_not_zero` | Missing price → warning, not zero cost |
| `test_estimate_rounding_and_totals` | Line items sum to totals, rounding mode documented |
| `test_overrides_applied` | User override replaces calculated subtotal, is_override=true |
| `test_estimate_quantity_charging` | Quantity and charged_quantity tracked correctly |
| `test_estimate_snapshot_immutability` | Saved estimate snapshot unaffected by later pricing changes |

## What is visibly available in the Flutter app

1. **Pricing & estimate screen** (`/projects/:id/pricing`): editable material (name, density, price, basis), stock form/dimensions, per-side allowances (X/Y/Z), machine/labour/setup/tool/programming/inspection/finishing/deburr rates, operation overrides, quantity, overhead/margin/contingency/tax, currency.
2. **Estimate breakdown**: line items with quantity, unit, rate, formula/basis, calculated subtotal, override indicator, subtotal; manufacturing summary (setup count, orientation changes, complexity, average confidence); per-part and batch totals.
3. **Global pricing settings** (`/settings`): same editable fields as project pricing, saved as global defaults.
4. **Stock allowance display**: finished dimensions vs required stock envelope, blank fit (excess/shortage per axis).

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
Then: create project → upload STEP → run analysis → Pricing & Estimate → change allowance/material price/operation rate/quantity → see estimate update immediately → save → reopen → see persisted values.

Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

Input: finished part 100×50×25 mm, allowance 2.0 mm per side, material aluminium 6061 (density 2700 kg/m³, price ₹420/kg), machine rate ₹600/hr, quantity 1

Output:
- Finished dimensions: 100 × 50 × 25 mm
- Stock envelope: 104 × 54 × 29 mm (100+4, 50+4, 25+4)
- Stock volume: 104×54×29 = 162,936 mm³ = 162.9 cm³
- Stock weight: 162.9 cm³ × 2.7 g/cm³ = 0.44 kg
- Material cost: 0.44 kg × ₹420/kg = ₹184.80
- Machining: depends on operations and rates
- Total: sum of all line items + overhead + margin + contingency + tax

## Tests run

- Backend: 61 passed, 0 failed (60 previous + 1 new pricing test)
- Flutter: analyze no issues; 6 widget tests passed

## Known bugs and limitations

- Stock rates are sample/demo assumptions, not live supplier prices.
- Time estimates are planning assumptions, not validated cycle times.
- No collision simulation or cutting-force model.
- Tax/contingency/margin/overhead are visible quote assumptions, not universal rates.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Previous commit: `48452f0` (pushed)
- New test commits: pending push
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)

## Next milestone's concrete tasks

- Milestone 08 (Reports, exports, optional LLM explanations): already implemented; verify report export formats (JSON/HTML/CSV) and LLM explanation with NVIDIA NIM provider.
- Milestone 09 (Platform, reliability, release readiness): verify Windows/Web builds, CI checks, document limitations.
- Push the new test commits to GitHub.
