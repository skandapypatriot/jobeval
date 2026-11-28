"""Pricing and estimate tests."""

from app.services.pricing_service import PricingService, money


def _base_config():
    return PricingService()._normalise(
        {
            "material": "aluminum_6061",
            "density_kg_m3": 2700.0,
            "price": 2.5,
            "price_basis": "kg",
            "stock_shape": "rectangular",
            "allowances": {"x": 2.0, "y": 2.0, "z": 2.0},
            "quantity": 1,
            "rates": {"machine": 60.0, "setup": 40.0, "inspection": 30.0},
        }
    )


def test_money_rounding():
    assert money(1.005) == 1.01
    assert money(1.004) == 1.0
    assert money(None) is None


def test_symmetric_allowance_stock():
    service = PricingService()
    config = _base_config()
    stock = service.calculate_stock(config, {"size": {"x": 100.0, "y": 50.0, "z": 25.0}})
    required = stock["required_stock"]
    assert required["length_mm"] == 104.0  # 100 + 2*2
    assert required["width_mm"] == 54.0
    assert required["height_mm"] == 29.0
    assert stock["fit"]["fits"] is True


def test_asymmetric_allowance_stock():
    service = PricingService()
    config = PricingService()._normalise(
        {
            "price": 2.5,
            "price_basis": "kg",
            "stock_shape": "rectangular",
            "allowances": {"x": 1.0, "y": 3.0, "z": 0.0},
            "quantity": 1,
            "rates": {"machine": 60.0},
        }
    )
    stock = service.calculate_stock(config, {"size": {"x": 100.0, "y": 50.0, "z": 25.0}})
    required = stock["required_stock"]
    assert required["length_mm"] == 102.0  # 100 + 2*1
    assert required["width_mm"] == 56.0  # 50 + 2*3
    assert required["height_mm"] == 25.0  # 25 + 2*0
    assert stock["fit"]["fits"] is True


def test_zero_allowance_stock():
    service = PricingService()
    config = PricingService()._normalise(
        {
            "price": 2.5,
            "price_basis": "kg",
            "stock_shape": "rectangular",
            "allowances": {"x": 0.0, "y": 0.0, "z": 0.0},
            "quantity": 1,
            "rates": {"machine": 60.0},
        }
    )
    stock = service.calculate_stock(config, {"size": {"x": 100.0, "y": 50.0, "z": 25.0}})
    required = stock["required_stock"]
    assert required["length_mm"] == 100.0  # 100 + 2*0
    assert required["width_mm"] == 50.0  # 50 + 2*0
    assert required["height_mm"] == 25.0  # 25 + 2*0


def test_blank_fit_shortage():
    service = PricingService()
    config = _base_config()
    stock = service.calculate_stock(
        config,
        {"size": {"x": 100.0, "y": 50.0, "z": 25.0}},
    )
    # Provide a blank that is too small in X.
    config["selected_blank"] = {"length_mm": 90.0, "width_mm": 60.0, "height_mm": 30.0}
    stock = service.calculate_stock(config, {"size": {"x": 100.0, "y": 50.0, "z": 25.0}})
    assert stock["fit"]["fits"] is False
    assert stock["fit"]["shortage"]["x"] > 0


def test_material_price_missing_is_warning_not_zero():
    service = PricingService()
    config = PricingService()._normalise(
        {
            "material": "aluminum_6061",
            "density_kg_m3": 2700.0,
            # price deliberately omitted
            "price_basis": "kg",
            "stock_shape": "rectangular",
            "allowances": {"x": 2.0, "y": 2.0, "z": 2.0},
            "quantity": 1,
            "rates": {"machine": 60.0, "setup": 40.0, "inspection": 30.0},
        }
    )
    plan = {
        "operations": [],
        "total_setup_time_min": 0.0,
        "total_tool_change_time_min": 0.0,
        "total_inspection_time_min": 0.0,
    }
    estimate = service.calculate(config, {}, plan, 1)
    assert any("Material price is missing" in w for w in estimate["warnings"]), estimate["warnings"]
    material_line = next(l for l in estimate["lines"] if l["id"] == "material")
    assert material_line["subtotal"] is None


def test_estimate_rounding_and_totals():
    service = PricingService()
    config = _base_config()
    plan = {
        "operations": [
            {
                "operation_id": "OP-1",
                "operation_type": "drilling",
                "estimated_time_min": 10.0,
                "machine": "generic_3axis",
            }
        ],
        "total_setup_time_min": 30.0,
        "total_tool_change_time_min": 0.0,
        "total_inspection_time_min": 0.0,
    }
    estimate = service.calculate(config, {}, plan, 1)
    assert estimate["total"] is not None
    assert estimate["total"] >= 0
    assert estimate["rounding"]["mode"] == "ROUND_HALF_UP"
    assert estimate["currency"] == "USD"


def test_overrides_applied():
    service = PricingService()
    config = _base_config()
    config["overrides"] = {"material": 100.0}
    plan = {
        "operations": [],
        "total_setup_time_min": 0.0,
        "total_tool_change_time_min": 0.0,
        "total_inspection_time_min": 0.0,
    }
    estimate = service.calculate(config, {}, plan, 1)
    material_line = next(l for l in estimate["lines"] if l["id"] == "material")
    assert material_line["is_override"] is True
    assert material_line["subtotal"] == 100.0


def test_estimate_quantity_charging():
    service = PricingService()
    config = _base_config()
    plan = {
        "operations": [],
        "total_setup_time_min": 0.0,
        "total_tool_change_time_min": 0.0,
        "total_inspection_time_min": 0.0,
    }
    estimate = service.calculate(config, {}, plan, 3)
    assert estimate["charged_quantity"] == 3
    assert estimate["quantity"] == 3
