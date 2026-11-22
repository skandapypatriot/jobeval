# REST API endpoints

The API is served under `/api/v1`. Interactive OpenAPI/Swagger documentation is available while the backend is running at `/docs`; the generated schema is authoritative for exact field names and status codes.

All request and response bodies use JSON except file upload and report downloads. IDs are opaque strings. Errors use HTTP status plus a `detail` message intended for a user-facing explanation.

## Service and dashboard

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Direct health alias |
| `GET` | `/api/v1/health` | Versioned health and service metadata |
| `GET` | `/api/v1/dashboard` | Recent projects and jobs for the dashboard |

The health response includes application version and service/database/storage status. It must reflect actual runtime checks; it is not a static `connected` value.

## Projects

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/projects` | List projects |
| `POST` | `/api/v1/projects` | Create a project |
| `GET` | `/api/v1/projects/{project_id}` | Open project details |
| `PATCH` | `/api/v1/projects/{project_id}` | Rename/update metadata |
| `DELETE` | `/api/v1/projects/{project_id}` | Delete project and owned runtime files |
| `POST` | `/api/v1/projects/demo` | Create a labelled deterministic demo project |

Example create request:

```json
{
  "name": "Bracket estimate",
  "description": "Q3 customer bracket"
}
```

## Files and analysis

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/projects/{project_id}/files` | List owned files and processing state |
| `POST` | `/api/v1/projects/{project_id}/files` | Upload a validated source file (multipart `file`) |
| `GET` | `/api/v1/files/{file_id}` | File metadata |
| `GET` | `/api/v1/files/{file_id}/content` | Safe source download/view |
| `DELETE` | `/api/v1/files/{file_id}` | Delete an owned file |
| `POST` | `/api/v1/projects/{project_id}/analysis` | Queue CAD analysis for a project/file |
| `GET` | `/api/v1/projects/{project_id}/analysis` | Latest geometry/features analysis |
| `GET` | `/api/v1/projects/{project_id}/features` | Raw and reviewed feature candidates |
| `PATCH` | `/api/v1/projects/{project_id}/features/{feature_id}` | Confirm, correct, exclude, or create a review record |

Example analysis request:

```json
{
  "file_id": "file-opaque-id"
}
```

The response identifies a job. Poll `/api/v1/jobs/{job_id}` until its state is `completed`, `failed`, or `cancelled`. A WebSocket may be used for progress when available; polling remains the portable fallback.

## Jobs

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/jobs/{job_id}` | State, progress, bounded log, and error |
| `POST` | `/api/v1/jobs/{job_id}/cancel` | Cooperative cancellation where safe |

Job states are `queued`, `processing`, `completed`, `failed`, and `cancelled`.

## Drawings and comparison

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/projects/{project_id}/drawings/parse` | Parse a project PDF/DXF file or supplied file ID |
| `GET` | `/api/v1/projects/{project_id}/drawings` | Latest drawing pages and annotations |
| `POST` | `/api/v1/projects/{project_id}/cross-validation` | Compare drawing values with model evidence |
| `GET` | `/api/v1/projects/{project_id}/cross-validation` | Latest comparison checks |
| `PATCH` | `/api/v1/projects/{project_id}/cross-validation/{check_id}` | Mark a discrepancy reviewed without deleting evidence |

## Manufacturing plan

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/projects/{project_id}/manufacturing-plan` | Current suggested/confirmed plan |
| `PUT` | `/api/v1/projects/{project_id}/manufacturing-plan` | Save setup, operation, order, tool, and time edits |
| `POST` | `/api/v1/projects/{project_id}/manufacturing-plan/regenerate` | Recalculate suggestions while preserving reviewed user state where possible |

A plan is a 3-axis milling planning estimate. It is not a generated or simulated toolpath.

## Pricing and estimate

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/settings/pricing` | Global default pricing profile |
| `PUT` | `/api/v1/settings/pricing` | Save global default profile |
| `GET` | `/api/v1/projects/{project_id}/pricing` | Effective project profile with provenance |
| `PUT` | `/api/v1/projects/{project_id}/pricing` | Save project profile/overrides |
| `POST` | `/api/v1/projects/{project_id}/estimate` | Calculate and save an immutable estimate snapshot |
| `GET` | `/api/v1/projects/{project_id}/estimate` | Latest saved estimate |

The profile includes material density and price basis, selected stock blank, per-side stock allowances, machine/labour/auxiliary rates, operation overrides, quantity, and commercial percentages. Null rates remain missing and produce warnings.

## Reports and optional explanation

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/projects/{project_id}/reports?format=json` | Structured saved report |
| `GET` | `/api/v1/projects/{project_id}/reports?format=html` | Printable HTML report |
| `GET` | `/api/v1/projects/{project_id}/reports?format=csv` | Tabular line-item export |
| `POST` | `/api/v1/projects/{project_id}/explanation` | Optional labelled prose grounded in structured results |

The explanation endpoint returns a clear unavailable response when no provider key is configured. Its output cannot mutate the estimate or any deterministic result.
