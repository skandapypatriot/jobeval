"""Cross-validation seeded mismatch tests."""

from app.services.cross_validation_service import CrossValidationService


def test_cross_validation_seeded_mismatch():
    drawing = {
        "dimensions": [
            {
                "id": "D-1-000",
                "type": "linear",
                "value": 100.0,
                "text": "Overall Length 100.0",
                "page": 1,
                "bbox": [0, 0, 10, 10],
                "source": "text",
            }
        ],
        "candidates": {"material": "AL 6061"},
    }
    analysis = {
        "geometry_summary": {
            "bbox": {"min": {"x": 0, "y": 0, "z": 0}, "max": {"x": 150.0, "y": 0, "z": 0}}
        },
        "features": [],
    }
    service = CrossValidationService({"dimension_mm": 0.5})
    result = service.validate(drawing, analysis)
    checks = {c["property"]: c for c in result["checks"]}
    assert "overall_length" in checks
    assert checks["overall_length"]["status"] == "mismatch", checks["overall_length"]
    assert checks["overall_length"]["drawing"] == 100.0
    assert checks["overall_length"]["model"] == 150.0
    assert result["summary"]["mismatch"] >= 1
    assert result["status"] == "needs_review"


def test_cross_validation_match():
    drawing = {
        "dimensions": [
            {
                "id": "D-1-000",
                "type": "linear",
                "value": 100.0,
                "text": "Overall Length 100.0",
                "page": 1,
                "bbox": [0, 0, 10, 10],
                "source": "text",
            },
            {
                "id": "D-1-001",
                "type": "linear",
                "value": 50.0,
                "text": "Overall Width 50.0",
                "page": 1,
                "bbox": [0, 20, 10, 30],
                "source": "text",
            },
            {
                "id": "D-1-002",
                "type": "linear",
                "value": 25.0,
                "text": "Overall Height 25.0",
                "page": 1,
                "bbox": [0, 40, 10, 50],
                "source": "text",
            },
        ],
        "candidates": {"material": "AL 6061"},
    }
    analysis = {
        "geometry_summary": {
            "bbox": {
                "min": {"x": 0, "y": 0, "z": 0},
                "max": {"x": 100.0, "y": 50.0, "z": 25.0},
            }
        },
        "features": [],
    }
    service = CrossValidationService({"dimension_mm": 0.5})
    result = service.validate(drawing, analysis, model_material="AL 6061")
    length_check = next(c for c in result["checks"] if c["property"] == "overall_length")
    assert length_check["status"] == "match"
    width_check = next(c for c in result["checks"] if c["property"] == "overall_width")
    assert width_check["status"] == "match"
    height_check = next(c for c in result["checks"] if c["property"] == "overall_height")
    assert height_check["status"] == "match"
    material_check = next(c for c in result["checks"] if c["property"] == "material")
    assert material_check["status"] == "match"
    assert result["status"] == "match"
