#!/usr/bin/env python
"""Test cross-validation between STEP models and PDF drawings."""

import json
import re
import sys
import time
from pathlib import Path
from uuid import uuid4

# Add backend to path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.services.cad_service import CADService
from app.services.drawing_service import DrawingService
from app.services.cross_validation_service import CrossValidationService
from app.schemas.cad_specs import CADSpecs


def find_matching_pdf(step_file: Path, pdf_dir: Path) -> Path | None:
    """Find a matching PDF for a STEP file based on part number in filename."""
    step_name = step_file.stem.upper()
    # Extract part number pattern from step filename
    # e.g., PO-SG158971-142759-Part81460 -> Part81460
    part_match = re.search(r'PART(\d+)', step_name)
    if not part_match:
        return None

    part_num = part_match.group(1)

    # Search PDF directory for matching part number
    for pdf_file in sorted(pdf_dir.glob("*.pdf")):
        pdf_name = pdf_file.stem.upper()
        if part_num in pdf_name:
            return pdf_file

    return None


def main():
    testdata_dir = Path(__file__).resolve().parents[1] / "testdata"
    step_dir = testdata_dir / "step"
    pdf_dir = testdata_dir / "pdf"

    if not step_dir.exists():
        print(f"STEP directory not found: {step_dir}")
        return 1
    if not pdf_dir.exists():
        print(f"PDF directory not found: {pdf_dir}")
        return 1

    step_files = sorted(step_dir.glob("*.step")) + sorted(step_dir.glob("*.stp"))

    if not step_files:
        print("No STEP files found")
        return 1

    print(f"Found {len(step_files)} STEP files\n")

    cad_service = CADService()
    drawing_service = DrawingService()
    cv_service = CrossValidationService()

    results = []
    paired_count = 0

    for i, step_file in enumerate(step_files, 1):
        print(f"\n[{i}/{len(step_files)}] {step_file.name}")

        # Process STEP file
        try:
            project_id = str(uuid4())
            cad_specs = cad_service.process_cad_file(step_file, project_id)
            print(f"  STEP: OK ({cad_specs.processing_time_seconds:.2f}s, {len(cad_specs.features)} features)")
        except Exception as e:
            print(f"  STEP: FAIL - {e}")
            continue

        # Find matching PDF
        pdf_file = find_matching_pdf(step_file, pdf_dir)
        if pdf_file:
            paired_count += 1
            print(f"  PDF: Found match -> {pdf_file.name}")

            try:
                drawing_annotations = drawing_service.process_drawing(pdf_file, project_id)
                print(f"  Drawing: OK ({len(drawing_annotations.pages)} page(s))")

                # Run cross-validation
                cv_report = cv_service.validate(
                    drawing_annotations=drawing_annotations,
                    geometry_summary=cad_specs.geometry_summary,
                    model_features=cad_specs.features,
                    model_material=None,
                )

                print(f"  Cross-Validation: {cv_report.summary['matches']} matches, "
                      f"{cv_report.summary['mismatches']} mismatches, "
                      f"{cv_report.summary['drawing_only']} drawing-only, "
                      f"{cv_report.summary['model_only']} model-only")

                # Print key checks
                for check in cv_report.checks[:5]:
                    print(f"    - {check.property}: {check.status} "
                          f"(drawing={check.drawing}, model={check.model})")

                results.append({
                    "step_file": step_file.name,
                    "pdf_file": pdf_file.name,
                    "step_features": len(cad_specs.features),
                    "drawing_pages": len(drawing_annotations.pages),
                    "drawing_dimensions": sum(len(p.dimensions) for p in drawing_annotations.pages),
                    "cross_validation": {
                        "matches": cv_report.summary["matches"],
                        "mismatches": cv_report.summary["mismatches"],
                        "drawing_only": cv_report.summary["drawing_only"],
                        "model_only": cv_report.summary["model_only"],
                    },
                    "checks": [
                        {
                            "property": c.property,
                            "drawing": c.drawing,
                            "model": c.model,
                            "status": c.status,
                            "details": c.details,
                        }
                        for c in cv_report.checks
                    ],
                })

            except Exception as e:
                print(f"  Drawing/CV: FAIL - {e}")
                results.append({
                    "step_file": step_file.name,
                    "pdf_file": pdf_file.name,
                    "error": str(e),
                })
        else:
            print(f"  PDF: No matching drawing found")
            results.append({
                "step_file": step_file.name,
                "pdf_file": None,
                "step_features": len(cad_specs.features),
            })

    # Summary
    print("\n" + "=" * 80)
    print("CROSS-VALIDATION SUMMARY")
    print("=" * 80)
    print(f"STEP files processed: {len(step_files)}")
    print(f"Paired with drawings: {paired_count}")
    print(f"Unpaired STEP files: {len(step_files) - paired_count}")

    paired_results = [r for r in results if r.get("pdf_file")]
    if paired_results:
        total_matches = sum(r["cross_validation"]["matches"] for r in paired_results)
        total_mismatches = sum(r["cross_validation"]["mismatches"] for r in paired_results)
        total_drawing_only = sum(r["cross_validation"]["drawing_only"] for r in paired_results)
        total_model_only = sum(r["cross_validation"]["model_only"] for r in paired_results)
        print(f"\nTotal checks: {total_matches + total_mismatches + total_drawing_only + total_model_only}")
        print(f"  Matches: {total_matches}")
        print(f"  Mismatches: {total_mismatches}")
        print(f"  Drawing only: {total_drawing_only}")
        print(f"  Model only: {total_model_only}")

    # Save results
    output_path = testdata_dir / "cross_validation_test_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {output_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())