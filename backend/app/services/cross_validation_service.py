"""Cross-validation between drawing evidence and the STEP model."""

from __future__ import annotations

from typing import Any


class CrossValidationService:
    """Compare dimensions, hole counts/diameters, and material explicitly."""

    DEFAULT_TOLERANCES = {
        "dimension_mm": 0.5,
        "hole_diameter_mm": 0.1,
        "count": 0,
        "material": 0.0,
    }

    def __init__(self, tolerances: dict[str, float] | None = None) -> None:
        self.tolerances = dict(self.DEFAULT_TOLERANCES)
        if tolerances:
            self.tolerances.update(tolerances)

    @staticmethod
    def _dimensions(drawings: dict[str, Any] | None) -> list[dict[str, Any]]:
        if not drawings:
            return []
        return list(drawings.get("dimensions") or [])

    @staticmethod
    def _features(analysis: dict[str, Any] | None) -> list[dict[str, Any]]:
        if not analysis:
            return []
        reviewed = analysis.get("reviewed_features") or {}
        if isinstance(reviewed, dict) and reviewed:
            return list(reviewed.values())
        return list(analysis.get("features") or analysis.get("raw_features") or [])

    @staticmethod
    def _bbox_size(analysis: dict[str, Any] | None) -> dict[str, float]:
        geometry = (
            (analysis or {}).get("geometry") or (analysis or {}).get("geometry_summary") or {}
        )
        bbox = geometry.get("bbox") or {}
        low, high = bbox.get("min", {}), bbox.get("max", {})
        return {
            "length": float(high.get("x", 0) - low.get("x", 0)),
            "width": float(high.get("y", 0) - low.get("y", 0)),
            "height": float(high.get("z", 0) - low.get("z", 0)),
        }

    def _drawing_dimension(
        self,
        dimensions: list[dict[str, Any]],
        name: str,
        exclude_ids: set[str] | None = None,
    ) -> dict[str, Any] | None:
        aliases = {
            "length": ("length", "overall length", "o/all length", "x"),
            "width": ("width", "overall width", "o/all width", "y"),
            "height": ("height", "overall height", "o/all height", "thickness", "z"),
        }
        exclude_ids = exclude_ids or set()
        for dimension in dimensions:
            dim_id = dimension.get("id", "")
            if dim_id in exclude_ids:
                continue
            text = str(dimension.get("text", "")).lower()
            if any(alias in text for alias in aliases[name]):
                return dimension
        # Generated drawings often use a single numeric dimension.  Only use
        # the closest numeric candidate, and mark it as an inference in the
        # check details rather than pretending it was labelled.
        numeric = [
            d
            for d in dimensions
            if d.get("type") == "linear"
            and d.get("value") is not None
            and d.get("id", "") not in exclude_ids
        ]
        if not numeric:
            return None
        return max(numeric, key=lambda d: float(d["value"]))

    def validate(
        self,
        drawing_annotations: dict[str, Any] | None,
        analysis: dict[str, Any] | None,
        model_material: str | None = None,
    ) -> dict[str, Any]:
        dimensions = self._dimensions(drawing_annotations)
        features = self._features(analysis)
        bbox = self._bbox_size(analysis)
        checks: list[dict[str, Any]] = []
        summary = {"match": 0, "mismatch": 0, "drawing_only": 0, "model_only": 0, "needs_review": 0}
        used_dimension_ids: set[str] = set()

        def add(
            property_name: str,
            drawing: Any,
            model: Any,
            status: str,
            tolerance: float,
            details: str,
            review_state: str = "unreviewed",
        ) -> None:
            checks.append(
                {
                    "id": f"CV-{len(checks) + 1:03d}",
                    "property": property_name,
                    "drawing": drawing,
                    "model": model,
                    "status": status,
                    "tolerance": tolerance,
                    "details": details,
                    "review_state": review_state,
                    "reviewer": None,
                    "note": None,
                }
            )
            summary[status] = summary.get(status, 0) + 1

        tolerance = float(self.tolerances.get("dimension_mm", 0.5))
        for name in ("length", "width", "height"):
            drawing_dimension = self._drawing_dimension(
                dimensions, name, exclude_ids=used_dimension_ids
            )
            if drawing_dimension is not None:
                used_dimension_ids.add(drawing_dimension.get("id", ""))
            model_value = bbox.get(name)
            drawing_value = drawing_dimension.get("value") if drawing_dimension else None
            if drawing_value is not None and model_value:
                difference = abs(float(drawing_value) - float(model_value))
                status = "match" if difference <= tolerance else "mismatch"
                add(
                    f"overall_{name}",
                    round(float(drawing_value), 4),
                    round(float(model_value), 4),
                    status,
                    tolerance,
                    f"Drawing {drawing_value} mm, model {model_value:.4f} mm, difference {difference:.4f} mm.",
                )
            elif drawing_value is not None:
                add(
                    f"overall_{name}",
                    drawing_value,
                    None,
                    "drawing_only",
                    tolerance,
                    "Dimension appears on the drawing but not in the model.",
                )
            elif model_value:
                add(
                    f"overall_{name}",
                    None,
                    round(float(model_value), 4),
                    "model_only",
                    tolerance,
                    "Dimension appears in the model but not on the drawing.",
                )

        drawing_holes = [d for d in dimensions if d.get("type") in {"diameter", "thread"}]
        model_holes = [
            f
            for f in features
            if f.get("type")
            in {
                "through_hole",
                "blind_hole",
                "counterbore",
                "countersink",
                "tapped_hole_candidate",
                "reamed_hole_candidate",
            }
        ]
        if drawing_holes or model_holes:
            difference = abs(len(drawing_holes) - len(model_holes))
            count_tolerance = int(self.tolerances.get("count", 0))
            add(
                "hole_count",
                len(drawing_holes),
                len(model_holes),
                "match" if difference <= count_tolerance else "mismatch",
                count_tolerance,
                f"Drawing shows {len(drawing_holes)} hole callouts; model has {len(model_holes)} hole features.",
            )

        diameter_tolerance = float(self.tolerances.get("hole_diameter_mm", 0.1))
        drawing_diameters = sorted(
            float(d["value"]) for d in drawing_holes if d.get("value") is not None
        )
        model_diameters = sorted(
            float((f.get("dimensions") or {}).get("diameter"))
            for f in model_holes
            if (f.get("dimensions") or {}).get("diameter") is not None
        )
        for index in range(min(len(drawing_diameters), len(model_diameters))):
            difference = abs(drawing_diameters[index] - model_diameters[index])
            add(
                f"hole_diameter_{index + 1}",
                round(drawing_diameters[index], 4),
                round(model_diameters[index], 4),
                "match" if difference <= diameter_tolerance else "mismatch",
                diameter_tolerance,
                f"Diameter difference {difference:.4f} mm.",
            )
        if len(drawing_diameters) > len(model_diameters):
            add(
                "hole_diameter_count",
                len(drawing_diameters),
                len(model_diameters),
                "drawing_only",
                0,
                "Drawing has more hole diameter callouts than the model.",
            )
        if len(model_diameters) > len(drawing_diameters):
            add(
                "hole_diameter_count",
                len(drawing_diameters),
                len(model_diameters),
                "model_only",
                0,
                "Model has more hole features than the drawing.",
            )

        drawing_material = (
            (drawing_annotations or {}).get("candidates", {}).get("material")
            if drawing_annotations
            else None
        )
        if drawing_material or model_material:
            if drawing_material and model_material:
                same = str(drawing_material).strip().lower() == str(model_material).strip().lower()
                add(
                    "material",
                    drawing_material,
                    model_material,
                    "match" if same else "mismatch",
                    0,
                    "Material names were compared exactly after trimming.",
                )
            elif drawing_material:
                add(
                    "material",
                    drawing_material,
                    None,
                    "drawing_only",
                    0,
                    "Material is specified on the drawing only.",
                )
            else:
                add(
                    "material",
                    None,
                    model_material,
                    "model_only",
                    0,
                    "Material is present in the model only.",
                )

        tolerances = [d for d in dimensions if d.get("tolerance")]
        if tolerances:
            add(
                "drawing_tolerances",
                len(tolerances),
                None,
                "drawing_only",
                0,
                "STEP geometry does not carry drawing tolerance semantics.",
            )

        return {
            "checks": checks,
            "summary": summary,
            "tolerances": self.tolerances,
            "status": "needs_review"
            if any(c["status"] in {"mismatch", "drawing_only", "model_only"} for c in checks)
            else "match",
        }
