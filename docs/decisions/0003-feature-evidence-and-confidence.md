# ADR 0003: Evidence-based feature candidates

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

Counting cylindrical faces is not feature recognition. A cylindrical face may be an outer boss, shaft, or a hole, and a hole can be represented by split/seamed faces. JobEval must avoid presenting a primitive-count heuristic as manufacturing geometry.

## Decision

Feature candidates are built from a combination of:

- analytic surface type and parameters;
- face orientation/concavity relative to the owning solid;
- boundary loops and circular/linear edge evidence;
- adjacent faces and containment;
- axial extents versus the solid bounding box;
- multiple independent evidence items.

Candidates are grouped and deduplicated by geometric proximity, axis, and compatible dimensions. Raw detection is persisted separately from user review state. A feature exposes evidence, warnings, an approach direction, an accessibility assessment, and a score from 0.0 to 1.0.

The score is an evidence/interpretation category, not a statistical guarantee:

- 0.90–1.00: unambiguous evidence match;
- 0.70–0.89: strong candidate with minor ambiguity;
- 0.50–0.69: plausible, needs confirmation;
- 0.30–0.49: weak candidate, likely false positive;
- below 0.30: unknown/unclassified.

Only reviewed candidates at or above the configured automatic-cost threshold contribute to an estimate. Weak candidates remain visible for inspection.

Thread labels require explicit drawing/evidence support. A plain cylinder is never silently labelled as tapped.

## Consequences

- Coverage varies with topology and source quality, especially for mesh-only files.
- Detectors must expose warnings when evidence is incomplete.
- Labelled fixtures are required before precision/recall can be reported.
- User corrections never mutate raw evidence, preserving reproducibility and auditability.
