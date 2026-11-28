# API contract and schema versioning

JobEval exposes versioned REST resources under `/api/v1`. FastAPI's generated OpenAPI document is the authoritative route and field reference. The source of truth for domain payloads is the Pydantic schema set in `backend/app/schemas`; the Flutter client parses those JSON objects into typed models.

## Versioning rules

- The URL prefix identifies the API generation. Breaking changes require a new prefix such as `/api/v2` or an explicit migration plan.
- Persisted analysis, plan, pricing, and estimate payloads carry a `schema_version` field.
- Additive optional fields are allowed within v1. Removing a field, changing its unit, changing its meaning, or making an optional field required is breaking.
- Units are explicit in field names or metadata (`_mm`, `_mm2`, `_mm3`, `currency`) and are never inferred by the client from a number alone.
- Timestamps are ISO 8601 UTC strings. IDs are opaque stable strings.
- Monetary values use decimal JSON numbers and the currency declared by the estimate/profile. The backend is responsible for rounding.
- API errors use FastAPI's `detail` shape for validation and a consistent HTTP status. Ordinary responses do not expose stack traces.

## Raw and reviewed data

Geometry and feature detections are never overwritten by a user edit. The raw result remains in the analysis payload, while review state and corrections are stored separately and merged into a review view. A client can therefore distinguish detected, inferred, default, and user-edited values.

## Estimate snapshots

A saved estimate is an immutable snapshot of its inputs and line items. Updating global/project pricing creates a new calculation; it does not mutate earlier estimates. Report exports use the same snapshot returned by the estimate endpoint.

## Compatibility review

Before a frontend release, compare its parsing code with the backend OpenAPI schema. Unknown additive fields are ignored safely. Missing required fields are treated as an API/version error with a retry or refresh action, not as a fabricated zero or empty result.
