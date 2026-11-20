#!/usr/bin/env python
"""Test CAD import on all STEP files in testdata/ and validate geometry extraction."""

import json
import sys
import time
from pathlib import Path
from uuid import uuid4

# Add backend to path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.services.cad_service import CADService
from app.schemas.cad_specs import CADSpecs


def test_step_file(step_path: Path, cad_service: CADService) -> dict:
    """Test import and geometry extraction on a single STEP file."""
    result = {
        "file": step_path.name,
        "success": False,
        "error": None,
        "geometry": None,
        "features": [],
        "warnings": [],
        "processing_time_sec": 0,
    }

    try:
        start = time.time()
        # Create a mock project ID
        project_id = str(uuid4())
        cad_specs = cad_service.process_cad_file(step_path, project_id)
        elapsed = time.time() - start

        result["success"] = True
        result["processing_time_sec"] = round(elapsed, 3)
        result["geometry"] = {
            "num_bodies": cad_specs.geometry_summary.num_bodies if cad_specs.geometry_summary else 0,
            "num_faces": cad_specs.geometry_summary.num_faces if cad_specs.geometry_summary else 0,
            "num_edges": cad_specs.geometry_summary.num_edges if cad_specs.geometry_summary else 0,
            "num_vertices": cad_specs.geometry_summary.num_vertices if cad_specs.geometry_summary else 0,
            "volume_mm3": round(cad_specs.geometry_summary.volume, 3) if cad_specs.geometry_summary else 0,
            "surface_area_mm2": round(cad_specs.geometry_summary.surface_area, 3) if cad_specs.geometry_summary else 0,
            "bbox_min": [round(cad_specs.geometry_summary.bbox.min.x, 3), round(cad_specs.geometry_summary.bbox.min.y, 3), round(cad_specs.geometry_summary.bbox.min.z, 3)] if cad_specs.geometry_summary else None,
            "bbox_max": [round(cad_specs.geometry_summary.bbox.max.x, 3), round(cad_specs.geometry_summary.bbox.max.y, 3), round(cad_specs.geometry_summary.bbox.max.z, 3)] if cad_specs.geometry_summary else None,
            "center_of_mass": [round(cad_specs.geometry_summary.center_of_mass.x, 3), round(cad_specs.geometry_summary.center_of_mass.y, 3), round(cad_specs.geometry_summary.center_of_mass.z, 3)] if cad_specs.geometry_summary else None,
        } if cad_specs.geometry_summary else None
        result["features"] = [{"id": f.feature_id, "type": f.type, "confidence": f.confidence} for f in cad_specs.features]
        result["warnings"] = [w.message for w in cad_specs.warnings]

    except Exception as e:
        result["error"] = str(e)
        import traceback
        result["traceback"] = traceback.format_exc()

    return result


def main():
    testdata_dir = Path(__file__).resolve().parents[1] / "testdata"
    step_dir = testdata_dir / "step"
    
    if not step_dir.exists():
        print(f"STEP directory not found: {step_dir}")
        return 1

    step_files = sorted(step_dir.glob("*.step")) + sorted(step_dir.glob("*.stp"))
    
    if not step_files:
        print("No STEP files found")
        return 1

    print(f"Found {len(step_files)} STEP files to test\n")
    print("=" * 80)

    cad_service = CADService()
    results = []

    for i, step_file in enumerate(step_files, 1):
        print(f"\n[{i}/{len(step_files)}] Testing: {step_file.name}")
        print("-" * 80)
        
        result = test_step_file(step_file, cad_service)
        results.append(result)

        if result["success"]:
            geo = result["geometry"]
            print(f"  OK Success ({result['processing_time_sec']}s)")
            if geo:
                print(f"    Bodies: {geo['num_bodies']} | Faces: {geo['num_faces']} | Edges: {geo['num_edges']} | Vertices: {geo['num_vertices']}")
                print(f"    Volume: {geo['volume_mm3']:.1f} mm³ | Surface: {geo['surface_area_mm2']:.1f} mm²")
                if geo['bbox_min'] and geo['bbox_max']:
                    dx = geo['bbox_max'][0] - geo['bbox_min'][0]
                    dy = geo['bbox_max'][1] - geo['bbox_min'][1]
                    dz = geo['bbox_max'][2] - geo['bbox_min'][2]
                    print(f"    BBox: {dx:.1f} x {dy:.1f} x {dz:.1f} mm")
                print(f"    CoM: ({geo['center_of_mass'][0]:.1f}, {geo['center_of_mass'][1]:.1f}, {geo['center_of_mass'][2]:.1f})")
            print(f"    Features found: {len(result['features'])}")
            for f in result['features']:
                print(f"      - {f['id']}: {f['type']} (conf: {f['confidence']:.2f})")
            if result['warnings']:
                print(f"    Warnings: {len(result['warnings'])}")
                for w in result['warnings']:
                    print(f"      WARN {w}")
        else:
            print(f"  FAIL Failed: {result['error']}")
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
        total_faces = sum(r["geometry"]["num_faces"] for r in successful if r["geometry"])
        total_features = sum(len(r["features"]) for r in successful)
        avg_time = sum(r["processing_time_sec"] for r in successful) / len(successful)
        print(f"Total faces processed: {total_faces}")
        print(f"Total features detected: {total_features}")
        print(f"Avg processing time: {avg_time:.3f}s")

    if failed:
        print("\nFailed files:")
        for r in failed:
            print(f"  - {r['file']}: {r['error'][:100]}")

    # Save results
    output_path = testdata_dir / "cad_import_test_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {output_path}")

    return 0 if len(failed) == 0 else 1


if __name__ == "__main__":
    sys.exit(main())