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


def test_cross_validation_drawing_only_dimension():
    """A drawing dimension with no corresponding non-zero model value is
    drawing_only."""
    drawing = {
        "dimensions": [
            {
                "id": "D-1-000",
                "type": "linear",
                "value": 75.0,
                "text": "Overall Length 75.0",
                "page": 1,
                "bbox": [0, 0, 10, 10],
                "source": "text",
            }
        ],
        "candidates": {},
    }
    # Model has zero length (degenerate flat part), so any drawing length is
    # drawing-only.
    analysis = {
        "geometry_summary": {
            "bbox": {"min": {"x": 0, "y": 0, "z": 0}, "max": {"x": 0, "y": 50.0, "z": 0}}
        },
        "features": [],
    }
    service = CrossValidationService({"dimension_mm": 0.5})
    result = service.validate(drawing, analysis)
    checks = {c["property"]: c for c in result["checks"]}
    assert "overall_length" in checks
    assert checks["overall_length"]["status"] == "drawing_only"
    assert checks["overall_length"]["drawing"] == 75.0
    assert checks["overall_length"]["model"] is None


def test_cross_validation_model_only_dimension():
    """A dimension in the model with no corresponding drawing value is
    model_only."""
    drawing = {
        "dimensions": [],
        "candidates": {},
    }
    analysis = {
        "geometry_summary": {
            "bbox": {"min": {"x": 0, "y": 0, "z": 0}, "max": {"x": 100.0, "y": 0, "z": 0}}
        },
        "features": [],
    }
    service = CrossValidationService({"dimension_mm": 0.5})
    result = service.validate(drawing, analysis)
    checks = {c["property"]: c for c in result["checks"]}
    assert "overall_length" in checks
    assert checks["overall_length"]["status"] == "model_only"
    assert checks["overall_length"]["drawing"] is None
    assert checks["overall_length"]["model"] == 100.0


def test_cross_validation_hole_count_mismatch():
    """Different hole counts between drawing and model is a mismatch."""
    drawing = {
        "dimensions": [
            {"id": "D-1", "type": "diameter", "value": 10.0, "text": "Ø10", "page": 1, "bbox": [0, 0, 10, 10], "source": "text"},
            {"id": "D-2", "type": "diameter", "value": 10.0, "text": "Ø10", "page": 1, "bbox": [0, 0, 10, 10], "source": "text"},
        ],
        "candidates": {},
    }
    analysis = {
        "geometry_summary": {
            "bbox": {"min": {"x": 0, "y": 0, "z": 0}, "max": {"x": 50.0, "y": 0, "z": 0}}
        },
        "features": [
            {
                "feature_id": "F-1",
                "type": "through_hole",
                "dimensions": {"diameter": 10.0},
            }
        ],
    }
    service = CrossValidationService({"dimension_mm": 0.5, "count": 0})
    result = service.validate(drawing, analysis)
    checks = {c["property"]: c for c in result["checks"]}
    assert "hole_count" in checks
    assert checks["hole_count"]["status"] == "mismatch"
    assert checks["hole_count"]["drawing"] == 2
    assert checks["hole_count"]["model"] == 1


def test_cross_validation_material_mismatch():
    """Different material names between drawing and model is a mismatch."""
    drawing = {
        "dimensions": [],
        "candidates": {"material": "STEEL"},
    }
    analysis = {
        "geometry_summary": {
            "bbox": {"min": {"x": 0, "y": 0, "z": 0}, "max": {"x": 50.0, "y": 0, "z": 0}}
        },
        "features": [],
    }
    service = CrossValidationService({"dimension_mm": 0.5})
    result = service.validate(drawing, analysis, model_material="AL 6061")
    checks = {c["property"]: c for c in result["checks"]}
    assert "material" in checks
    assert checks["material"]["status"] == "mismatch"
    assert checks["material"]["drawing"] == "STEEL"
    assert checks["material"]["model"] == "AL 6061"
