#!/usr/bin/env python
"""Test manufacturing analysis on STEP-processed results."""

import json
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))

from app.services.cad_service import CADService
from app.services.manufacturing_service import ManufacturingService, estimate_cost
from app.schemas.cad_specs import Material


def main():
    testdata_dir = Path(__file__).resolve().parents[1] / "testdata"
    step_dir = testdata_dir / "step"

    step_files = sorted(step_dir.glob("*.step")) + sorted(step_dir.glob("*.stp"))

    if not step_files:
        print("No STEP files found")
        return 1

    cad_service = CADService()
    manufacturing_service = ManufacturingService()

    results = []

    for i, step_file in enumerate(step_files[:5], 1):  # Test first 5 for speed
        print(f"\n[{i}/5] {step_file.name}")

        try:
            from uuid import uuid4
            project_id = str(uuid4())
            cad_specs = cad_service.process_cad_file(step_file, project_id)
            print(f"  STEP: OK ({len(cad_specs.features)} features)")

            # Manufacturing analysis
            mfg_analysis = manufacturing_service.analyze_manufacturability(cad_specs)
            print(f"  Mfg: {mfg_analysis.machining_difficulty} difficulty")
            print(f"    Setups: {len(mfg_analysis.setups)}")
            print(f"    Operations: {len(mfg_analysis.operations)}")
            print(f"    Total time: {mfg_analysis.total_estimated_time_min:.1f} min")
            print(f"    Cutting: {mfg_analysis.total_cutting_time_min:.1f} min")
            print(f"    Setup: {mfg_analysis.total_setup_time_min:.1f} min")
            print(f"    Tool change: {mfg_analysis.total_tool_change_time_min:.1f} min")
            print(f"    Inspection: {mfg_analysis.total_inspection_time_min:.1f} min")
            print(f"    Stock: {mfg_analysis.stock_volume_cm3:.1f} cm3, {mfg_analysis.stock_weight_kg:.2f} kg")
            print(f"    Removal: {mfg_analysis.material_removal_volume_cm3:.1f} cm3")
            if mfg_analysis.inaccessible_features:
                print(f"    Inaccessible: {len(mfg_analysis.inaccessible_features)} features")
            if mfg_analysis.warnings:
                print(f"    Warnings: {len(mfg_analysis.warnings)}")
                for w in mfg_analysis.warnings[:3]:
                    print(f"      - {w}")

            # Cost estimate
            material = Material(
                name="Aluminum",
                grade="6061-T6",
                density_kg_m3=2700.0,
                source="default",
                confidence=0.9,
            )
            cost = estimate_cost(mfg_analysis, material, region="domestic", quantity=1)
            print(f"  Cost: ${cost.total_cost:.2f} (material: ${cost.material_cost:.2f}, "
                  f"machining: ${cost.machining_cost:.2f}, setup: ${cost.setup_cost:.2f})")

            results.append({
                "file": step_file.name,
                "features": len(cad_specs.features),
                "setups": len(mfg_analysis.setups),
                "operations": len(mfg_analysis.operations),
                "difficulty": mfg_analysis.machining_difficulty,
                "total_time_min": mfg_analysis.total_estimated_time_min,
                "total_cost_usd": cost.total_cost,
                "inaccessible": len(mfg_analysis.inaccessible_features),
                "warnings": len(mfg_analysis.warnings),
            })

        except Exception as e:
            print(f"  FAIL: {e}")
            import traceback
            traceback.print_exc()

    # Save results
    output_path = testdata_dir / "manufacturing_test_results.json"
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {output_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())