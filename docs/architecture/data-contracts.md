# Core data contracts

The backend Pydantic models are authoritative. This document names the contract groups and the provenance rules that the Flutter client must preserve.

## Provenance values

A displayed numeric or categorical value can carry a source label:

| Source | Meaning |
|---|---|
| `source` | Read directly from the CAD/drawing file |
| `inferred` | Determined from deterministic geometry/evidence rules |
| `default` | Application or sample-profile assumption |
| `user_edited` | Explicit user correction/override |

Provenance describes where a value came from; it does not imply that the value is verified. Confidence is separate and only appears where the backend defines a reproducible evidence score.

## Project and source file

A project owns source files and analysis jobs. A source file records the sanitized original name, generated storage key, media/category, byte size, SHA-256 digest, creation time, processing state, and detected source unit. The original bytes are immutable.

## Geometry summary

The geometry contract contains:

- schema version and source file ID;
- working unit (`mm`) and detected source unit plus unit confidence;
- body, solid, shell, face, edge, and vertex counts;
- axis-aligned bounds and dimensions;
- volume, surface area, and center of mass with units;
- validity state, import warnings, and any repair/healing log;
- bounded triangle mesh grouped by body and face where possible.

A failed import has a job error and no fabricated geometry payload.

## Feature candidate

Each feature contains a stable ID, type/subtype, body/face references, dimensions with units, axis/position, classification such as through/blind, evidence, detection method, warnings, confidence, accessibility, and review state.

`raw_detection` is immutable. User review data is separate and identifies `confirmed`, `corrected`, `excluded`, or `manually_created` status. A feature is eligible for automatic costing only when it is confirmed (or explicitly accepted by the user) and meets the confidence threshold.

## Drawing annotation

Each annotation preserves the original text, normalized numeric value and unit, parsed tolerance, page/view ID, source rectangle/entity ID, extraction method, confidence, annotation kind, and review state. OCR-derived text records the image region and OCR method.

## Cross-validation check

A check has stable IDs for both sources, check kind, source values, normalized comparison values, comparison tolerance and rule, status (`match`, `mismatch`, `drawing_only`, `model_only`, `needs_review`), explanation, evidence, and review state. Reviewing a discrepancy never removes either source value.

## Manufacturing plan

A plan contains stock orientation, setup records, operation records, tool/machine assumptions, warnings, and generation status. Each operation records whether it is suggested or user-confirmed, its source features, tool, sequence, setup, estimated duration components, manual duration override, accessibility evidence, and warnings.

## Pricing profile and estimate

The profile contains currency, quantity, material definition, selected stock blank, per-side allowances, machine/labour/auxiliary rates, operation rates/fixed overrides, and commercial percentages. Missing values are `null`, not implicit zero.

An estimate contains an immutable snapshot, line items, totals, warnings, confidence/uncertainty notes, and timestamps. Every line item contains quantity, unit, rate, calculated amount, override amount, formula/basis, and subtotal.

## Jobs

A job has a stable ID, project ID, kind, state (`queued`, `processing`, `completed`, `failed`, `cancelled`), progress, created/started/finished timestamps, a bounded log, result reference, and an actionable error. Cancellation is cooperative and safe only before irreversible output is committed.
