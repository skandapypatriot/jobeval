# Milestone 02 — NVIDIA NIM provider adapter for optional LLM explanations

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `48a508c`  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pushed to GitHub

## Features completed

- **NVIDIA NIM provider adapter** — The LLM service now supports two providers: OpenRouter (default) and NVIDIA NIM. Provider selection is via `LLM_PROVIDER` environment variable (`openrouter`, `nvidia_nim`, or `disabled`).
- **Provider-specific configuration** — Each provider has its own API key, base URL, model, and timeout settings read from environment variables. No provider is contacted without its API key.
- **Explanation endpoint provider selection** — `POST /api/v1/projects/{id}/explanation` accepts an optional `provider` field in the request body to override the server default per-request.
- **Generic LLM completion method** — `LLMService.complete()` sends system + user prompts to the configured provider with retries, backoff, and structured JSON output validation. All LLM output is marked advisory and cannot change geometry, dimensions, feature data, operations, times, prices, or confidence.
- **Frontend settings screen** — Added read-only LLM provider configuration section showing OpenRouter and NVIDIA NIM options with privacy guidance. API keys are configured server-side via `.env`; the UI never stores or transmits keys.
- **Backend tests** — 5 new tests cover OpenRouter config, NVIDIA NIM config, missing API key handling, local privacy mode blocking, and disabled provider.
- **Documentation** — Updated `.env.example`, `docs/known-limitations.md`, and `docs/api/endpoints.md`.

## What is visibly available in the Flutter app

- **Settings screen** — Shows API connection info, LLM provider options (OpenRouter / NVIDIA NIM), data privacy guidance, and global pricing editor.
- **Provider selection** — Individual explanation requests can specify `openrouter` or `nvidia_nim` via the API request body.
- **Pricing & estimate** — Non-zero estimates with sample/demo rates (₹420/kg aluminum, ₹600/hr machine, etc.), manufacturing summary with setup count, orientation changes, complexity band, and average confidence.

## Exact steps to reproduce

Backend:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
Frontend:
```powershell
cd C:\Users\casmm\jobeval\frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```
Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

**LLM service config (NVIDIA NIM):**
```
Provider: nvidia_nim
API key: ****
Base URL: https://integrate.api.nvidia.com/v1
Model: nvidia/nemotron-3.5-...
```

**LLM service config (OpenRouter):**
```
Provider: openrouter
API key: ****
Base URL: https://openrouter.ai/api/v1
Model: openai/gpt-4o-mini
```

**Explanation endpoint response:**
```json
{
  "project_id": "...",
  "explanation": {
    "summary": "...",
    "risks": [],
    "suggestions": [],
    "_validation": {
      "validated_by": "jobeval_llm_validator",
      "warnings": [],
      "is_advisory": true,
      "geometry_authoritative": true
    },
    "provider": "nvidia_nim",
    "model": "nvidia/nemotron-3.5-..."
  },
  "calculations_unchanged": true,
  "cad_sent": false,
  "provider": "nvidia_nim",
  "provider_name": "NVIDIA NIM"
}
```

**Without API key:** Returns HTTP 503 with `"NVIDIA NIM is not configured; set the corresponding API key to enable explanations"`.

## Tests run

- Backend: 37 passed, 0 failed (32 original + 5 new LLM service tests)
- Flutter: analyze no issues; 6 widget tests passed

## Known bugs and limitations

- LLM API keys are server-side environment variables only; the frontend cannot set or store them. This is intentional for local-first security.
- Without an API key, the explanation endpoint returns 503. The app works fully without LLM.
- LLM output is advisory only — validated against geometry but never trusted as authoritative.
- Original CAD binaries are never sent to any LLM provider.
- Flutter Radio API deprecation warnings resolved by using read-only icons instead of interactive radio buttons.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Commit: `48a508c`
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)
- Push status: Pushed

## Next milestone's concrete tasks

- Milestone 03 (project workflow/upload/persistence): add project rename/delete confirmation, duplicate-file handling, file download, persisted analysis across backend restart, upload progress UI, and backend restart persistence test.
- Milestone 04 (CAD import/viewer): add more STEP fixtures (5+ validation cases), known-dimension tolerance checks, viewer error/empty states, and import-warning display.
