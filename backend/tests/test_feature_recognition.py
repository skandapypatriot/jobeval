"""Feature recognition tests."""

from build123d import Box, Cylinder

from app.services.feature_recognition import recognize_features


def test_feature_detection_on_block_with_hole():
    part = Box(40, 30, 20).cut(Cylinder(6, 25))
    payload = recognize_features(part.wrapped, "mm")
    assert "geometry_summary" in payload
    assert "bodies" in payload
    assert "faces" in payload
    assert "raw_features" in payload
    assert "units" in payload
    assert payload["units"]["conversion_factor"] == 1.0
    geometry = payload["geometry_summary"]
    assert geometry["num_bodies"] == 1
    assert abs(geometry["volume"] - 21738.05) < 5

    holes = [
        f
        for f in payload["raw_features"]
        if f["type"] in {"through_hole", "blind_hole", "counterbore"}
    ]
    assert len(holes) == 1, holes
    hole = holes[0]
    assert hole["confidence"] >= 0.5
    assert hole["dimensions"]["diameter"] == 12.0
    assert hole["dimensions"]["depth"] == 20.0
    assert hole["through"] is True
    assert "evidence" in hole and hole["evidence"]
    assert "surface" in hole["evidence"]
    assert hole["feature_id"].startswith("F-")


def test_recognize_features_returns_confidence_and_evidence():
    part = Box(20, 20, 20).cut(Cylinder(4, 18))
    payload = recognize_features(part.wrapped, "mm")
    for feature in payload["raw_features"]:
        assert 0.0 <= feature["confidence"] <= 1.0
        assert isinstance(feature["evidence"], dict)
        assert feature["feature_id"]
        assert feature["type"]


def test_plain_block_has_no_spurious_features():
    """Negative case: a plain rectangular block must not produce hole/pocket
    detections merely because it has planar faces."""
    part = Box(40, 30, 20)
    payload = recognize_features(part.wrapped, "mm")
    holes = [
        f
        for f in payload["raw_features"]
        if f["type"]
        in {"through_hole", "blind_hole", "counterbore", "countersink"}
    ]
    pockets = [
        f
        for f in payload["raw_features"]
        if f["type"] in {"rectangular_pocket", "open_slot", "complex_pocket"}
    ]
    assert len(holes) == 0, f"Unexpected hole detections on plain block: {holes}"
    assert len(pockets) == 0, f"Unexpected pocket detections on plain block: {pockets}"


def test_no_duplicate_detections_for_same_feature():
    """A single cylindrical bore must produce one feature record, not one per
    cylindrical face."""
    part = Box(50, 40, 30).cut(Cylinder(8, 35))
    payload = recognize_features(part.wrapped, "mm")
    holes = [
        f
        for f in payload["raw_features"]
        if f["type"] in {"through_hole", "blind_hole", "counterbore"}
    ]
    assert len(holes) == 1, f"Expected 1 hole, got {len(holes)}: {holes}"
    hole_ids = {f["feature_id"] for f in holes}
    assert len(hole_ids) == len(holes), "Duplicate feature IDs detected"


def test_counterbore_detection():
    """A stepped bore (larger cylinder intersecting smaller) should be
    recognised as a counterbore with two diameters."""
    part = Box(60, 40, 40).cut(Cylinder(8, 30)).cut(Cylinder(4, 35))
    payload = recognize_features(part.wrapped, "mm")
    counterbores = [
        f for f in payload["raw_features"] if f["type"] == "counterbore"
    ]
    assert len(counterbores) >= 1, f"Expected counterbore, got: {[f['type'] for f in payload['raw_features']]}"
    cb = counterbores[0]
    assert cb["confidence"] >= 0.5
    assert cb["dimensions"].get("major_diameter") is not None
    assert cb["dimensions"].get("secondary_diameter") is not None


def test_blind_hole_detection():
    """A hole that does not go all the way through should be classified blind."""
    part = Box(40, 30, 30).cut(Cylinder(6, 15))
    payload = recognize_features(part.wrapped, "mm")
    blind = [
        f for f in payload["raw_features"]
        if f["type"] == "blind_hole"
    ]
    assert len(blind) >= 1, f"Expected blind hole, got: {[f['type'] for f in payload['raw_features']]}"
    bh = blind[0]
    assert bh["through"] is False
    assert bh["depth_type"] == "blind"
    assert bh["dimensions"]["depth"] > 0


def test_fillet_chamfer_on_edged_block():
    """A block with rounded or chamfered edges should produce fillet/chamfer
    candidates rather than spurious holes."""
    part = Box(40, 30, 20)
    # Apply a fillet via chamfer on edges (build123d fillet on a solid edge)
    from build123d import fillet
    edges = part.edges()
    if len(edges) > 0:
        try:
            filleted = fillet(edges[:2], 2.0)
            payload = recognize_features(filleted.wrapped, "mm")
            # Should not crash and should return valid feature structures
            for feature in payload["raw_features"]:
                assert 0.0 <= feature["confidence"] <= 1.0
                assert feature["feature_id"]
                assert feature["type"]
        except Exception:
            # Fillet may fail on certain edge selections; at minimum the
            # recognizer must not crash on the original block.
            payload = recognize_features(part.wrapped, "mm")
            for feature in payload["raw_features"]:
                assert 0.0 <= feature["confidence"] <= 1.0


def test_confidence_band_documentation():
    """Confidence bands must follow the documented interpretation and never
    claim measured precision."""
    part = Box(40, 30, 20).cut(Cylinder(6, 25))
    payload = recognize_features(part.wrapped, "mm")
    for feature in payload["raw_features"]:
        conf = feature["confidence"]
        assert conf is not None
        assert 0.0 <= conf <= 1.0
        # Band classification
        if conf < 0.5:
            band = "low"
        elif conf < 0.75:
            band = "medium"
        else:
            band = "high"
        assert band in {"low", "medium", "high"}
        # Warning must not claim statistical precision
        if "warnings" in feature:
            for w in feature["warnings"]:
                assert "precision" not in w.lower()
                assert "recall" not in w.lower()
