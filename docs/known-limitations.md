# Known limitations

This document describes the implementation and its honest boundaries. It must be updated whenever support changes.

## CAD and geometry

- STEP (`.step`, `.stp`) is the implemented analytic B-Rep path. STL is a mesh and cannot provide the same topology-aware feature quality; any STL fallback is labelled as mesh-only.
- IGES, BREP, native DXF-to-solid conversion, and DWG are not supported in the initial release. DWG is not converted through an unlicensed proprietary converter.
- STEP source units are detected where the file provides evidence. An ambiguous unit is not silently assumed to be millimetres.
- Import warnings and validity results describe the imported source. JobEval does not silently heal or overwrite an invalid source.
- Feature recognition is evidence-based candidate detection, not a certified recognition system. Confidence is not a measured precision/recall probability until labelled fixtures are evaluated.
- Initial feature coverage is holes, hole variants, slots/pockets, steps/shoulders, fillets/chamfers where the available topology supports them. Threads require explicit drawing evidence; a plain cylinder is not labelled as a thread.
- Multi-body assemblies are summarized and displayed, but fixture/assembly constraints are not yet a complete manufacturing constraint solver.

## Drawings

- PDF extraction prefers embedded text and vector content. Raster-only OCR is optional and is not available when its engine/dependency is missing.
- DXF support is intentionally limited to supported entities and text/dimension values. Blocks and annotative entities may be flattened or reported as unsupported.
- Drawing-to-model association is evidence-limited. Ambiguous dimensions are `needs_review`, never forced into a match.
- GD&T is presented as a candidate review item, not a standards-certified interpretation.
- Material and finish notes are recognized conservatively; a low-confidence note does not overwrite a user-selected material.

## Manufacturing estimate

- The estimate covers candidate **3-axis milling** planning only. It does not support turning, EDM, grinding, additive, 4-axis, or 5-axis manufacturing.
- Candidate operations are not generated or simulated toolpaths. There is no collision simulation, gouge checking, cutting-force model, or machine-post validation.
- Feeds, speeds, stepdowns, engagement, tool changes, setup, and labour times are explicit assumptions or editable estimates. A precise cycle time cannot be claimed from incomplete geometry.
- Accessibility is a reviewable heuristic based on candidate approach direction and available evidence, not a proof that a tool can reach every feature.
- Taxes, contingency, margin, and overhead are visible quote assumptions, not universal market rates. Seed rates are labelled sample/demo pricing and are not live supplier quotes.

## Viewer

- The first viewer is a triangulated analysis renderer with orbit, pan, zoom, fit, axes, body selection, and feature highlighting.
- It does not yet include section planes, clipping, precise 3D measurement, assembly constraints, or full PMI/GD&T visualization.

## Platform and operations

- Web and Windows desktop are the primary development targets. Android support is architectural; device-level validation depends on the available SDK/emulator.
- A single-process local job runner is not a durable distributed queue. Persisted job state remains inspectable after interruption, but work may need to be restarted.
- The optional OpenRouter explanation is disabled without an API key and can only produce labelled prose. It cannot change geometry, dimensions, feature data, operations, times, prices, or confidence.
