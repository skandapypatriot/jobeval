"""Transparent, editable pricing and stock calculations."""

from __future__ import annotations

import copy
import math
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.jobeval import PricingConfig

_MONEY = Decimal("0.01")


def money(value: float | int | Decimal | None) -> float | None:
    if value is None:
        return None
    return float(Decimal(str(value)).quantize(_MONEY, rounding=ROUND_HALF_UP))


def _number(value: Any, default: float | None = None) -> float | None:
    if value is None or value == "":
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _size_from_bbox(bbox: Any) -> dict[str, float]:
    if not isinstance(bbox, dict):
        return {"x": 0.0, "y": 0.0, "z": 0.0}
    if "size" in bbox and isinstance(bbox["size"], dict):
        return {axis: float(bbox["size"].get(axis, 0.0)) for axis in ("x", "y", "z")}
    low, high = bbox.get("min", {}) or {}, bbox.get("max", {}) or {}
    return {
        "x": float(high.get("x", 0.0) - low.get("x", 0.0)),
        "y": float(high.get("y", 0.0) - low.get("y", 0.0)),
        "z": float(high.get("z", 0.0) - low.get("z", 0.0)),
    }


DEFAULT_GLOBAL_PRICING: dict[str, Any] = {
    "material": "aluminum_6061",
    "density_kg_m3": 2700.0,
    "price": 420.0,
    "price_per_kg": 420.0,
    "price_basis": "kg",
    "currency": "INR",
    "stock_shape": "rectangular",
    "allowances": {"x": 2.0, "y": 2.0, "z": 2.0},
    "allowance_per_side_mm": 2.0,
    "quantity": 1,
    "minimum_quantity": 1,
    "overhead_percent": 10.0,
    "margin_percent": 15.0,
    "contingency_percent": 5.0,
    "tax_percent": 18.0,
    "rates": {
        "machine": 600.0,
        "labor": 400.0,
        "setup": 500.0,
        "tool_change": 150.0,
        "programming": 300.0,
        "inspection": 200.0,
        "finishing": 250.0,
        "deburr": 100.0,
    },
    "operation_rates": {},
    "fixed_overrides": {},
    "overrides": {},
    "notes": [
        "Sample/demo pricing — replace with your shop's actual rates.",
    ],
}


class PricingService:
    """Calculate stock, material, labour, and overhead transparently."""

    def __init__(self, session: Session | None = None) -> None:
        self.session = session

    # ------------------------------------------------------------------
    # Configuration persistence
    # ------------------------------------------------------------------
    def _get_row(self, scope: str, project_id: str | None = None) -> PricingConfig | None:
        if self.session is None:
            return None
        statement = select(PricingConfig).where(PricingConfig.scope == scope)
        if project_id is None:
            statement = statement.where(PricingConfig.project_id.is_(None))
        else:
            statement = statement.where(PricingConfig.project_id == project_id)
        return self.session.execute(statement).scalars().first()

    def get_global_config(self) -> dict[str, Any]:
        row = self._get_row("global")
        if row is None:
            return copy.deepcopy(DEFAULT_GLOBAL_PRICING)
        return self._normalise(copy.deepcopy(row.data))

    def get_project_config(self, project_id: str) -> dict[str, Any]:
        row = self._get_row("project", project_id)
        if row is None:
            return copy.deepcopy(DEFAULT_GLOBAL_PRICING)
        return self._normalise(copy.deepcopy(row.data))

    def save_global_config(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._save("global", None, data)

    def save_project_config(self, project_id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._save("project", project_id, data)

    def _save(self, scope: str, project_id: str | None, data: dict[str, Any]) -> dict[str, Any]:
        normalised = self._normalise(copy.deepcopy(data))
        if self.session is None:
            return normalised
        row = self._get_row(scope, project_id)
        if row is None:
            row = PricingConfig(
                id=f"pricing-{scope}-{project_id or 'global'}", scope=scope, project_id=project_id
            )
            self.session.add(row)
        row.data = normalised
        self.session.flush()
        return normalised

    @staticmethod
    def _normalise(data: dict[str, Any]) -> dict[str, Any]:
        result = copy.deepcopy(DEFAULT_GLOBAL_PRICING)
        result.update(copy.deepcopy(data or {}))
        allowances = result.get("allowances") or {}
        if not isinstance(allowances, dict):
            allowances = getattr(allowances, "model_dump", lambda: {})()
        allowance_value = result.get("allowance_per_side_mm")
        if allowance_value is None:
            allowance_value = result.get("allowance_mm", 2.0)
        result["allowances"] = {
            axis: float(allowances.get(axis, allowance_value)) for axis in ("x", "y", "z")
        }
        result["allowance_per_side_mm"] = float(allowance_value)
        rates = dict(DEFAULT_GLOBAL_PRICING["rates"])
        rates.update(result.get("rates") or {})
        result["rates"] = rates
        result["quantity"] = max(1, int(result.get("quantity", 1)))
        result["minimum_quantity"] = max(1, int(result.get("minimum_quantity", 1)))
        return result

    # ------------------------------------------------------------------
    # Stock calculations
    # ------------------------------------------------------------------
    def calculate_stock(
        self, config: dict[str, Any], finished_bbox: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        config = self._normalise(config)
        bbox = finished_bbox or config.get("finished_bbox") or {}
        size = _size_from_bbox(bbox)
        allowances = config["allowances"]
        required = {axis: size[axis] + 2.0 * allowances[axis] for axis in ("x", "y", "z")}
        shape = config.get("stock_shape", "rectangular")
        selected = config.get("selected_blank") or config.get("stock_dimensions") or {}
        actual: dict[str, float]
        fit: dict[str, Any]
        if shape == "round":
            required_diameter = max(required["x"], required["y"])
            selected_diameter = _number(selected.get("diameter_mm", selected.get("diameter")))
            selected_thickness = _number(
                selected.get("thickness_mm", selected.get("thickness", selected.get("height_mm")))
            )
            if selected_diameter is not None:
                actual = {
                    "diameter_mm": selected_diameter,
                    "thickness_mm": selected_thickness or required["z"],
                }
                excess_diameter = selected_diameter - required_diameter
                excess_thickness = (selected_thickness or required["z"]) - required["z"]
                fit = {
                    "fits": excess_diameter >= 0 and excess_thickness >= 0,
                    "excess": {"diameter_mm": excess_diameter, "thickness_mm": excess_thickness},
                    "shortage": {
                        "diameter_mm": max(0.0, -excess_diameter),
                        "thickness_mm": max(0.0, -excess_thickness),
                    },
                }
            else:
                actual = {"diameter_mm": required_diameter, "thickness_mm": required["z"]}
                fit = {
                    "fits": True,
                    "excess": {"diameter_mm": 0.0, "thickness_mm": 0.0},
                    "shortage": {"diameter_mm": 0.0, "thickness_mm": 0.0},
                }
            stock = {
                "shape": "round",
                "diameter_mm": actual["diameter_mm"],
                "thickness_mm": actual["thickness_mm"],
                "required_diameter_mm": required_diameter,
                "required_thickness_mm": required["z"],
            }
        else:
            selected_size = {
                "x": _number(selected.get("length_mm", selected.get("x", selected.get("length")))),
                "y": _number(selected.get("width_mm", selected.get("y", selected.get("width")))),
                "z": _number(
                    selected.get(
                        "height_mm",
                        selected.get("z", selected.get("height", selected.get("thickness_mm"))),
                    )
                ),
            }
            if all(value is not None for value in selected_size.values()):
                actual = {axis: selected_size[axis] for axis in ("x", "y", "z")}
                excess = {axis: actual[axis] - required[axis] for axis in ("x", "y", "z")}
                shortage = {axis: max(0.0, -value) for axis, value in excess.items()}
                fit = {
                    "fits": all(value >= 0 for value in excess.values()),
                    "excess": excess,
                    "shortage": shortage,
                }
            else:
                actual = dict(required)
                fit = {
                    "fits": True,
                    "excess": dict.fromkeys(("x", "y", "z"), 0.0),
                    "shortage": dict.fromkeys(("x", "y", "z"), 0.0),
                }
            stock = {
                "shape": "rectangular",
                "length_mm": actual["x"],
                "width_mm": actual["y"],
                "height_mm": actual["z"],
                "required_length_mm": required["x"],
                "required_width_mm": required["y"],
                "required_height_mm": required["z"],
            }
        volume_mm3 = 0.0
        if stock["shape"] == "round":
            volume_mm3 = math.pi * (stock["diameter_mm"] / 2.0) ** 2 * stock["thickness_mm"]
        else:
            volume_mm3 = stock["length_mm"] * stock["width_mm"] * stock["height_mm"]
        density = _number(config.get("density_kg_m3"), 2700.0) or 2700.0
        weight_kg = volume_mm3 * density / 1_000_000_000.0
        return {
            "finished_bbox": {"size": size, "bbox": bbox},
            "allowances_per_side_mm": allowances,
            "allowance_total_mm": {axis: value * 2.0 for axis, value in allowances.items()},
            "required_stock": stock,
            "selected_blank": selected or None,
            "fit": fit,
            "stock_volume_mm3": round(volume_mm3, 4),
            "stock_volume_cm3": round(volume_mm3 / 1000.0, 6),
            "stock_weight_kg": round(weight_kg, 6),
            "density_kg_m3": density,
            "warnings": []
            if fit.get("fits", True)
            else [
                "Selected blank is smaller than the required stock; shortage is reported and no allowance is added again."
            ],
        }

    # ------------------------------------------------------------------
    # Estimate calculations
    # ------------------------------------------------------------------
    def calculate(
        self,
        config: dict[str, Any],
        analysis: dict[str, Any] | None = None,
        plan: dict[str, Any] | None = None,
        quantity: int | None = None,
    ) -> dict[str, Any]:
        config = self._normalise(config)
        analysis = analysis or {}
        plan = plan or {}
        if quantity is not None:
            config["quantity"] = max(1, int(quantity))
        finished_bbox = config.get("finished_bbox") or (
            (analysis.get("geometry") or analysis.get("geometry_summary") or {}).get("bbox")
        )
        stock = self.calculate_stock(config, finished_bbox)
        requested_quantity = int(config.get("quantity", 1))
        minimum_quantity = int(config.get("minimum_quantity", 1))
        charged_quantity = max(requested_quantity, minimum_quantity)
        warnings = list(stock.get("warnings", []))
        lines: list[dict[str, Any]] = []

        def line(
            key: str,
            label: str,
            quantity_value: float,
            unit: str,
            rate: float | None,
            basis: str,
            formula: str,
            subtotal: float | None,
            *,
            override: float | None = None,
            calculated: float | None = None,
            source: str = "calculated",
            note: str | None = None,
        ) -> None:
            lines.append(
                {
                    "id": key,
                    "label": label,
                    "quantity": quantity_value,
                    "unit": unit,
                    "rate": rate,
                    "basis": basis,
                    "formula": formula,
                    "calculated_subtotal": money(calculated),
                    "subtotal": money(override if override is not None else subtotal),
                    "is_override": override is not None,
                    "override_value": money(override),
                    "source": source,
                    "note": note,
                }
            )

        # Material price is never silently treated as free.
        price = _number(config.get("price"))
        if price is None:
            price = _number(config.get("price_per_kg"))
        basis = config.get("price_basis", "kg")
        material_weight = stock["stock_weight_kg"]
        material_volume = stock["stock_volume_cm3"]
        if basis == "kg":
            material_qty = material_weight * charged_quantity
            material_rate = price
            material_unit = "kg"
            material_subtotal = material_qty * price if price is not None else None
            formula = "stock_weight_kg × charged_quantity × price_per_kg"
        elif basis == "piece":
            material_qty = charged_quantity
            material_rate = price
            material_unit = "piece"
            material_subtotal = price * charged_quantity if price is not None else None
            formula = "charged_quantity × price_per_piece"
        elif basis == "volume_cm3":
            material_qty = material_volume * charged_quantity
            material_rate = price
            material_unit = "cm³"
            material_subtotal = material_qty * price if price is not None else None
            formula = "stock_volume_cm3 × charged_quantity × price_per_cm3"
        elif basis == "volume_m3":
            material_qty = material_volume / 1_000_000.0 * charged_quantity
            material_rate = price
            material_unit = "m³"
            material_subtotal = material_qty * price if price is not None else None
            formula = "stock_volume_m3 × charged_quantity × price_per_m3"
        else:  # sheet
            material_qty = charged_quantity
            material_rate = price
            material_unit = "sheet"
            material_subtotal = price * charged_quantity if price is not None else None
            formula = "charged_quantity × price_per_sheet"
        if price is None:
            warnings.append(
                "Material price is missing; material cost is unpriced rather than zero."
            )
        material_override = _number((config.get("overrides") or {}).get("material"))
        line(
            "material",
            "Material",
            material_qty,
            material_unit,
            material_rate,
            basis,
            formula,
            material_subtotal,
            override=material_override,
            calculated=material_subtotal,
        )

        operations = list(plan.get("operations") or [])
        # Only operations the user has confirmed (or that are auto-costed
        # because they are confident) contribute to the estimate.  A
        # needs_review operation stays visible but adds no cost until the user
        # changes its status.
        costable_operations = [
            op
            for op in operations
            if str(op.get("status", "suggested")) in {"suggested", "confirmed", "edited"}
            and bool(op.get("auto_costed", True))
        ]
        rates = config.get("rates") or {}
        operation_rates = config.get("operation_rates") or {}
        fixed_overrides = config.get("fixed_overrides") or {}
        overrides = config.get("overrides") or {}

        machine_rate = _number(rates.get("machine"))
        if machine_rate is None:
            warnings.append("Machine rate is missing; machining cost is unpriced rather than zero.")
        for operation in costable_operations:
            op_type = str(operation.get("operation_type", "unknown"))
            op_id = str(operation.get("operation_id", op_type))
            minutes = float(operation.get("estimated_time_min", 0.0) or 0.0)
            rate = _number(
                operation_rates.get(op_id), _number(operation_rates.get(op_type), machine_rate)
            )
            subtotal = minutes / 60.0 * rate * charged_quantity if rate is not None else None
            override = _number(fixed_overrides.get(op_id), _number(fixed_overrides.get(op_type)))
            if override is not None:
                override *= charged_quantity
            line(
                f"operation:{op_id}",
                f"Operation: {op_type}",
                minutes,
                "min",
                rate,
                "machine_hour",
                "operation_minutes ÷ 60 × machine_rate × charged_quantity",
                subtotal,
                override=override,
                calculated=subtotal,
                source="operation",
            )

        # Explicit support rates.  Missing values produce warnings and null
        # subtotals, never an invisible free line.
        time_values = {
            "setup": float(plan.get("total_setup_time_min", 0.0) or 0.0),
            "tool_change": float(plan.get("total_tool_change_time_min", 0.0) or 0.0),
            "inspection": float(plan.get("total_inspection_time_min", 0.0) or 0.0),
            "programming": 0.0,
            "finishing": 0.0,
            "deburr": 0.0,
            "labor": 0.0,
        }
        for key, minutes in time_values.items():
            rate = _number(rates.get(key))
            if key in {"labor", "finishing", "deburr"}:
                # These are not durations in the default plan; users can set a
                # rate and a duration in operation overrides/plan fields.
                minutes = float(plan.get(f"{key}_time_min", 0.0) or 0.0)
            if rate is None:
                warnings.append(
                    f"{key.replace('_', ' ').title()} rate is missing; this cost is unpriced rather than zero."
                )
            subtotal = minutes / 60.0 * rate * charged_quantity if rate is not None else None
            override = _number(overrides.get(key))
            line(
                key,
                key.replace("_", " ").title(),
                minutes,
                "min",
                rate,
                "hour",
                "duration_min ÷ 60 × rate × charged_quantity",
                subtotal,
                override=override,
                calculated=subtotal,
            )

        # Track operations excluded from costing so the UI can show them.
        excluded_operations = [
            {
                "operation_id": op.get("operation_id"),
                "operation_type": op.get("operation_type"),
                "status": op.get("status"),
                "confidence": op.get("confidence"),
                "reason": "Below costing confidence threshold or not confirmed",
            }
            for op in operations
            if op not in costable_operations
        ]
        if excluded_operations:
            warnings.append(
                f"{len(excluded_operations)} operation(s) are not costed; confirm them in the manufacturing plan before they affect the estimate."
            )
        priced = [float(item["subtotal"]) for item in lines if item.get("subtotal") is not None]
        base_total = sum(priced)
        overhead_rate = float(config.get("overhead_percent", 0.0) or 0.0)
        margin_rate = float(config.get("margin_percent", 0.0) or 0.0)
        contingency_rate = float(config.get("contingency_percent", 0.0) or 0.0)
        tax_rate = float(config.get("tax_percent", 0.0) or 0.0)
        overhead = base_total * overhead_rate / 100.0
        margin = (base_total + overhead) * margin_rate / 100.0
        contingency = (base_total + overhead + margin) * contingency_rate / 100.0
        subtotal_before_tax = base_total + overhead + margin + contingency
        tax = subtotal_before_tax * tax_rate / 100.0
        for key, label, value, formula in (
            ("overhead", "Overhead", overhead, "base_total × overhead_percent"),
            ("margin", "Margin", margin, "(base_total + overhead) × margin_percent"),
            (
                "contingency",
                "Contingency",
                contingency,
                "(base_total + overhead + margin) × contingency_percent",
            ),
            ("tax", "Tax", tax, "subtotal_before_tax × tax_percent"),
        ):
            line(key, label, 1.0, "currency", None, "percent", formula, value)

        # Manufacturing summary for the estimate UI: setup count, orientation
        # changes, and a simple complexity band based on feature evidence.
        setups = list(plan.get("setups") or [])
        setup_count = len(setups)
        orientations = {str(s.get("orientation", {})) for s in setups if s.get("orientation")}
        orientation_changes = max(0, len(orientations) - 1)
        all_features = list((analysis or {}).get("features") or [])
        confidence_values = [
            float(f.get("confidence", 0.0)) for f in all_features if f.get("confidence") is not None
        ]
        avg_confidence = (
            sum(confidence_values) / len(confidence_values) if confidence_values else 0.0
        )
        if avg_confidence >= 0.8:
            complexity = "low"
        elif avg_confidence >= 0.6:
            complexity = "medium"
        else:
            complexity = "high"

        total = subtotal_before_tax + tax
        if charged_quantity > requested_quantity:
            warnings.append(
                f"Minimum quantity {minimum_quantity} increased charged quantity from {requested_quantity}."
            )
        if any(item.get("subtotal") is None for item in lines):
            warnings.append(
                "Some lines are unpriced because a rate or price is missing; the total is a lower bound until configured."
            )

        return {
            "currency": config.get("currency", "USD"),
            "quantity": requested_quantity,
            "minimum_quantity": minimum_quantity,
            "charged_quantity": charged_quantity,
            "pricing": config,
            "stock": stock,
            "lines": lines,
            "excluded_operations": excluded_operations,
            "base_total": money(base_total),
            "subtotal_before_tax": money(subtotal_before_tax),
            "total": money(total),
            "total_cost": money(total),
            "rounding": {"currency_decimals": 2, "mode": "ROUND_HALF_UP"},
            "warnings": warnings,
            "estimated": True,
            "manufacturing_summary": {
                "setup_count": setup_count,
                "orientation_changes": orientation_changes,
                "complexity": complexity,
                "average_confidence": round(avg_confidence, 2),
                "feature_count": len(all_features),
            },
        }


def default_pricing_config() -> dict[str, Any]:
    return copy.deepcopy(DEFAULT_GLOBAL_PRICING)
