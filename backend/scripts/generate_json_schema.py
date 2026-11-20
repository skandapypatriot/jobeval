#!/usr/bin/env python
"""Generate JSON Schema from Pydantic models for cad_specs.json validation."""

import json
from pathlib import Path

from app.schemas.cad_specs import CADSpecs


def main():
    output_dir = Path(__file__).parent.parent / "app" / "schemas" / "json_schema"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Generate schema
    schema = CADSpecs.model_json_schema()

    # Write schema file
    schema_path = output_dir / "cad_specs.schema.json"
    with open(schema_path, "w") as f:
        json.dump(schema, f, indent=2)

    print(f"Generated JSON Schema: {schema_path}")

    # Also generate a minimal example
    example = {
        "version": "1.0",
        "job_id": "example-job-id",
        "created_at": "2024-01-15T10:30:00Z",
        "source_files": [
            {
                "role": "model_3d",
                "path": "part.step",
                "format": "STEP",
                "size_bytes": 123456,
                "sha256": "abc123..."
            }
        ],
        "units": {
            "source": "mm",
            "normalized": "mm",
            "confidence": 1.0
        },
        "geometry_summary": {
            "num_bodies": 1,
            "num_shells": 1,
            "num_faces": 50,
            "num_edges": 120,
            "num_vertices": 60,
            "volume": 125000.0,
            "surface_area": 45000.0,
            "bbox": {
                "min": {"x": 0, "y": 0, "z": 0},
                "max": {"x": 100, "y": 50, "z": 25}
            },
            "center_of_mass": {"x": 50, "y": 25, "z": 12.5},
            "principal_axes": [
                {"x": 1, "y": 0, "z": 0},
                {"x": 0, "y": 1, "z": 0},
                {"x": 0, "y": 0, "z": 1}
            ],
            "symmetry": {}
        },
        "features": [
            {
                "feature_id": "F-001",
                "type": "through_hole",
                "position": {"x": 25, "y": 25, "z": 0},
                "axis": {"x": 0, "y": 0, "z": 1},
                "dimensions": {"diameter": 10, "depth": 25},
                "depth_type": "through",
                "faces": ["face_1", "face_2", "face_3"],
                "open": True,
                "through": True,
                "confidence": 0.95,
                "detection_method": "cylindrical_face_pair_with_planar_caps"
            }
        ],
        "feature_relationships": [],
        "confidence_report": {
            "overall_confidence": 0.9,
            "geometry_confidence": 0.95,
            "feature_confidence": 0.9,
            "manufacturing_confidence": 0.8,
            "cost_confidence": 0.7
        },
        "warnings": []
    }

    example_path = output_dir / "cad_specs.example.json"
    with open(example_path, "w") as f:
        json.dump(example, f, indent=2)

    print(f"Generated example: {example_path}")


if __name__ == "__main__":
    main()