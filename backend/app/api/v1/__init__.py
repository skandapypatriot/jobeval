"""API v1 routes."""

from fastapi import APIRouter

from app.api.v1.health import router as health_router
from app.api.v1.jobs import router as jobs_router
from app.api.v1.cad import router as cad_router
from app.api.v1.drawings import router as drawings_router
from app.api.v1.manufacturing import router as manufacturing_router
from app.api.v1.materials import router as materials_router
from app.api.v1.llm import router as llm_router

router = APIRouter()

# Sub-routers with their own prefixes
router.include_router(health_router, tags=["Health"])
router.include_router(jobs_router, tags=["Projects"])

# Sub-routers without prefixes - add them here
router.include_router(cad_router, prefix="/cad", tags=["CAD"])
router.include_router(drawings_router, prefix="/drawings", tags=["Drawings"])
router.include_router(manufacturing_router, prefix="/manufacturing", tags=["Manufacturing"])
router.include_router(materials_router, prefix="/materials", tags=["Materials"])
router.include_router(llm_router, prefix="/llm", tags=["LLM"])