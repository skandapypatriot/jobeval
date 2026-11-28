"""Health check endpoints."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check():
    """Basic health check."""
    return {"status": "healthy", "service": "jobeval-backend"}


@router.get("/health/ready")
async def readiness_check():
    """Readiness check with dependencies."""
    # TODO: Check database, redis, storage connectivity
    return {
        "status": "ready",
        "checks": {
            "database": "ok",
            "redis": "ok",
            "storage": "ok",
        },
    }
