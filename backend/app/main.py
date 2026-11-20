"""JobEval Backend — Main FastAPI Application."""

import uuid
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.celery_app import celery_app
from app.core.config import get_settings
from app.core.database import db_manager
from app.core.logging import LoggingMiddleware, configure_logging, get_logger

settings = get_settings()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan manager."""
    # Startup
    logger.info("starting_application", version=settings.APP_VERSION)
    configure_logging()

    # Initialize database
    db_manager.init()
    await db_manager.create_tables()
    logger.info("database_initialized")

    # Initialize storage directories
    settings.UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    settings.TEMP_DIR.mkdir(parents=True, exist_ok=True)
    settings.OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    logger.info("storage_directories_ready")

    # Verify Celery connection
    try:
        celery_app.control.ping(timeout=5)
        logger.info("celery_broker_connected")
    except Exception as e:
        logger.warning("celery_broker_unavailable", error=str(e))

    logger.info("application_started")

    yield

    # Shutdown
    logger.info("shutting_down_application")
    await db_manager.close()
    logger.info("application_stopped")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title="JobEval API",
        description="Intelligent CAD Analysis & CNC Cost Estimation",
        version=settings.APP_VERSION,
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        openapi_url="/openapi.json" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=settings.CORS_ALLOW_CREDENTIALS,
        allow_methods=settings.CORS_ALLOW_METHODS,
        allow_headers=settings.CORS_ALLOW_HEADERS,
    )

    # Request logging middleware
    app.add_middleware(LoggingMiddleware)

    # Request ID middleware
    @app.middleware("http")
    async def add_request_id(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4())[:8])
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

    # Global exception handler
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.exception(
            "unhandled_exception",
            path=request.url.path,
            method=request.method,
            error=str(exc),
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal server error",
                "request_id": getattr(request.state, "request_id", "unknown"),
            },
        )

    # Health check endpoints
    @app.get("/health", tags=["Health"])
    async def health_check():
        """Basic health check."""
        return {"status": "healthy", "version": settings.APP_VERSION}

    @app.get("/health/ready", tags=["Health"])
    async def readiness_check():
        """Readiness check with dependencies."""
        checks = {}

        # Database
        try:
            async with db_manager.session() as session:
                await session.execute("SELECT 1")
            checks["database"] = "ok"
        except Exception as e:
            checks["database"] = f"error: {e}"

        # Redis/Celery
        try:
            celery_app.control.ping(timeout=2)
            checks["celery"] = "ok"
        except Exception as e:
            checks["celery"] = f"error: {e}"

        # Storage
        try:
            settings.UPLOAD_DIR.mkdir(exist_ok=True)
            checks["storage"] = "ok"
        except Exception as e:
            checks["storage"] = f"error: {e}"

        all_healthy = all(v == "ok" for v in checks.values())
        status_code = 200 if all_healthy else 503

        return JSONResponse(
            status_code=status_code,
            content={"status": "ready" if all_healthy else "not_ready", "checks": checks},
        )

    # API routes
    from app.api import router as api_router
    app.include_router(api_router, prefix=settings.API_PREFIX)

    @app.get("/", tags=["Root"])
    async def root():
        """API root endpoint."""
        return {
            "name": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "description": "Intelligent CAD Analysis & CNC Cost Estimation",
            "docs": "/docs" if settings.DEBUG else "disabled",
        }

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        workers=settings.WORKERS if not settings.DEBUG else 1,
    )