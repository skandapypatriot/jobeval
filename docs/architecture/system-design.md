# JobEval system design

## Product boundary

JobEval is an estimating and analysis application for mechanical CAD parts and engineering drawings. The first manufacturing scope is **3-axis CNC milling**. It does not generate validated toolpaths, simulate cutting forces, or quote turning, EDM, grinding, additive, 4-axis, or 5-axis processes.

## Runtime topology

```text
Flutter desktop / web
        |
        | REST (JSON) + optional job WebSocket
        v
FastAPI API layer
        |
        v
Application/domain services
  |        |          |             |
  v        v          v             v
CAD      Drawing   Feature      Manufacturing / pricing
  |        |          |             |
  +--------+----------+-------------+
             |
        repositories
             |
    SQLite (default) / PostgreSQL (future)

Uploaded source bytes -> generated local storage path
CAD geometry -> bounded triangle mesh + structured properties
```

API handlers validate input and delegate to services. Geometry, feature, manufacturing, and cost logic has no FastAPI or database dependency and is unit-testable.

## Modules

| Backend area | Responsibility |
|---|---|
| `api` | Versioned routes, request/response validation, status codes, actionable errors |
| `schemas` / `models` | Versioned Pydantic contracts and persistence entities |
| `repositories` | Transaction boundaries and JSON/relational persistence |
| `services/cad` | STEP import, unit detection, topology/property measurement, tessellation |
| `services/features` | Surface/topology classification, candidate grouping, evidence, confidence |
| `services/drawings` | PDF/DXF extraction and source-region preservation |
| `services/manufacturing` | Feature-to-operation mapping, setups, warnings, editable plan |
| `services/pricing` | Stock envelopes, rate snapshots, line items, rounding, overrides |
| `workers` | Bounded local jobs with persisted status/progress/errors |

The Flutter client is organized by route/feature. It stores only server-owned state, uses Riverpod providers for async data, and uses GoRouter for navigation. CAD rendering uses a custom mesh painter rather than a platform-specific viewer.

## Data flow

### Import and analysis

1. Validate extension, size, and basic content.
2. Generate an opaque stored filename; retain the sanitized original name as metadata.
3. Detect the STEP source unit and normalize working geometry to millimetres.
4. Import with build123d/OCP and collect topology and global properties.
5. Tessellate each body/face with bounded tolerances for the viewer.
6. Detect feature candidates using analytic surfaces, topology, boundaries, and adjacency.
7. Persist the raw result, warnings, job log, and timestamps.
8. Return the same structured result to the Flutter application.

The original upload is never replaced. A failed import produces an inspectable job error and does not fabricate geometry.

### Feature review

Raw detection is immutable. A user's confirmation, correction, exclusion, or manual candidate is stored separately and merged only in the response. Confidence is an evidence score, not a measured precision/recall claim. Features below the automatic-cost threshold remain visible but are not costed until reviewed.

### Drawings and cross-validation

PDF text and vector content are extracted first; DXF entities are read through ezdxf. Each annotation keeps its original text, normalized value, unit, tolerance, page, source rectangle, extraction method, and confidence. OCR is optional and explicitly reported as unavailable when its engine is not installed.

Cross-validation compares only values with an explicit association or a bounded, documented best-match rule. Every result states its tolerance and shows both sources. A discrepancy review flag never deletes source evidence.

### Manufacturing plan

Only reviewed features at or above the configured threshold are mapped automatically. Suggested operations carry explicit time assumptions, setup, tool, accessibility evidence, and warnings. User edits are stored separately from the generated suggestion. The result is a planning estimate, not a CAM toolpath.

### Stock and estimate

The finished-part bounding box never changes. Raw-stock sizing applies configurable allowances to each side:

```text
required stock x = part x + negative-x allowance + positive-x allowance
required stock y = part y + negative-y allowance + positive-y allowance
required stock z = part z + negative-z allowance + positive-z allowance
```

The symmetric default is 2.0 mm per side and can be zero or asymmetric. For a selected blank, JobEval compares the selected envelope to the required envelope and reports excess or shortage. It never adds the allowance twice.

The estimate is calculated from saved inputs using a deterministic formula for each line. Overrides are visible and do not erase the calculated value. A saved estimate contains an immutable snapshot of rates, quantities, stock assumptions, formulas, warnings, and totals.

## Security and privacy

- CAD and drawing files are confidential local inputs by default.
- Original bytes are not sent to an LLM. Optional explanations receive only validated structured results.
- Filenames are metadata only; storage paths are generated and normalized.
- Upload size and supported types are validated before persistence.
- API keys come from environment variables. The core workflow works without one.
- Runtime database, uploads, generated reports, and customer data are ignored by Git.

## Deployment evolution

The local profile is the baseline. A deployment profile can add PostgreSQL, object storage, a durable queue, OCR, and an LLM provider without changing domain calculations. Contract version fields and migrations provide the upgrade boundary.
