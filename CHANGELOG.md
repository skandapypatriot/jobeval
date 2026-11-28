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

The runnable app and analysis workflow are tracked in the subsequent milestone entries.
