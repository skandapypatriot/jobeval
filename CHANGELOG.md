# Changelog

All notable JobEval changes are recorded here. The format follows semantic versioning once a release is published.

## [Unreleased]

### Milestone 0 — Repository audit and local implementation baseline

- Audited the upstream scaffold and corrected its unsupported "all phases complete" claim.
- Added a local-first architecture, exact dependency compatibility record, API contract guidance, known limitations, and release checklist.
- Added reproducible Windows setup/run/check scripts and a real API smoke script.
- Replaced the misleading service-dependent CI definition with backend and Flutter format/lint/test checks.
- Added the previously missing MIT license.
- Established feature branch `feat/incremental-jobeval-build` from upstream `main` at `3eaab95`.

### Milestone 01 — Runnable application: backend analysis layer, frontend screens, deterministic pricing

- Real SQLite persistence for projects, files, jobs, analysis, drawings, cross-validation, manufacturing plan, pricing/estimates, and reports
- STEP import via build123d/OCP with unit detection, topology/property measurement, per-face tessellation for the viewer, and validity warnings
- Topology/analytic-surface feature recognition (holes, counterbore, countersink, pockets, fillets, chamfers) with evidence, confidence, and accessibility
- PDF and DXF drawing extraction with page/source bbox evidence
- Cross-validation with explicit tolerances and match/mismatch statuses
- 3-axis manufacturing plan with auto/costing-confidence thresholds and needs_review flagging
- Transparent pricing with per-side stock allowance (default 2.0 mm, editable to zero), material price basis, rate warnings for missing values, line-item formulas, overrides, and immutable estimate snapshots
- Local in-process background jobs with queued/processing/completed/failed states, progress, and actionable errors
- Dashboard with live backend health (real /health, not hardcoded), project create/list/demo, and job status
- Project workspace tabs: overview, files/upload, geometry + mesh viewer, features, drawings, cross-validation, manufacturing plan, pricing/estimate
- Editable pricing editor with stock allowance, material price, machine/labor rates, operation overrides, quantity, overhead/margin/contingency/tax
- 32 backend tests and 6 Flutter widget tests passing

### Milestone 02 — NVIDIA NIM provider adapter for optional LLM explanations

- NVIDIA NIM provider adapter alongside OpenRouter; provider selected via LLM_PROVIDER env var
- Provider-specific API key, base URL, model, and timeout for each provider
- Explanation endpoint accepts optional provider field per request
- LLMService.complete() with retries, backoff, and structured JSON validation
- Frontend settings screen with LLM provider options and privacy guidance
- All LLM output is advisory, validated, and cannot change deterministic calculations
- 5 new backend tests; 37 total backend tests passing

### Milestone 03 — Feature recognition and review UI

- Feature recognition: topology- and analytic-surface-based detection of holes, counterbores, countersinks, fillets, chamfers, pockets, steps with evidence, confidence, accessibility
- Feature review UI: table with confidence bands, evidence, review status filters, confirm/correct/manual actions
- 3D highlighting linkage: selecting a feature row highlights corresponding faces/body/vertices in mesh viewer
- Manual correction: PATCH endpoint updates reviewed_features separately; raw detection never overwritten
- New tests: negative case (plain block), duplicate detection, counterbore, blind hole, fillet/chamfer, confidence band documentation
- 6 new backend tests; 43 total backend tests passing

### Milestone 04 — Drawing parser and annotation review

- PDF text/vector extraction with PyMuPDF, DXF entity extraction with ezdxf
- Dimension parsing: diameter, radius, depth, thread, chamfer, fillet, angular, linear with source bbox evidence
- Title block extraction: part number, revision, material, finish, title, scale
- GD&T candidates: flatness, straightness, circularity, position, etc.
- OCR availability reporting: reports unavailable when Tesseract not installed
- New tests: dimension source evidence, title block fields, GD&T candidates, OCR unavailable, unsupported format rejection
- 5 new backend tests; 48 total backend tests passing

### Milestone 05 — Drawing/model cross-validation

- Cross-validation: drawing vs model comparison with explicit tolerances (match/mismatch/drawing_only/model_only/needs_review)
- Dimension, hole count, hole diameter, material comparison
- Discrepancy review: mark reviewed without deleting source evidence
- New tests: seeded mismatch, match, drawing-only, model-only, hole count mismatch, material mismatch
- 4 new backend tests; 52 total backend tests passing

### Milestone 06 — 3-axis CNC plan and operation editor

- Feature-to-operation mapping: 12 feature types → drilling, counterboring, countersinking, pocket milling, slot milling, profile milling, chamfering
- Setup grouping by dominant axis (Z/X/Y)
- Costing confidence threshold (0.75): auto-costed vs needs_review operations
- Plan validation: rejects non-3-axis, normalizes operation defaults
- New tests: feature-to-operation mapping, auto-costing, needs_review, setup grouping, 3-axis validation, plan normalization, time estimation, confidence documentation
- 8 new backend tests; 60 total backend tests passing

### Milestone 07 — Material database, stock allowance, editable prices, cost estimate

- Material database: name/grade, density, price, price basis, currency
- Stock forms: rectangular and round
- Per-side stock allowance: default 2.0 mm, editable to zero/asymmetric; finished vs stock dimensions separate
- Editable pricing: machine/labour/setup/tool/programming/inspection/finishing rates, operation overrides, quantity, overhead/margin/contingency/tax
- Deterministic cost engine: line items with formulas, overrides, missing-rate warnings, immutable snapshots
- New tests: estimate snapshot immutability
- 1 new backend test; 61 total backend tests passing

### Milestone 08 — Reports, exports, optional LLM explanations

- Report export: JSON/HTML/CSV formats with project, geometry, features, plan, estimate, stock, warnings
- Optional LLM explanations: OpenRouter and NVIDIA NIM providers, advisory-only, cannot change calculations
- Dual LLM provider support with per-request provider selection
- Privacy gate: privacy_mode=local blocks cloud LLM; CAD binaries never sent
- New tests: JSON/HTML/CSV report export
- 3 new backend tests; 64 total backend tests passing

### Milestone 09 — Platform, reliability, and release readiness

- Web build verified: flutter build web --release succeeds
- All backend tests pass: 64 tests
- All Flutter tests pass: 6 widget tests
- Flutter analyze: no issues
- CI workflows: backend format/lint/test, Flutter format/analyze/test/web build
- Docker compose: backend + frontend services
- Dockerfile.backend: Python 3.12 with OCP/OpenGL runtime
- README: clean setup path, exact run commands for backend and frontend
- Known limitations: documented format support, feature coverage, platform constraints, estimation caveats
- Release checklist: pre-release verification items
- Windows desktop: NOT buildable in this environment (Visual Studio C++ workload not installed)
- Android: NOT tested (no device/emulator available)
- Integration tests: covered by unit/API tests covering full workflows

The runnable app and analysis workflow are complete across all 10 milestones.
