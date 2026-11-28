"""Editable 3-axis milling manufacturing planning."""

from __future__ import annotations

import hashlib
from typing import Any

_OPERATION_BY_FEATURE = {
    "through_hole": ("drilling", "drill"),
    "blind_hole": ("drilling", "drill"),
    "counterbore": ("counterboring", "counterbore_tool"),
    "countersink": ("countersinking", "countersink_tool"),
    "tapped_hole_candidate": ("tapping", "tap"),
    "reamed_hole_candidate": ("reaming", "reamer"),
    "cylindrical_bore": ("boring", "boring_bar"),
    "rectangular_pocket": ("pocket_milling", "end_mill"),
    "circular_pocket": ("pocket_milling", "end_mill"),
    "complex_pocket": ("pocket_milling", "end_mill"),
    "open_slot": ("slot_milling", "end_mill"),
    "closed_slot": ("slot_milling", "end_mill"),
    "t_slot": ("slot_milling", "t_slot_cutter"),
    "dovetail_slot": ("slot_milling", "dovetail_cutter"),
    "step": ("profile_milling", "end_mill"),
    "shoulder": ("profile_milling", "end_mill"),
    "chamfer": ("chamfering", "chamfer_tool"),
    "fillet": ("profile_milling", "ball_end_mill"),
    "rounded_corner": ("profile_milling", "ball_end_mill"),
    "groove": ("slot_milling", "end_mill"),
    "recess": ("pocket_milling", "end_mill"),
    "boss": ("profile_milling", "end_mill"),
    "rib": ("profile_milling", "end_mill"),
}


class ManufacturingService:
    """Create a suggested 3-axis plan; users may edit every operation."""

    # Features below this confidence are suggested for review but are not
    # automatically included in costing until the user confirms them.
    COSTING_CONFIDENCE_THRESHOLD = 0.75

    def __init__(self, min_confidence: float = 0.5) -> None:
        self.min_confidence = min_confidence

    @staticmethod
    def _feature_list(analysis: dict[str, Any]) -> list[dict[str, Any]]:
        reviewed = analysis.get("reviewed_features") or {}
        if isinstance(reviewed, dict) and reviewed:
            return list(reviewed.values())
        return list(analysis.get("features") or analysis.get("raw_features") or [])

    @staticmethod
    def _operation_id(feature_id: str, operation_type: str) -> str:
        digest = hashlib.sha1(f"{operation_type}|{feature_id}".encode()).hexdigest()[:8].upper()
        return f"OP-{digest}"

    def _setups(self, features: list[dict[str, Any]]) -> list[dict[str, Any]]:
        groups: dict[str, list[dict[str, Any]]] = {"Z": [], "X": [], "Y": [], "OTHER": []}
        for feature in features:
            axis = feature.get("axis") or {}
            x, y, z = float(axis.get("x", 0)), float(axis.get("y", 0)), float(axis.get("z", 0))
            if abs(z) >= max(abs(x), abs(y)):
                groups["Z"].append(feature)
            elif abs(x) >= abs(y):
                groups["X"].append(feature)
            elif abs(y) >= abs(x):
                groups["Y"].append(feature)
            else:
                groups["OTHER"].append(feature)
        setups: list[dict[str, Any]] = []
        for key, orientation in (
            ("Z", {"x": 0, "y": 0, "z": 1}),
            ("X", {"x": 1, "y": 0, "z": 0}),
            ("Y", {"x": 0, "y": 1, "z": 0}),
            ("OTHER", {"x": 0, "y": 0, "z": 1}),
        ):
            if not groups[key]:
                continue
            setups.append(
                {
                    "setup_id": f"S-{key}",
                    "orientation": orientation,
                    "origin": {"x": 0, "y": 0, "z": 0},
                    "feature_ids": [f["feature_id"] for f in groups[key]],
                    "description": f"{key}-axis setup (suggested)",
                }
            )
        if not setups:
            setups.append(
                {
                    "setup_id": "S-Z",
                    "orientation": {"x": 0, "y": 0, "z": 1},
                    "origin": {"x": 0, "y": 0, "z": 0},
                    "feature_ids": [],
                    "description": "Default setup - no machining features detected",
                }
            )
        return setups

    def analyze_manufacturability(
        self,
        analysis: dict[str, Any],
        machine_id: str = "generic_3axis",
        material_id: str = "aluminum_6061",
    ) -> dict[str, Any]:
        features = [
            f
            for f in self._feature_list(analysis)
            if float(f.get("confidence", 0.0)) >= self.min_confidence
        ]
        low_confidence = [
            f.get("feature_id")
            for f in self._feature_list(analysis)
            if float(f.get("confidence", 0.0)) < self.min_confidence
        ]
        setups = self._setups(features)
        setup_by_feature: dict[str, str] = {}
        for setup in setups:
            for feature_id in setup["feature_ids"]:
                setup_by_feature[feature_id] = setup["setup_id"]
        operations: list[dict[str, Any]] = []
        for feature in features:
            feature_type = str(feature.get("type", "unknown"))
            operation_type, tool = _OPERATION_BY_FEATURE.get(
                feature_type, ("profile_milling", "end_mill")
            )
            dimensions = feature.get("dimensions") or {}
            size = float(
                dimensions.get("diameter")
                or dimensions.get("width")
                or dimensions.get("length")
                or 10.0
            )
            base = {
                "drilling": 1.5,
                "counterboring": 2.0,
                "countersinking": 1.5,
                "tapping": 3.0,
                "reaming": 2.0,
                "boring": 2.5,
                "chamfering": 1.5,
                "pocket_milling": 8.0,
                "slot_milling": 5.0,
                "profile_milling": 5.0,
            }.get(operation_type, 4.0)
            confidence = float(feature.get("confidence", 0.0))
            # Only confident features are auto-costed; weaker ones stay as review
            # candidates until the user explicitly confirms them.
            auto_costed = confidence >= self.COSTING_CONFIDENCE_THRESHOLD
            operation = {
                "operation_id": self._operation_id(feature["feature_id"], operation_type),
                "feature_ids": [feature["feature_id"]],
                "operation_type": operation_type,
                "tool": tool,
                "setup_id": setup_by_feature.get(feature["feature_id"], setups[0]["setup_id"]),
                "estimated_time_min": round(base * max(0.5, min(3.0, size / 10.0)), 2),
                "status": "suggested" if auto_costed else "needs_review",
                "machine": machine_id,
                "material": material_id,
                "rate": None,
                "fixed_cost": None,
                "assumptions": [
                    "3-axis vertical milling machine",
                    "Standard carbide tooling",
                    "Fixturing and workholding are adequate",
                ],
                "warnings": []
                if auto_costed
                else ["Confidence below costing threshold; confirm before costing."],
                "confidence": confidence,
                "auto_costed": auto_costed,
            }
            if operation_type == "drilling":
                operation["tool_diameter_mm"] = round(size, 3)
            operations.append(operation)
        geometry = analysis.get("geometry") or analysis.get("geometry_summary") or {}
        bbox = geometry.get("bbox") or {}
        low = bbox.get("min", {})
        high = bbox.get("max", {})
        size = {
            "x": float(high.get("x", 0) - low.get("x", 0)),
            "y": float(high.get("y", 0) - low.get("y", 0)),
            "z": float(high.get("z", 0) - low.get("z", 0)),
        }
        # Only auto-costed (confident) operations count toward estimated time.
        costed_ops = [op for op in operations if op.get("auto_costed")]
        cutting_time = sum(float(op["estimated_time_min"]) for op in costed_ops)
        setup_time = len(setups) * 30.0
        tool_changes = len({op["tool"] for op in costed_ops}) * 15.0 / 60.0
        inspection = len(costed_ops) * 2.0
        warnings: list[str] = []
        if len(setups) > 1:
            warnings.append(
                f"{len(setups)} setups are suggested; confirm fixturing and datum strategy."
            )
        if low_confidence:
            warnings.append(
                f"{len(low_confidence)} feature(s) below {self.min_confidence:.2f} confidence are excluded from suggestions."
            )
        review_only = [op for op in operations if not op.get("auto_costed")]
        if review_only:
            warnings.append(
                f"{len(review_only)} operation(s) are below the {self.COSTING_CONFIDENCE_THRESHOLD:.2f} costing threshold; confirm them before they affect the estimate."
            )
        if geometry.get("num_bodies", 1) > 1:
            warnings.append(
                "Multiple solids are present; confirm whether they are separate parts or an assembly."
            )
        return {
            "machine": machine_id,
            "machine_axis_count": 3,
            "material": material_id,
            "status": "suggested",
            "setups": setups,
            "operations": operations,
            "low_confidence_feature_ids": low_confidence,
            "total_cutting_time_min": round(cutting_time, 2),
            "total_tool_change_time_min": round(tool_changes, 2),
            "total_setup_time_min": round(setup_time, 2),
            "total_inspection_time_min": round(inspection, 2),
            "total_estimated_time_min": round(
                cutting_time + tool_changes + setup_time + inspection, 2
            ),
            "finished_bbox": {"size": size, "bbox": bbox},
            "assumptions": [
                "Only 3-axis milling is supported.",
                "Suggested operations require engineering review before release.",
                "Rates are not included in the manufacturing plan; configure them in pricing.",
            ],
            "warnings": warnings,
        }

    def validate_plan(self, plan: dict[str, Any]) -> dict[str, Any]:
        """Validate and normalise an editable plan."""

        if int(plan.get("machine_axis_count", 3)) != 3:
            raise ValueError("JobEval currently supports 3-axis milling only")
        operations = []
        for index, operation in enumerate(plan.get("operations", [])):
            if not isinstance(operation, dict):
                raise ValueError(f"Operation {index + 1} must be an object")
            op = dict(operation)
            op.setdefault("operation_id", f"OP-{index + 1:03d}")
            op.setdefault("status", "suggested")
            op.setdefault("feature_ids", [])
            op.setdefault("estimated_time_min", 0.0)
            op.setdefault("assumptions", [])
            op.setdefault("warnings", [])
            op.setdefault("rate", None)
            op.setdefault("fixed_cost", None)
            operations.append(op)
        result = dict(plan)
        result["machine_axis_count"] = 3
        result["operations"] = operations
        result.setdefault("setups", [])
        result.setdefault("assumptions", [])
        result.setdefault("warnings", [])
        result.setdefault("status", "suggested")
        return result


def estimate_cost(*args: Any, **kwargs: Any) -> dict[str, Any]:
    """Compatibility entry point; detailed pricing lives in PricingService."""

    from app.services.pricing_service import PricingService

    return PricingService().calculate(*args, **kwargs)
