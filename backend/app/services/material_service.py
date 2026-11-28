"""Material Database Service - Material properties and regional pricing."""

import logging
import re

from app.core.config import get_settings
from app.models.material import Material as MaterialModel
from app.models.material import MaterialPricing as MaterialPricingModel
from app.schemas.cad_specs import BoundingBox3D, Material, MaterialPricing, Vector3D

settings = get_settings()
logger = logging.getLogger(__name__)


class MaterialService:
    """Service for material management and regional pricing."""

    def __init__(self) -> None:
        self.settings = settings
        self._material_db: dict[str, MaterialModel] = {}
        self._pricing_db: dict[str, list[MaterialPricingModel]] = {}
        self._initialize_default_materials()

    def _initialize_default_materials(self) -> None:
        """Initialize default material database with common engineering materials."""
        default_materials = [
            {
                "name": "Aluminum",
                "grade": "6061-T6",
                "standard": "ASTM B221",
                "category": "aluminum",
                "density_kg_m3": 2700.0,
                "properties": {
                    "yield_strength_mpa": 276,
                    "tensile_strength_mpa": 310,
                    "elongation_pct": 12,
                    "hardness_hb": 95,
                    "thermal_conductivity_w_mk": 167,
                },
            },
            {
                "name": "Aluminum",
                "grade": "7075-T6",
                "standard": "ASTM B221",
                "category": "aluminum",
                "density_kg_m3": 2810.0,
                "properties": {
                    "yield_strength_mpa": 503,
                    "tensile_strength_mpa": 572,
                    "elongation_pct": 11,
                    "hardness_hb": 150,
                    "thermal_conductivity_w_mk": 130,
                },
            },
            {
                "name": "Steel",
                "grade": "1018",
                "standard": "ASTM A108",
                "category": "steel",
                "density_kg_m3": 7870.0,
                "properties": {
                    "yield_strength_mpa": 370,
                    "tensile_strength_mpa": 440,
                    "elongation_pct": 15,
                    "hardness_hb": 126,
                    "thermal_conductivity_w_mk": 51.9,
                },
            },
            {
                "name": "Steel",
                "grade": "4140",
                "standard": "ASTM A829",
                "category": "steel",
                "density_kg_m3": 7850.0,
                "properties": {
                    "yield_strength_mpa": 415,
                    "tensile_strength_mpa": 655,
                    "elongation_pct": 25,
                    "hardness_hb": 197,
                    "thermal_conductivity_w_mk": 42.7,
                },
            },
            {
                "name": "Stainless Steel",
                "grade": "304",
                "standard": "ASTM A240",
                "category": "stainless",
                "density_kg_m3": 8000.0,
                "properties": {
                    "yield_strength_mpa": 215,
                    "tensile_strength_mpa": 505,
                    "elongation_pct": 40,
                    "hardness_hb": 123,
                    "thermal_conductivity_w_mk": 16.2,
                },
            },
            {
                "name": "Stainless Steel",
                "grade": "316",
                "standard": "ASTM A240",
                "category": "stainless",
                "density_kg_m3": 8000.0,
                "properties": {
                    "yield_strength_mpa": 205,
                    "tensile_strength_mpa": 515,
                    "elongation_pct": 40,
                    "hardness_hb": 149,
                    "thermal_conductivity_w_mk": 16.3,
                },
            },
            {
                "name": "Brass",
                "grade": "C36000",
                "standard": "ASTM B16",
                "category": "brass",
                "density_kg_m3": 8470.0,
                "properties": {
                    "yield_strength_mpa": 140,
                    "tensile_strength_mpa": 340,
                    "elongation_pct": 25,
                    "hardness_hb": 100,
                    "thermal_conductivity_w_mk": 115,
                },
            },
            {
                "name": "Copper",
                "grade": "C11000",
                "standard": "ASTM B152",
                "category": "copper",
                "density_kg_m3": 8940.0,
                "properties": {
                    "yield_strength_mpa": 70,
                    "tensile_strength_mpa": 220,
                    "elongation_pct": 45,
                    "hardness_hb": 40,
                    "thermal_conductivity_w_mk": 391,
                },
            },
            {
                "name": "Delrin",
                "grade": "Acetal",
                "standard": "ASTM D6100",
                "category": "plastic",
                "density_kg_m3": 1420.0,
                "properties": {
                    "yield_strength_mpa": 70,
                    "tensile_strength_mpa": 75,
                    "elongation_pct": 25,
                    "hardness_hb": 85,
                    "thermal_conductivity_w_mk": 0.31,
                },
            },
            {
                "name": "Nylon 6/6",
                "grade": "PA66",
                "standard": "ASTM D4066",
                "category": "plastic",
                "density_kg_m3": 1140.0,
                "properties": {
                    "yield_strength_mpa": 80,
                    "tensile_strength_mpa": 85,
                    "elongation_pct": 50,
                    "hardness_hb": 78,
                    "thermal_conductivity_w_mk": 0.25,
                },
            },
        ]

        for mat_data in default_materials:
            mat = MaterialModel(**mat_data)
            self._material_db[f"{mat.name}:{mat.grade}"] = mat

    def get_material(self, material_id: str) -> MaterialModel | None:
        """Get material by ID (name:grade format)."""
        return self._material_db.get(material_id)

    def list_materials(self, category: str | None = None) -> list[MaterialModel]:
        """List available materials, optionally filtered by category."""
        if category:
            return [m for m in self._material_db.values() if m.category == category]
        return list(self._material_db.values())

    def search_materials(self, query: str) -> list[MaterialModel]:
        """Search materials by name, grade, or category."""
        query_lower = query.lower()
        return [
            m
            for m in self._material_db.values()
            if query_lower in m.name.lower()
            or query_lower in (m.grade or "").lower()
            or query_lower in m.category.lower()
        ]

    def get_pricing(
        self,
        material_id: str,
        region: str,
        stock_dimensions: BoundingBox3D | None = None,
        quantity: int = 1,
    ) -> MaterialPricing:
        """
        Get material pricing for a region and stock size.
        Returns indicative pricing - not a verified quote.
        """
        material = self.get_material(material_id)
        if not material:
            return MaterialPricing(
                material=material_id,
                region=region,
                stock_weight_kg=0.0,
                currency="USD",
                availability="unknown",
                is_verified=False,
                notes=["Material not found in database"],
            )

        # Calculate stock weight
        stock_weight_kg = 0.0
        if stock_dimensions:
            dx = stock_dimensions.max.x - stock_dimensions.min.x
            dy = stock_dimensions.max.y - stock_dimensions.min.y
            dz = stock_dimensions.max.z - stock_dimensions.min.z
            volume_cm3 = (dx * dy * dz) / 1000.0
            density_g_cm3 = material.density_kg_m3 / 1000.0  # kg/m3 to g/cm3
            stock_weight_kg = volume_cm3 * density_g_cm3 / 1000.0

        # Indicative pricing by material category and region
        # These are placeholder values - real implementation would query supplier APIs
        base_price_per_kg = self._get_base_price_per_kg(material.category)
        region_multiplier = self._get_region_multiplier(region)

        price_per_kg = round(base_price_per_kg * region_multiplier, 2)
        price_total = round(price_per_kg * stock_weight_kg, 2) if stock_weight_kg > 0 else None

        # Determine availability based on material commonality
        availability = "in_stock" if material.category in ("aluminum", "steel") else "lead_time"
        lead_time_days = 1 if availability == "in_stock" else 10

        return MaterialPricing(
            material=material_id,
            region=region,
            supplier=None,  # No verified supplier in indicative mode
            stock_dimensions=stock_dimensions,
            stock_weight_kg=round(stock_weight_kg, 2),
            price_per_kg=price_per_kg,
            price_total=price_total,
            currency="USD",
            availability=availability,
            lead_time_days=lead_time_days,
            is_verified=False,  # Indicative only
            notes=[
                "Indicative pricing - not a verified supplier quote",
                f"Base price: ${base_price_per_kg}/kg for {material.category}",
                f"Region multiplier: {region_multiplier}x for {region}",
                "Contact supplier for actual pricing and availability",
            ],
        )

    def get_verified_quote(
        self,
        material_id: str,
        region: str,
        stock_dimensions: BoundingBox3D | None = None,
        quantity: int = 1,
    ) -> MaterialPricing | None:
        """
        Get a verified supplier quote if available.
        Returns None if no verified quote exists (indicative pricing only).
        """
        # In a real implementation, this would query a supplier database
        # For now, return None to indicate no verified quotes available
        return None

    def _get_base_price_per_kg(self, category: str) -> float:
        """Get base price per kg for a material category (indicative USD)."""
        prices = {
            "aluminum": 3.50,
            "steel": 1.20,
            "stainless": 4.50,
            "brass": 5.00,
            "copper": 8.00,
            "plastic": 2.00,
            "other": 5.00,
        }
        return prices.get(category, 5.00)

    def _get_region_multiplier(self, region: str) -> float:
        """Get price multiplier for a region (indicative)."""
        multipliers = {
            "domestic": 1.0,
            "usa": 1.0,
            "canada": 1.1,
            "mexico": 0.9,
            "europe": 1.2,
            "germany": 1.25,
            "china": 0.8,
            "india": 0.75,
            "asia": 0.85,
        }
        return multipliers.get(region.lower(), 1.0)

    def estimate_stock_from_bbox(
        self,
        bbox: BoundingBox3D,
        margin_mm: float = 5.0,
    ) -> tuple[BoundingBox3D, float, float]:
        """
        Estimate stock dimensions, volume, and weight from part bounding box.
        Returns (stock_dimensions, volume_cm3, weight_kg) for aluminum.
        """
        dx = bbox.max.x - bbox.min.x
        dy = bbox.max.y - bbox.min.y
        dz = bbox.max.z - bbox.min.z

        stock_dx = dx + 2 * margin_mm
        stock_dy = dy + 2 * margin_mm
        stock_dz = dz + 2 * margin_mm

        stock_dimensions = BoundingBox3D(
            min=Vector3D(
                x=bbox.min.x - margin_mm,
                y=bbox.min.y - margin_mm,
                z=bbox.min.z - margin_mm,
            ),
            max=Vector3D(
                x=bbox.max.x + margin_mm,
                y=bbox.max.y + margin_mm,
                z=bbox.max.z + margin_mm,
            ),
        )

        volume_cm3 = (stock_dx * stock_dy * stock_dz) / 1000.0
        density_g_cm3 = 2.7  # Aluminum
        weight_kg = volume_cm3 * density_g_cm3 / 1000.0

        return stock_dimensions, round(volume_cm3, 1), round(weight_kg, 2)

    def parse_material_from_text(self, text: str) -> Material | None:
        """Parse material specification from drawing text."""
        text_upper = text.upper()

        # Common material patterns
        material_patterns = [
            (r"AL\s*6061", "Aluminum", "6061-T6", "ASTM B221", "aluminum", 2700.0),
            (r"AL\s*7075", "Aluminum", "7075-T6", "ASTM B221", "aluminum", 2810.0),
            (r"STEEL\s*1018", "Steel", "1018", "ASTM A108", "steel", 7870.0),
            (r"STEEL\s*4140", "Steel", "4140", "ASTM A829", "steel", 7850.0),
            (r"SS\s*304", "Stainless Steel", "304", "ASTM A240", "stainless", 8000.0),
            (r"SS\s*316", "Stainless Steel", "316", "ASTM A240", "stainless", 8000.0),
            (r"BRASS\s*C360", "Brass", "C36000", "ASTM B16", "brass", 8470.0),
            (r"COPPER\s*C110", "Copper", "C11000", "ASTM B152", "copper", 8940.0),
        ]

        for pattern, name, grade, standard, category, density in material_patterns:
            if re.search(pattern, text_upper):
                return Material(
                    name=name,
                    grade=grade,
                    standard=standard,
                    density_kg_m3=density,
                    source="drawing",
                    confidence=0.85,
                )

        return None

    def match_drawing_material_to_db(
        self,
        drawing_material: str | None,
    ) -> MaterialModel | None:
        """Match a drawing material specification to a database entry."""
        if not drawing_material:
            return None

        # Try exact match first
        for mat in self._material_db.values():
            if drawing_material.lower().strip() == f"{mat.name} {mat.grade}".lower():
                return mat

        # Try parsing from text
        parsed = self.parse_material_from_text(drawing_material)
        if parsed:
            db_key = f"{parsed.name}:{parsed.grade}"
            return self._material_db.get(db_key)

        return None
