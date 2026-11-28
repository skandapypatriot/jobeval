"""FastAPI application factory for the local JobEval backend."""

from __future__ import annotations

import uuid
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import db_manager, get_db_session
from app.core.logging import LoggingMiddleware, configure_logging, get_logger
from app.models.jobeval import Project

settings = get_settings()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    configure_logging()
    settings = get_settings()
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
    settings.upload_root.mkdir(parents=True, exist_ok=True)
    (settings.DATA_DIR / "tmp").mkdir(parents=True, exist_ok=True)
    (settings.DATA_DIR / "outputs").mkdir(parents=True, exist_ok=True)
    db_manager.init()
    db_manager.create_tables()
    logger.info(
        "application_started", database=settings.database_url, upload_dir=str(settings.upload_root)
    )
    try:
        yield
    finally:
        db_manager.close()
        logger.info("application_stopped")


def create_app() -> FastAPI:
    app = FastAPI(
        title="JobEval API",
        description="Local CAD geometry, manufacturing planning, and transparent cost estimation.",
        version=get_settings().APP_VERSION,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    origins = get_settings().CORS_ORIGINS
    allow_credentials = get_settings().CORS_ALLOW_CREDENTIALS and "*" not in origins
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=allow_credentials,
        allow_methods=get_settings().CORS_ALLOW_METHODS,
        allow_headers=get_settings().CORS_ALLOW_HEADERS,
    )
    app.add_middleware(LoggingMiddleware)

    @app.middleware("http")
    async def request_id_middleware(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError):
        return JSONResponse(
            status_code=422,
            content={
                "error": "Validation error",
                "detail": "The request did not match the JobEval API contract.",
                "errors": exc.errors(),
                "request_id": getattr(request.state, "request_id", None),
            },
        )

    @app.exception_handler(HTTPException)
    async def http_error_handler(request: Request, exc: HTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": "Request failed",
                "detail": exc.detail,
                "request_id": getattr(request.state, "request_id", None),
            },
            headers=exc.headers,
        )

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception):
        logger.exception(
            "unhandled_exception", path=request.url.path, method=request.method, error=str(exc)
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": "Internal server error",
                "detail": "The local backend could not complete the request.",
                "request_id": getattr(request.state, "request_id", None),
            },
        )

    @app.get("/health", tags=["Health"])
    def health() -> dict[str, str]:
        settings = get_settings()
        database = "ok"
        storage = "ok"
        try:
            db_manager.init()
            with db_manager.session() as session:
                session.execute(select(Project).limit(1)).first()
        except Exception as exc:  # pragma: no cover - depends on environment
            database = f"error: {exc}"
        try:
            upload_root = settings.upload_root
            upload_root.mkdir(parents=True, exist_ok=True)
            probe = upload_root / ".jobeval_health_probe"
            probe.write_text("ok", encoding="utf-8")
            probe.unlink(missing_ok=True)
        except Exception as exc:  # pragma: no cover - depends on environment
            storage = f"error: {exc}"
        overall = "healthy" if database == "ok" and storage == "ok" else "degraded"
        return {
            "status": overall,
            "service": "jobeval-backend",
            "version": get_settings().APP_VERSION,
            "database": database,
            "storage": storage,
        }

    @app.get("/api/v1/health", tags=["Health"])
    def api_health() -> dict[str, str]:
        return health()

    from app.api import router as api_router

    app.include_router(api_router, prefix=get_settings().API_PREFIX)

    # A root dashboard alias is convenient for local clients; the canonical
    # versioned endpoint remains /api/v1/dashboard.
    from app.api.v1.jobeval import dashboard

    @app.get("/dashboard", include_in_schema=False)
    def dashboard_alias(db: Session = Depends(get_db_session)):
        return dashboard(db)

    @app.get("/", tags=["Root"])
    def root() -> dict[str, str]:
        return {
            "name": get_settings().APP_NAME,
            "version": get_settings().APP_VERSION,
            "docs": "/docs",
            "openapi": "/openapi.json",
        }

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host=get_settings().HOST, port=get_settings().PORT)
