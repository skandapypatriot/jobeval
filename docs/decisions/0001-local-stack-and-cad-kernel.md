# ADR 0001: Local-first stack and CAD kernel

- **Status:** Accepted
- **Date:** 2026-11-22
- **Decision owners:** JobEval engineering

## Context

JobEval must be runnable locally without Docker, a hosted API, a paid service, or a customer CAD file. The initial vertical slice needs persistent projects, real STEP geometry analysis, deterministic manufacturing calculations, and a Flutter application on Windows and Web.

The repository's original scaffold assumed PostgreSQL, Redis, Celery, MinIO, and `pythonocc-core`. The development machine has no Docker daemon, and `pythonocc-core` is not installed for its Python 3.12 interpreter. Requiring those services would prevent the first runnable milestone.

## Decision

Use the following tested local stack:

| Component | Selected version | Verification on 2026-11-22 |
|---|---:|---|
| Flutter / Dart | 3.47.1 / 3.13.1 | `flutter --version`, `flutter doctor -v` |
| Python | 3.12.0 | `python --version` |
| FastAPI | 0.165.0 | import and API tests |
| Pydantic | 2.13.5 | import and contract tests |
| SQLAlchemy | 2.1.8 | import and persistence tests |
| build123d | 0.13.0 | STEP import/export probe succeeded |
| OCP / OCCT Python binding | `cadquery-ocp-novtk` / `cadquery-ocp-proxy` 8.0.1.1.0 | imported and tessellated a 10 x 20 x 30 mm block |
| PyMuPDF | 2.1 bindings | imported and fixture generation verified |
| ezdxf | 1.4.5 | imported and fixture generation verified |
| trimesh | 5.2.1 | imported; STL fallback is secondary |

- Use **SQLite + SQLAlchemy 2** as the default development persistence layer. Keep database access behind repositories so PostgreSQL can be added later.
- Run local analysis jobs through the application's bounded background-task mechanism. Do not require Redis or Celery for a single-machine workflow.
- Store uploaded files under an ignored runtime directory using generated names and sanitized metadata.
- Use **build123d/OCP** for STEP/B-Rep import and analysis. Do not claim `pythonocc-core` support until it is installed and tested in a supported environment.
- Render the triangulated CAD mesh in Flutter with a `CustomPainter` and explicit camera/mesh transforms. This is cross-platform and avoids a WebView/Three.js bridge on the critical path.
- Keep optional PostgreSQL, Redis, MinIO/S3, OCR, and OpenRouter integrations behind adapters/configuration. The core application must run without them.

## Rationale

This choice removes infrastructure blockers while preserving the required architecture boundaries. It provides actual analytic B-Rep geometry instead of counting mesh faces, persists data across restarts, and permits the Flutter UI and backend to evolve against validated JSON contracts. SQLite is appropriate for the local-first product scope; the repository abstraction is the compatibility boundary for a later server deployment.

The custom mesh renderer is less feature-rich than a full CAD viewer, but it supports orbit, pan, zoom, fit, axes, body selection, and feature highlighting on both Web and desktop without shipping an embedded browser engine. It is still an analysis viewer, not a CAM viewport.

## Risks and mitigations

- **OCP availability:** wheels may not exist for every Python/platform combination. The backend must report a missing-kernel dependency clearly and retain project/file persistence.
- **SQLite concurrency:** local background jobs and API writes are short. WAL mode and repository transactions are used where needed; production PostgreSQL remains an explicit future deployment option.
- **Background jobs in a single process:** jobs can be lost if the process exits. Job and result state is persisted so status and failures remain inspectable; a durable queue is deferred until distributed deployment is required.
- **STEP units:** OCCT normalizes imported lengths to millimetres. The source unit and confidence are retained separately so the UI never hides an ambiguity.
- **Custom viewer scale:** very large meshes are tessellated with bounded tolerances. If limits are exceeded, the API returns an actionable warning instead of an unbounded response.

## Revisit when

- Server-side multi-user deployment or durable distributed jobs is introduced.
- STEP import must support a Python/platform combination not covered by build123d/OCP wheels.
- The viewer needs sectioning, clipping, measurement, or full assembly interaction.
