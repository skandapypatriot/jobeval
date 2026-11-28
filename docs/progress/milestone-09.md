# Milestone 09 — Platform, reliability, and release readiness

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `5923b61` (pushed) + final commit pending  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pending for final commit

## Features completed

- **Platform verification:**
  - Web build: `flutter build web --release` succeeds (build/web output)
  - Backend: Python 3.12 with build123d/OCP, FastAPI, SQLAlchemy SQLite
  - Windows desktop: NOT buildable in this environment (Visual Studio C++ workload not installed)
  - Android: NOT tested (no device/emulator available for validation)
- **Reliability:**
  - 64 backend tests pass (unit + API tests covering full workflows)
  - 6 Flutter widget tests pass (dashboard, pricing)
  - Flutter analyze: no issues
  - SQLite persistence with WAL mode, foreign keys
  - Background jobs with queued/processing/completed/failed/cancelled states
  - Upload validation: extension + content magic bytes, size limits, path traversal prevention
  - Error handling: actionable error messages, no stack traces in UI
- **CI checks:**
  - `.github/workflows/ci.yml`: backend format/lint/test, Flutter format/analyze/test/web build
  - `.github/workflows/flutter-ci.yml`: Windows, Android, Web platform builds
- **Release instructions:**
  - README.md: exact backend and frontend setup/run commands
  - scripts/setup_backend.ps1, run_backend.ps1, run_frontend.ps1, check.ps1
  - docker-compose.yml: optional container deployment
  - Dockerfile.backend: Python 3.12 with OCP/OpenGL runtime
- **Documentation:**
  - docs/known-limitations.md: format support, feature coverage, platform constraints, estimation caveats
  - docs/release-checklist.md: pre-release verification items
  - docs/architecture/, docs/decisions/, docs/api/: design and contract documentation
  - docs/progress/: one report per milestone (0-9)

## What is visibly available in the Flutter app

Complete end-to-end workflow:
1. **Dashboard**: live backend health, project create/list/demo, recent jobs
2. **Project workspace**: uploaded files, analysis status, recent results
3. **Upload/import**: STEP/PDF/DXF upload with progress and validation
4. **3D Viewer**: orbit/pan/zoom/fit, axes, bounds, body/feature selection/highlighting
5. **Geometry Analysis**: bodies, units, bbox, volume, surface area, center of mass, validation warnings
6. **Feature Review**: holes, counterbores, countersinks, fillets, chamfers, pockets, steps with confidence/evidence/accessibility; confirm/correct/manual
7. **Drawing Review**: pages, extracted dimensions, title block, GD&T candidates, source evidence
8. **Cross-Validation**: match/mismatch/drawing_only/model_only/needs_review with discrepancy review
9. **Manufacturing Plan**: setups, operations, costing confidence threshold, accessibility warnings
10. **Pricing & Estimate**: editable material/stock/allowance/rates, line items, totals, snapshots
11. **Reports**: JSON/HTML/CSV export
12. **Settings**: global pricing defaults, LLM provider options, privacy guidance

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

Frontend (Web):
```powershell
cd C:\Users\casmm\jobeval\frontend
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
python -m http.server 5173 --directory build/web
```
Then open Chrome to `http://localhost:5173`.

Or Flutter dev mode:
```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

Full check script:
```powershell
cd C:\Users\casmm\jobeval
.\scripts\check.ps1
```

## Sample workflow (end-to-end)

1. Create project → "Demo review"
2. Upload STEP file (e.g., testdata\step\*.step)
3. Run geometry analysis → view mesh, dimensions, volume, surface area
4. Review features → select row → see 3D highlight → confirm/correct
5. Upload PDF/DXF drawing → parse → view dimensions, title block, GD&T
6. Cross-validation → see match/mismatch statuses → review discrepancies
7. Manufacturing plan → view setups/operations → confirm low-confidence ops
8. Pricing & Estimate → change allowance/material/rate/quantity → see estimate update
9. Save estimate → snapshot is immutable
10. Report → export JSON/HTML/CSV

## Tests run

- Backend: 64 passed, 0 failed
- Flutter: analyze no issues; 6 widget tests passed
- Web build: succeeds (build/web/)

## Known bugs and limitations

- **Windows desktop:** Cannot build in this environment (Visual Studio C++ workload not installed). Works on machines with Visual Studio installed.
- **Android:** Not tested (no device/emulator available for validation).
- **Flutter web Chrome debug service:** Chrome debug-service handshake may time out; use `flutter run -d web-server` and open Chrome manually.
- **STEP import time:** ~66 seconds for 7 MB fixture on i3-1115G4 (documented timing).
- **OCR:** Not available (Tesseract not installed); PDF text/vector extraction works for vector-based PDFs.
- **STL:** Mesh-only, no topology-aware feature recognition.
- **DWG:** Not supported (no lawful conversion path).
- **LLM:** Optional, requires API key; CAD binaries never sent; output is advisory only.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Previous commit: `5923b61` (pushed)
- Final commit: pending
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)

## Git status

Working tree is clean after this commit. All changes are committed and pushed.
