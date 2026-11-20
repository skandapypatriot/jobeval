#!/usr/bin/env python
"""Test drawing analysis on all PDF files in testdata/."""

import json
import sys
import time
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.services.drawing_service import DrawingService


def test_pdf_file(pdf_path: Path, drawing_service: DrawingService) -> dict:
    """Test drawing analysis on a single PDF file."""
    result = {
        "file": pdf_path.name,
        "success": False,
        "error": None,
        "pages": 0,
        "dimensions_found": 0,
        "gd_t_found": 0,
        "surface_finish_found": 0,
        "notes_found": 0,
        "title_block": None,
        "processing_time_sec": 0,
    }

    try:
        start = time.time()
        annotations = drawing_service.process_drawing(pdf_path, "test-project-001")
        elapsed = time.time() - start

        result["success"] = True
        result["processing_time_sec"] = round(elapsed, 3)
        result["pages"] = annotations.total_pages

        total_dims = 0
        total_gd = 0
        total_sf = 0
        total_notes = 0
        title_block = None

        for page in annotations.pages:
            total_dims += len(page.dimensions)
            total_gd += len(page.gd_t)
            total_sf += len(page.surface_finish)
            total_notes += len(page.notes)
            if page.title_block:
                title_block = {
                    "part_number": page.title_block.part_number,
                    "revision": page.title_block.revision,
                    "material": page.title_block.material,
                    "finish": page.title_block.finish,
                    "scale": page.title_block.scale,
                    "sheet": page.title_block.sheet,
                }

        result["dimensions_found"] = total_dims
        result["gd_t_found"] = total_gd
        result["surface_finish_found"] = total_sf
        result["notes_found"] = total_notes
        result["title_block"] = title_block

    except Exception as e:
        result["error"] = str(e)
        import traceback
        result["traceback"] = traceback.format_exc()

    return result


def main():
    testdata_dir = Path(__file__).resolve().parents[1] / "testdata"
    pdf_dir = testdata_dir / "pdf"

    if not pdf_dir.exists():
        print(f"PDF directory not found: {pdf_dir}")
        return 1

    pdf_files = sorted(pdf_dir.glob("*.pdf"))

    if not pdf_files:
        print("No PDF files found")
        return 1

    print(f"Found {len(pdf_files)} PDF files to test\n")
    print("=" * 80)

    drawing_service = DrawingService()
    results = []

    for i, pdf_file in enumerate(pdf_files, 1):
        print(f"\n[{i}/{len(pdf_files)}] Testing: {pdf_file.name}")
        print("-" * 80)

        result = test_pdf_file(pdf_file, drawing_service)
        results.append(result)

        if result["success"]:
            print(f"  OK Success ({result['processing_time_sec']}s)")
            print(f"    Pages: {result['pages']}")
            print(f"    Dimensions: {result['dimensions_found']}")
            print(f"    GD&T: {result['gd_t_found']}")
            print(f"    Surface Finish: {result['surface_finish_found']}")
            print(f"    Notes: {result['notes_found']}")
            if result["title_block"]:
                print(f"    Title Block: {result['title_block']}")
        else:
            print(f"  FAIL Failed: {result['error'][:200]}")
            if 'traceback' in result:
                print(f"    {result['traceback'][:500]}...")

    # Summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    successful = [r for r in results if r["success"]]
    failed = [r for r in results if not r["success"]]

    print(f"Total: {len(results)} | Success: {len(successful)} | Failed: {len(failed)}")

    if successful:
        total_dims = sum(r["dimensions_found"] for r in successful)
        total_gd = sum(r["gd_t_found"] for r in successful)
        total_sf = sum(r["surface_finish_found"] for r in successful)
        total_notes = sum(r["notes_found"] for r in successful)
        avg_time = sum(r["processing_time_sec"] for r in successful) / len(successful)
        print(f"Total dimensions: {total_dims}")
        print(f"Total GD&T: {total_gd}")
        print(f"Total surface finish: {total_sf}")
        print(f"Total notes: {total_notes}")
        print(f"Avg processing time: {avg_time:.3f}s")

    if failed:
        print("\nFailed files:")
        for r in failed:
            print(f"  - {r['file']}: {r['error'][:100]}")

    # Save results
    output_path = testdata_dir / "drawing_analysis_test_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {output_path}")

    return 0 if len(failed) == 0 else 1


if __name__ == "__main__":
    sys.exit(main())