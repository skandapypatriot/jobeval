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
