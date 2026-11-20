"""Cross-Validation Service - Compare 3D model with 2D drawing annotations."""

import logging
from typing import Any
from uuid import UUID

from app.core.config import get_settings
from app.schemas.cad_specs import (
    CrossValidationCheck,
    CrossValidationReport,
    DrawingAnnotations,
    GeometrySummary,
    ValidationStatus,
)

settings = get_settings()
logger = logging.getLogger(__name__)


class CrossValidationService:
    """Service for comparing 3D model data with 2D drawing annotations."""

    def __init__(self) -> None:
        self.settings = settings
        self.dimension_tolerance_mm = 0.5  # Default tolerance for dimension matching
        self.hole_count_tolerance = 0

    def validate(
        self,
        drawing_annotations: DrawingAnnotations | None,
        geometry_summary: GeometrySummary | None,
        model_features: list[Any],
        model_material: str | None = None,
    ) -> CrossValidationReport:
        """
        Compare drawing annotations with 3D model features.
        Never assumes either source is correct - flags all discrepancies.
        """
        checks: list[CrossValidationCheck] = []
        summary = {
            "matches": 0,
            "mismatches": 0,
            "drawing_only": 0,
            "model_only": 0,
            "within_tolerance": 0,
        }

        # Extract drawing data
        drawing_dims = self._get_all_dimensions(drawing_annotations) if drawing_annotations else []
        drawing_holes = self._count_drawing_holes(drawing_dims)
        drawing_material = self._extract_drawing_material(drawing_annotations) if drawing_annotations else None
        drawing_tolerances = self._extract_drawing_tolerances(drawing_annotations) if drawing_annotations else []

        # Extract model data
        model_dims = self._extract_model_dimensions(geometry_summary) if geometry_summary else {}
        model_holes = self._count_model_holes(model_features)
        model_material = model_material

        # =====================================================================
        # 1. Overall Dimensions Comparison
        # =====================================================================
        for dim_name in ["length", "width", "height", "volume"]:
            model_val = model_dims.get(dim_name)
            drawing_val = self._find_drawing_dimension(drawing_dims, dim_name)

            if model_val is not None and drawing_val is not None:
                diff = abs(model_val - drawing_val)
                if dim_name == "volume":
                    # Volume tolerance is relative (5%)
                    tolerance = abs(model_val) * 0.05
                    status = ValidationStatus.MATCH if diff <= tolerance else ValidationStatus.MISMATCH
                else:
                    status = ValidationStatus.MATCH if diff <= self.dimension_tolerance_mm else ValidationStatus.MISMATCH

                if status == ValidationStatus.MATCH:
                    summary["matches"] += 1
                else:
                    summary["mismatches"] += 1

                checks.append(CrossValidationCheck(
                    property=f"overall_{dim_name}",
                    drawing=round(drawing_val, 3) if drawing_val else None,
                    model=round(model_val, 3) if model_val else None,
                    status=status,
                    tolerance=self.dimension_tolerance_mm if dim_name != "volume" else tolerance,
                    details=f"Drawing: {drawing_val}, Model: {model_val}, diff: {diff:.3f}",
                ))
            elif drawing_val is not None and model_val is None:
                summary["drawing_only"] += 1
                checks.append(CrossValidationCheck(
                    property=f"overall_{dim_name}",
                    drawing=round(drawing_val, 3),
                    model=None,
                    status=ValidationStatus.DRAWING_ONLY,
                    details="Dimension found on drawing but not in model",
                ))
            elif model_val is not None and drawing_val is None:
                summary["model_only"] += 1
                checks.append(CrossValidationCheck(
                    property=f"overall_{dim_name}",
                    drawing=None,
                    model=round(model_val, 3),
                    status=ValidationStatus.MODEL_ONLY,
                    details="Dimension found in model but not on drawing",
                ))

        # =====================================================================
        # 2. Hole Count Comparison
        # =====================================================================
        if drawing_holes > 0 or model_holes > 0:
            if drawing_holes == model_holes:
                summary["matches"] += 1
                status = ValidationStatus.MATCH
            else:
                summary["mismatches"] += 1
                status = ValidationStatus.MISMATCH

            checks.append(CrossValidationCheck(
                property="hole_count",
                drawing=drawing_holes,
                model=model_holes,
                status=status,
                details=f"Drawing: {drawing_holes} holes, Model: {model_holes} holes",
            ))

        # =====================================================================
        # 3. Hole Diameter Comparison (sample first few)
        # =====================================================================
        drawing_diameters = [
            d for d in drawing_dims
            if d.type in ("diameter", "thread")
        ]
        model_diameters = [
            f for f in model_features
            if f.type in ("through_hole", "blind_hole", "counterbore", "countersink", "cylindrical_bore")
            and f.dimensions and f.dimensions.diameter
        ]

        # Compare up to 5 hole diameters
        for i in range(min(5, len(drawing_diameters), len(model_diameters))):
            dd = drawing_diameters[i]
            mf = model_diameters[i]
            md = mf.dimensions.diameter if mf.dimensions else None

            if dd.value is not None and md is not None:
                diff = abs(dd.value - md)
                status = ValidationStatus.MATCH if diff <= 0.1 else ValidationStatus.MISMATCH
                if status == ValidationStatus.MATCH:
                    summary["matches"] += 1
                else:
                    summary["mismatches"] += 1

                checks.append(CrossValidationCheck(
                    property=f"hole_diameter_{i+1}",
                    drawing=dd.value,
                    model=round(md, 3),
                    status=status,
                    tolerance=0.1,
                    details=f"Drawing: Ø{dd.value}, Model: Ø{md}, diff: {diff:.3f}",
                ))

        # Extra drawing holes not in model
        if len(drawing_diameters) > len(model_diameters):
            summary["drawing_only"] += 1
            checks.append(CrossValidationCheck(
                property="hole_count_extra_drawing",
                drawing=len(drawing_diameters),
                model=len(model_diameters),
                status=ValidationStatus.DRAWING_ONLY,
                details=f"Drawing has {len(drawing_diameters) - len(model_diameters)} more hole dimensions than model features",
            ))

        # Extra model holes not in drawing
        if len(model_diameters) > len(drawing_diameters):
            summary["model_only"] += 1
            checks.append(CrossValidationCheck(
                property="hole_count_extra_model",
                drawing=len(drawing_diameters),
                model=len(model_diameters),
                status=ValidationStatus.MODEL_ONLY,
                details=f"Model has {len(model_diameters) - len(drawing_diameters)} more hole features than drawing dimensions",
            ))

        # =====================================================================
        # 4. Material Comparison
        # =====================================================================
        if drawing_material or model_material:
            if drawing_material and model_material:
                if drawing_material.lower().strip() == model_material.lower().strip():
                    summary["matches"] += 1
                    status = ValidationStatus.MATCH
                else:
                    summary["mismatches"] += 1
                    status = ValidationStatus.MISMATCH
                checks.append(CrossValidationCheck(
                    property="material",
                    drawing=drawing_material,
                    model=model_material,
                    status=status,
                    details=f"Drawing: {drawing_material}, Model: {model_material}",
                ))
            elif drawing_material and not model_material:
                summary["drawing_only"] += 1
                checks.append(CrossValidationCheck(
                    property="material",
                    drawing=drawing_material,
                    model=None,
                    status=ValidationStatus.DRAWING_ONLY,
                    details="Material specified on drawing but not in model",
                ))
            elif model_material and not drawing_material:
                summary["model_only"] += 1
                checks.append(CrossValidationCheck(
                    property="material",
                    drawing=None,
                    model=model_material,
                    status=ValidationStatus.MODEL_ONLY,
                    details="Material specified in model but not on drawing",
                ))

        # =====================================================================
        # 5. Tolerance Comparison
        # =====================================================================
        if drawing_tolerances:
            # Model typically doesn't carry tolerance info in STEP
            summary["drawing_only"] += 1
            checks.append(CrossValidationCheck(
                property="tolerances",
                drawing=f"{len(drawing_tolerances)} tolerance(s) found",
                model=None,
                status=ValidationStatus.DRAWING_ONLY,
                details="Tolerances found on drawing but STEP models typically don't carry tolerance data",
            ))

        return CrossValidationReport(checks=checks, summary=summary)

    # --------------------------------------------------------------------- #
    # Helper Methods
    # --------------------------------------------------------------------- #

    def _get_all_dimensions(self, annotations: DrawingAnnotations) -> list[Any]:
        """Get all dimensions from all pages."""
        dims = []
        for page in annotations.pages:
            dims.extend(page.dimensions)
        return dims

    def _count_drawing_holes(self, dimensions: list[Any]) -> int:
        """Count hole-related dimensions on drawing."""
        count = 0
        for d in dimensions:
            if d.type in ("diameter", "thread"):
                count += 1
        return count

    def _count_model_holes(self, model_features: list[Any]) -> int:
        """Count hole features in model."""
        hole_types = {
            "through_hole", "blind_hole", "counterbore",
            "countersink", "cylindrical_bore", "tapped_hole_candidate",
            "reamed_hole_candidate",
        }
        count = 0
        for f in model_features:
            if f.type in hole_types:
                count += 1
        return count

    def _find_drawing_dimension(
        self,
        dimensions: list[Any],
        dim_name: str,
    ) -> float | None:
        """Find a drawing dimension matching the given overall dimension name."""
        # Map dimension names to keywords
        keywords = {
            "length": ["length", "overall length", "o/all length"],
            "width": ["width", "overall width", "o/all width"],
            "height": ["height", "overall height", "o/all height", "thickness"],
            "volume": [],  # Volume not typically dimensioned on drawings
        }

        kw_list = keywords.get(dim_name, [])
        for d in dimensions:
            if d.type != "linear":
                continue
            text_lower = d.text.lower()
            if any(kw in text_lower for kw in kw_list):
                return d.value

        # Fallback: return first linear dimension that's reasonably large
        if dim_name in ("length", "width", "height"):
            candidates = [
                d for d in dimensions
                if d.type == "linear" and d.value and d.value > 10
            ]
            if candidates:
                # Return the largest matching dimension as overall
                return max(c.value for c in candidates if c.value)

        return None

    def _extract_model_dimensions(
        self,
        geometry_summary: GeometrySummary,
    ) -> dict[str, float]:
        """Extract comparable dimensions from model geometry summary."""
        dims = {}
        if geometry_summary and geometry_summary.bbox:
            bbox = geometry_summary.bbox
            dims["length"] = bbox.max.x - bbox.min.x
            dims["width"] = bbox.max.y - bbox.min.y
            dims["height"] = bbox.max.z - bbox.min.z
            dims["volume"] = geometry_summary.volume
        return dims

    def _extract_drawing_material(
        self,
        annotations: DrawingAnnotations,
    ) -> str | None:
        """Extract material from drawing title block or notes."""
        for page in annotations.pages:
            if page.title_block and page.title_block.material:
                return page.title_block.material
            for note in page.notes:
                if note.category == "material":
                    return note.text
        return None

    def _extract_drawing_tolerances(
        self,
        annotations: DrawingAnnotations,
    ) -> list[Any]:
        """Extract all tolerance information from drawing."""
        tolerances = []
        for page in annotations.pages:
            for d in page.dimensions:
                if d.tolerance:
                    tolerances.append(d)
            for gt in page.gd_t:
                if gt.value is not None:
                    tolerances.append(gt)
        return tolerances