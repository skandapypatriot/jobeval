"""API package."""

from fastapi import APIRouter

from app.api.v1 import router as v1_router
from app.api.v1.health import router as health_router

router = APIRouter()

# v1_router already has /api/v1 prefix from main.py
# Don't add another prefix here
router.include_router(v1_router)
router.include_router(health_router, tags=["Health"])