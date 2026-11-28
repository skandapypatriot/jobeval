# ADR 0002: Deterministic pricing and stock envelopes

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

A quote must be reproducible, editable, and auditable. The UI also needs a configurable machining allowance on every side of the finished part. This allowance is a stock-sizing/quoting assumption; it is not a part dimension, tolerance, or guaranteed machining requirement.

## Decision

### Finished and stock geometry are separate

The imported CAD bounding box remains the finished-part geometry. Stock envelopes are calculated in a dedicated pricing service:

```text
required_x = finished_x + allowance_x_negative + allowance_x_positive
required_y = finished_y + allowance_y_negative + allowance_y_positive
required_z = finished_z + allowance_z_negative + allowance_z_positive
```

The default is 2.0 mm on each side. Users can set zero or different positive/negative values.

A selected rectangular blank is compared with the required envelope. Its dimensions are used to cost the blank; allowances are not added again. The UI reports excess, shortage, or exact fit per axis. Round stock uses a separately defined diameter/length calculation.

### Rates are explicit inputs

Material density and price, machine/labour time rates, setup, tool changes, programming, inspection, finishing/deburring, overhead, margin, contingency, and tax are persisted inputs. A missing rate produces a visible warning and a non-costed line; it never becomes a hidden zero.

### Every calculation is a line item

Each estimate line records:

- stable key and description;
- quantity and unit;
- source/calculated rate;
- user override, if any;
- formula or basis;
- rounded subtotal;
- warning/confidence metadata where relevant.

Line items are rounded using one documented currency rule. Totals are calculated from the persisted rounded line items so a saved report reproduces the displayed total.

### Saved estimates are snapshots

A saved estimate stores the complete pricing profile, plan assumptions, quantities, formulas, warnings, and totals. Later edits to global or project defaults do not mutate that estimate. Recalculation creates a new snapshot.

## Rationale

Separating finished geometry from stock prevents a subtle but material pricing error. Keeping calculated and overridden values visible lets a machinist audit why a price changed. Immutable snapshots make old quotes reproducible and prevent later price updates from rewriting history.

## Consequences

- Users must configure rates that matter to their shop.
- A quote may intentionally show an incomplete total when rates are missing; this is safer than a deceptively low total.
- Stock defaults are assumptions rather than engineering rules and must be labelled as such in the UI and report.
- Live supplier prices are not implied. Seed rates are sample data unless the user provides a source.
