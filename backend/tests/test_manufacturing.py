"""3-axis CNC manufacturing plan tests."""

from app.services.manufacturing_service import ManufacturingService


def _make_analysis(features):
    """Build a minimal analysis payload with the given features."""
    return {
        "geometry_summary": {
            "bbox": {
                "min": {"x": 0, "y": 0, "z": 0},
                "max": {"x": 100.0, "y": 50.0, "z": 25.0},
            }
        },
        "features": features,
    }


def test_feature_to_operation_mapping():
    """Every recognised feature type maps to a valid 3-axis operation."""
    service = ManufacturingService()
    feature_types = [
        ("through_hole", "drilling"),
        ("blind_hole", "drilling"),
        ("counterbore", "counterboring"),
        ("countersink", "countersinking"),
        ("rectangular_pocket", "pocket_milling"),
        ("circular_pocket", "pocket_milling"),
        ("open_slot", "slot_milling"),
        ("closed_slot", "slot_milling"),
        ("step", "profile_milling"),
        ("shoulder", "profile_milling"),
        ("chamfer", "chamfering"),
        ("fillet", "profile_milling"),
    ]
    for feature_type, expected_op in feature_types:
        features = [
            {
                "feature_id": f"F-{feature_type}-001",
                "type": feature_type,
                "confidence": 0.9,
                "dimensions": {"diameter": 10.0, "width": 10.0, "length": 10.0},
                "axis": {"x": 0, "y": 0, "z": 1},
            }
        ]
        analysis = _make_analysis(features)
        plan = service.analyze_manufacturability(analysis)
        assert plan["machine_axis_count"] == 3
        ops = [
            op for op in plan["operations"]
            if f"F-{feature_type}-001" in op["feature_ids"]
        ]
        assert len(ops) == 1, f"Expected 1 operation for {feature_type}, got {len(ops)}"
        assert ops[0]["operation_type"] == expected_op, (
            f"Expected {expected_op} for {feature_type}, got {ops[0]['operation_type']}"
        )


def test_high_confidence_operations_auto_costed():
    """Features with confidence >= 0.75 are auto-costed (status=suggested)."""
    service = ManufacturingService()
    features = [
        {
            "feature_id": "F-HIGH-001",
            "type": "through_hole",
            "confidence": 0.92,
            "dimensions": {"diameter": 10.0},
            "axis": {"x": 0, "y": 0, "z": 1},
        }
    ]
    analysis = _make_analysis(features)
    plan = service.analyze_manufacturability(analysis)
    ops = [op for op in plan["operations"] if "F-HIGH-001" in op["feature_ids"]]
    assert len(ops) == 1
    assert ops[0]["status"] == "suggested"
    assert ops[0]["auto_costed"] is True
    assert ops[0]["confidence"] == 0.92


def test_low_confidence_operations_needs_review():
    """Features with confidence < 0.75 are needs_review and excluded from costing."""
    service = ManufacturingService()
    features = [
        {
            "feature_id": "F-LOW-001",
            "type": "chamfer",
            "confidence": 0.68,
            "dimensions": {"chamfer_distance": 1.0},
            "axis": {"x": 0, "y": 0, "z": 1},
        }
    ]
    analysis = _make_analysis(features)
    plan = service.analyze_manufacturability(analysis)
    ops = [op for op in plan["operations"] if "F-LOW-001" in op["feature_ids"]]
    assert len(ops) == 1
    assert ops[0]["status"] == "needs_review"
    assert ops[0]["auto_costed"] is False
    assert "below the" in ops[0]["warnings"][0] or "costing threshold" in ops[0]["warnings"][0]


def test_setup_grouping_by_axis():
    """Features are grouped into setups by their dominant axis."""
    service = ManufacturingService()
    features = [
        {
            "feature_id": "F-Z-001",
            "type": "through_hole",
            "confidence": 0.9,
            "dimensions": {"diameter": 10.0},
            "axis": {"x": 0, "y": 0, "z": 1},
        },
        {
            "feature_id": "F-X-001",
            "type": "through_hole",
            "confidence": 0.9,
            "dimensions": {"diameter": 10.0},
            "axis": {"x": 1, "y": 0, "z": 0},
        },
    ]
    analysis = _make_analysis(features)
    plan = service.analyze_manufacturability(analysis)
    setup_ids = {s["setup_id"] for s in plan["setups"]}
    assert "S-Z" in setup_ids
    assert "S-X" in setup_ids


def test_plan_validates_3axis_only():
    """Plan validation rejects non-3-axis machine counts."""
    service = ManufacturingService()
    plan = {"machine_axis_count": 5, "operations": []}
    try:
        service.validate_plan(plan)
        assert False, "Expected ValueError for non-3-axis"
    except ValueError as exc:
        assert "3-axis milling only" in str(exc)


def test_plan_validation_normalizes_operations():
    """validate_plan fills in defaults for missing operation fields."""
    service = ManufacturingService()
    plan = {
        "machine_axis_count": 3,
        "operations": [
            {"operation_type": "drilling"}
        ],
    }
    result = service.validate_plan(plan)
    assert result["machine_axis_count"] == 3
    assert len(result["operations"]) == 1
    op = result["operations"][0]
    assert op["operation_id"] == "OP-001"
    assert op["status"] == "suggested"
    assert op["feature_ids"] == []
    assert op["estimated_time_min"] == 0.0


def test_estimated_time_includes_only_auto_costed():
    """Total cutting time only includes auto-costed operations."""
    service = ManufacturingService()
    features = [
        {
            "feature_id": "F-HIGH-001",
            "type": "through_hole",
            "confidence": 0.92,
            "dimensions": {"diameter": 10.0},
            "axis": {"x": 0, "y": 0, "z": 1},
        },
        {
            "feature_id": "F-LOW-001",
            "type": "chamfer",
            "confidence": 0.68,
            "dimensions": {"chamfer_distance": 1.0},
            "axis": {"x": 0, "y": 0, "z": 1},
        },
    ]
    analysis = _make_analysis(features)
    plan = service.analyze_manufacturability(analysis)
    auto_ops = [op for op in plan["operations"] if op.get("auto_costed")]
    review_ops = [op for op in plan["operations"] if not op.get("auto_costed")]
    assert len(auto_ops) == 1
    assert len(review_ops) == 1
    assert plan["total_cutting_time_min"] == auto_ops[0]["estimated_time_min"]


def test_confidence_band_documentation():
    """Confidence is an evidence score, not a measured precision claim."""
    service = ManufacturingService()
    features = [
        {
            "feature_id": "F-CONF-001",
            "type": "through_hole",
            "confidence": 0.92,
            "dimensions": {"diameter": 10.0},
            "axis": {"x": 0, "y": 0, "z": 1},
        }
    ]
    analysis = _make_analysis(features)
    plan = service.analyze_manufacturability(analysis)
    ops = [op for op in plan["operations"] if "F-CONF-001" in op["feature_ids"]]
    assert len(ops) == 1
    conf = ops[0]["confidence"]
    assert 0.0 <= conf <= 1.0
    # Warnings must not claim statistical precision.
    for w in ops[0].get("warnings", []):
        assert "precision" not in w.lower()
        assert "recall" not in w.lower()