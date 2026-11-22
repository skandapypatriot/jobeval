# ADR 0004: Cross-platform triangulated CAD viewer

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

JobEval must display imported CAD on Windows desktop and Web and link feature review selections to geometry. A WebView-hosted Three.js scene was proposed, but it introduces platform-specific WebView, JavaScript bridge, asset, and input-coordinate risks.

## Decision

Use a Flutter `CustomPainter` with the backend's bounded triangulated mesh. The painter owns camera state and transforms vertices/triangles for orbit, pan, zoom, fit-to-view, axes, bounds, body selection, and feature highlighting.

The backend tessellates each body and face with bounded tolerance and preserves body/face identifiers where available. The UI treats this as an analysis viewer, not a CAD/CAM viewport. Missing or invalid mesh data produces an explicit empty/error state; no placeholder solid is displayed as if it were the uploaded part.

## Rationale

The custom renderer uses Flutter's input and painting systems on every target, has no JavaScript bridge, and keeps API data simple and inspectable. It is enough to make geometry and feature review visibly connected in the first release.

## Limitations and future work

This decision does not provide section planes, clipping, exact measurement, PMI/GD&T display, assembly constraints, or full feature-intent reconstruction. If those requirements become central, a maintained WebView/Three.js or native OpenGL component can be introduced behind the same mesh/selection contract.
