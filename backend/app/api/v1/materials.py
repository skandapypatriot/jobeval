"""Materials and pricing API endpoints."""

from typing import Any

from fastapi import APIRouter, HTTPException, status

from app.services.material_service import MaterialService

router = APIRouter()


@router.get("")
async def list_materials(
    category: str | None = None,
    search: str | None = None,
) -> dict[str, Any]:
    """List available materials."""
    service = MaterialService()
    materials = service.list_materials(category=category)

    if search:
        materials = service.search_materials(search)

    return {
        "materials": [
            {
                "id": f"{m.name}:{m.grade}",
                "name": m.name,
                "grade": m.grade,
                "standard": m.standard,
                "category": m.category,
                "density_kg_m3": m.density_kg_m3,
                "properties": m.properties,
                "is_active": m.is_active,
            }
            for m in materials
        ],
        "total": len(materials),
    }


@router.get("/{material_id}")
async def get_material(
    material_id: str,
) -> dict[str, Any]:
    """Get material details by ID (name:grade format)."""
    service = MaterialService()
    material = service.get_material(material_id)

    if not material:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Material not found: {material_id}",
        )

    return {
        "id": f"{material.name}:{material.grade}",
        "name": material.name,
        "grade": material.grade,
        "standard": material.standard,
        "category": material.category,
        "density_kg_m3": material.density_kg_m3,
        "properties": material.properties,
        "is_active": material.is_active,
    }


@router.post("/pricing")
async def get_material_pricing(
    material_id: str,
    region: str = "domestic",
    stock_length_mm: float | None = None,
    stock_width_mm: float | None = None,
    stock_height_mm: float | None = None,
    quantity: int = 1,
) -> dict[str, Any]:
    """Get material pricing for a region and stock size."""
    from app.schemas.cad_specs import BoundingBox3D, Vector3D

    service = MaterialService()

    stock_dimensions = None
    if stock_length_mm and stock_width_mm and stock_height_mm:
        stock_dimensions = BoundingBox3D(
            min=Vector3D(x=0, y=0, z=0),
            max=Vector3D(x=stock_length_mm, y=stock_width_mm, z=stock_height_mm),
        )

    pricing = service.get_pricing(
        material_id=material_id,
        region=region,
        stock_dimensions=stock_dimensions,
        quantity=quantity,
    )

    return {
        "material": pricing.material,
        "region": pricing.region,
        "supplier": pricing.supplier,
        "stock_weight_kg": pricing.stock_weight_kg,
        "price_per_kg": pricing.price_per_kg,
        "price_total": pricing.price_total,
        "currency": pricing.currency,
        "availability": pricing.availability,
        "lead_time_days": pricing.lead_time_days,
        "is_verified": pricing.is_verified,
        "notes": pricing.notes,
    }


@router.get("/categories")
async def get_material_categories() -> dict[str, Any]:
    """Get available material categories."""
    return {
        "categories": [
            {"id": "aluminum", "name": "Aluminum"},
            {"id": "steel", "name": "Steel"},
            {"id": "stainless", "name": "Stainless Steel"},
            {"id": "brass", "name": "Brass"},
            {"id": "copper", "name": "Copper"},
            {"id": "plastic", "name": "Engineering Plastics"},
            {"id": "other", "name": "Other"},
        ]
    }
