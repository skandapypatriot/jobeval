# JobEval

**JobEval** is a local-first Flutter and FastAPI application for analysing mechanical CAD parts and engineering drawings, reviewing manufacturing features, and producing transparent 3-axis CNC milling estimates.

> JobEval is an estimating and analysis tool, not a certified CAM package. It does not generate validated toolpaths and does not quote turning, EDM, grinding, additive, 4-axis, or 5-axis processes.

## What is in the application

The intended workflow is:

1. create a project or open the labelled demo project;
2. upload a STEP model and an optional PDF/DXF drawing;
3. run analysis and inspect measured geometry in the 3D viewer;
4. review evidence-backed feature candidates and drawing annotations;
5. compare drawing and model values;
6. review a candidate 3-axis milling plan;
7. edit material, stock, allowance, rates, quantities, and overrides;
8. calculate and export an itemized estimate.

Deterministic geometry and costing are kept separate from optional LLM prose. The application remains usable without an LLM key.

## Prerequisites

- Windows 10/11 with PowerShell for the commands below (equivalent Bash commands are noted where useful);
- Python 3.11 or 3.12;
- Flutter stable with Dart 3.13 or newer;
- Chrome/Edge for the Web target.

Optional services are **not required** for the local workflow. The default backend uses SQLite and generated files under an ignored runtime directory. Docker, PostgreSQL, Redis, object storage, OCR, and OpenRouter are deployment/optional integrations, not prerequisites for the demo.

## Quick start on Windows

Open two PowerShell terminals at the repository root.

### 1. Prepare and start the backend

```powershell
Set-Location C:\Users\casmm\jobeval
.\scripts\setup_backend.ps1
.\scripts\run_backend.ps1
```

Equivalent manual commands:

```powershell
cd C:\Users\casmm\jobeval\backend
python -m venv .venv
.\.venv\Scripts\python -m pip install --upgrade pip
.\.venv\Scripts\python -m pip install -e ".[dev]"
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Verify the real backend health response:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/v1/health
```

The Flutter dashboard reads this endpoint. Stop and restart the backend to see the connection state change; the app does not display a hardcoded connection status.

### 2. Start the Flutter application

```powershell
Set-Location C:\Users\casmm\jobeval\frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Or use the wrapper:

```powershell
Set-Location C:\Users\casmm\jobeval
.\scripts\run_frontend.ps1
```

For a Windows desktop build, install Visual Studio with the **Desktop development with C++** workload, then run:

```powershell
cd C:\Users\casmm\jobeval\frontend
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Web development from another device can use the host machine's LAN address in `API_BASE_URL`; add that origin to the backend's configured CORS list.

## Demo workflow

1. Start both applications and open **Dashboard**.
2. Confirm the backend badge is connected.
3. Select **Create demo project**. The backend seeds a labelled demo with a small deterministic STEP model and paired drawing fixture.
4. Open the project, run CAD analysis, and inspect the measured dimensions, volume, surface area, bounds, and tessellated 3D viewer.
5. Open **Features**, select a row, and inspect its evidence and linked geometry. Confirm or correct a candidate.
6. Open **Drawing** and **Compare** to inspect extracted source regions and drawing/model discrepancies.
7. Open **Plan**, then **Pricing & Estimate**. Change the default **2.0 mm per side** stock allowance (including zero), a material price, an operation rate, and quantity.
8. Inspect each line item's rate, formula, override indicator, and total.
9. Open **Report** and export JSON, HTML, or CSV.

The seeded prices are **sample/demo assumptions**, not live market or supplier prices. Missing rates remain visible warnings rather than becoming zero-cost operations.

## Supported inputs

| Input | Current role | Important limitation |
|---|---|---|
| STEP (`.step`, `.stp`) | Analytic B-Rep import, measured properties, feature candidates, viewer mesh | Feature quality depends on topology and source quality |
| PDF | Embedded text/vector dimension and note extraction | Raster-only OCR is optional and may be unavailable |
| DXF | Supported drawing entities, text, and dimensions | Not a native solid-conversion path |
| STL | Possible mesh inspection only | Mesh topology cannot preserve B-Rep feature intent |

DWG is out of scope. See [`docs/known-limitations.md`](docs/known-limitations.md).

## Stock and estimate rules

The imported CAD bounding box remains the finished part. Raw-stock sizing is a separate quoting assumption:

```text
required stock length = finished length + allowance on both ends
required stock width  = finished width  + allowance on both sides
required stock height = finished height + allowance on both faces
```

The symmetric default is **2.0 mm per side**. It is editable globally/project-locally and can be zero or asymmetric. When a pre-sized blank is selected, JobEval compares it with the required envelope and reports excess or shortage; it does not add the allowance twice.

Every estimate line shows its quantity, unit, rate, formula/basis, calculated value, optional override, and subtotal. Saved estimates are immutable snapshots, so changing a global price does not rewrite an old quote.

## Repository layout

```text
jobeval/
├── frontend/                 Flutter application
├── backend/                  FastAPI application and domain services
├── fixtures/                 Small deterministic CAD/drawing validation data
├── shared/                   Versioned shared examples/contracts (when needed)
├── scripts/                  Setup, run, fixture, and verification helpers
├── docs/architecture/        Design and module boundaries
├── docs/decisions/           Architecture decision records
├── docs/api/                 API and contract guidance
├── docs/progress/            Milestone reports and actual verification evidence
├── .github/workflows/        CI and platform build checks
└── docker-compose.yml        Optional deployment services
```

## Tests and checks

From a prepared backend environment:

```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m ruff format --check app tests
.\.venv\Scripts\python -m ruff check app tests
.\.venv\Scripts\python -m pytest -q
```

Flutter:

```powershell
cd C:\Users\casmm\jobeval\frontend
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
```

Run both groups with:

```powershell
Set-Location C:\Users\casmm\jobeval
.\scripts\check.ps1
```

The verified results for each delivery are recorded under [`docs/progress/`](docs/progress/). Failed or unavailable checks are reported explicitly rather than omitted.

## Architecture and privacy

- API handlers stay thin; domain calculations live in deterministic services.
- Uploads use generated storage names and sanitized original-name metadata.
- Runtime data, customer CAD files, databases, uploads, and generated reports are ignored by Git.
- Original CAD bytes are not sent to an optional LLM. The optional explanation receives only validated structured results and cannot change calculated values.
- The full local data flow is described in [`docs/architecture/system-design.md`](docs/architecture/system-design.md).

## Documentation

- [System design](docs/architecture/system-design.md)
- [Architecture decisions](docs/decisions/0001-local-stack-and-cad-kernel.md)
- [API contract versioning](docs/api/contract-versioning.md)
- [Known limitations](docs/known-limitations.md)
- [Milestone reports](docs/progress/README.md)
- [Release checklist](docs/release-checklist.md)

## License

MIT — see [`LICENSE`](LICENSE).
