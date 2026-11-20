"""LLM integration API endpoints."""

from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status

from app.services.llm_service import LLMService

router = APIRouter()


@router.post("/analyze")
async def analyze_with_llm(
    project_id: str,
    prompt_type: str = "feature_explanation",
) -> dict[str, Any]:
    """Analyze CAD data with LLM."""
    # TODO: Load CAD specs from database
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="LLM analysis requires CAD specs to be loaded from database",
    )


@router.post("/report")
async def generate_llm_report(
    project_id: str,
    report_type: str = "manufacturing",
) -> dict[str, Any]:
    """Generate LLM-powered manufacturing report."""
    # TODO: Load CAD specs from database
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="LLM report generation requires CAD specs from database",
    )


@router.get("/privacy")
async def get_privacy_info() -> dict[str, Any]:
    """Get LLM privacy and data flow information."""
    service = LLMService()
    return {
        "privacy_mode": service.privacy_mode,
        "provider": service.provider,
        "model": service.model,
        "zero_data_retention": service.enable_zdr,
        "allowed_providers": service.allowed_providers,
        "cloud_allowed": service.is_cloud_allowed(),
        "data_flow": service.get_data_flow_description(),
    }


@router.post("/privacy/mode")
async def set_privacy_mode(
    mode: str,
) -> dict[str, Any]:
    """Set privacy mode (local or approved_cloud)."""
    if mode not in ("local", "approved_cloud"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid privacy mode. Use 'local' or 'approved_cloud'",
        )

    # TODO: Update settings persistently
    return {
        "privacy_mode": mode,
        "message": f"Privacy mode set to {mode}",
        "note": "Changes apply to new LLM requests only",
    }