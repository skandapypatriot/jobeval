"""JobEval API v1 routes."""

from fastapi import APIRouter

from app.api.v1.jobeval import router as jobeval_router

router = APIRouter()
router.include_router(jobeval_router)

__all__ = ["router"]
