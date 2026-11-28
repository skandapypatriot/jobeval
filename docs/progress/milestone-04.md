# Milestone 04 — Drawing parser and annotation review

**Date:** 2026-11-28  
**Branch:** `feat/incremental-jobeval-build`  
**Commit:** `900b669` (pushed) + new tests committed separately  
**Remote:** `https://github.com/skandapypatriot/jobeval.git`  
**Push status:** Pending for new test commits

## Features completed

- **Drawing upload** (already implemented): PDF and DXF file upload with multipart progress, content validation (magic bytes check), safe storage with generated filenames.
- **PDF text/vector extraction** (already implemented): PyMuPDF extracts embedded text blocks, vector paths, page dimensions, and per-block source bboxes. No OCR required for vector-based PDFs.
- **DXF entity extraction** (already implemented): ezdxf reads TEXT, MTEXT, DIMENSION, LINE, CIRCLE, ARC, LWPOLYLINE, POLYLINE, SPLINE entities with source bbox evidence.
- **Dimension parsing** (already implemented): regex-based detection of diameter (Ø), radius (R), depth, thread (M/UNC/UNF), chamfer, fillet radius, angular (°), and linear dimensions. Each carries original text, normalized value, unit (mm), tolerance, page, source bbox, extraction method, and confidence.
- **Title block extraction** (already implemented): part number, revision, material, finish, title, and scale detected from drawing text.
- **GD&T candidates** (already implemented): flatness, straightness, circularity, cylindricity, parallelism, perpendicularity, angularity, position, concentricity detected from drawing text.
- **OCR availability reporting** (already implemented): reports whether Tesseract is installed and whether OCR was used; never pretends OCR was performed when it wasn't.
- **Drawing review UI** (already implemented): pages list, extracted dimensions, notes, GD&T candidates, title block fields, confidence bands, source region evidence.

## New test coverage added for Milestone 04

| Test | What it verifies |
|---|---|
| `test_drawing_dimension_has_source_evidence` | Every dimension has id, type, unit=mm, evidence with page+bbox |
| `test_drawing_title_block_fields` | Title block exposes part_number, revision, material, finish, title, scale |
| `test_drawing_gdt_candidates` | GD&T candidates (flatness, etc.) extracted with page+bbox evidence |
| `test_drawing_ocr_unavailable_when_engine_missing` | OCR reports unavailable when Tesseract not installed |
| `test_drawing_rejects_unsupported_format` | Non-drawing file upload rejected with 415 |

## What is visibly available in the Flutter app

1. **Drawing review screen** (`/projects/:id/drawings`): pages list, extracted dimensions with confidence, notes categorized by type (material/finish/GDT/general), GD&T candidates, title block fields, source page/bbox for every annotation.
2. **Upload screen** (`/projects/:id/upload`): drag-and-drop/file picker for PDF/DXF, content validation, upload progress.

## Exact steps to reproduce

Backend:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
Verify:
```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/v1/health | ConvertTo-Json
```

Frontend:
```powershell
cd C:\Users\casmm\jobeval\frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```
Then: create project → upload PDF/DXF drawing → Drawing screen → inspect pages, dimensions, GD&T, title block → inspect source evidence.

Tests:
```powershell
cd C:\Users\casmm\jobeval\backend
.\.venv\Scripts\python -m pytest -q
cd C:\Users\casmm\jobeval\frontend
flutter analyze && flutter test
```

## Sample input and actual output

Input: `write_pdf_drawing()` helper creates a PDF with:
- "PART NO: ABC-123", "REV: A", "MATERIAL: AL 6061", "TITLE: Test Bracket"
- "Overall Length 100.0", "Ø10.0 THRU", "FLATNESS 0.1"

Output:
- `analysis.format` = "pdf"
- `analysis.total_pages` >= 1
- `analysis.dimensions` includes: diameter 10.0, linear 100.0 — each with bbox, evidence, confidence
- `analysis.candidates.material` = "AL 6061" (or similar)
- `analysis.pages[0].title_block` includes part_number="ABC-123", revision="A", material="AL 6061", title="Test Bracket"
- `analysis.gdt` includes flatness candidate
- `analysis.ocr.available` = false, `analysis.ocr.used` = false

Input: `not_a_drawing.txt`
- Upload returns 415 Unsupported Media Type

## Tests run

- Backend: 48 passed, 0 failed (43 previous + 5 new drawing tests)
- Flutter: analyze no issues; 6 widget tests passed

## Known bugs and limitations

- PDF extraction prefers embedded text/vector; scanned/raster-only PDFs report OCR unavailable and produce no dimensions.
- DXF support is limited to supported entities; blocks and annotative entities may be flattened.
- Title block regex patterns are conservative; unusual title block layouts may not be recognized.
- GD&T is presented as candidate review items, not standards-certified interpretations.
- Extraction accuracy is measured per annotation type; no blanket percentage is claimed from small test fixtures.

## Screenshots

None captured (no automated screenshot tooling configured). No mockups substituted.

## Git

- Branch: `feat/incremental-jobeval-build`
- Previous commit: `900b669` (pushed)
- New test commits: pending push
- Remote: `origin` = `https://github.com/skandapypatriot/jobeval.git` (tracking `origin/feat/incremental-jobeval-build`)

## Next milestone's concrete tasks

- Milestone 05 (Drawing/model cross-validation): verify seeded mismatch detection, configurable tolerances, review-state persistence without deleting source evidence.
- Milestone 06 (3-axis CNC plan and operation editor): verify feature-to-operation mapping, setup grouping, costing confidence threshold, user edits to operations.
- Push the new test commits to GitHub.
