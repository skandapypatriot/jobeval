"""Small structured logging setup with an ASGI request logger."""

from __future__ import annotations

import logging
import sys
from typing import Any

import structlog

from app.core.config import get_settings


def configure_logging() -> None:
    settings = get_settings()
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    )
    processors: list[Any] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
    ]
    processors.append(
        structlog.processors.JSONRenderer()
        if settings.LOG_FORMAT == "json"
        else structlog.dev.ConsoleRenderer(colors=False)
    )
    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=False,
    )


def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    return structlog.get_logger(name)


class LoggingMiddleware:
    def __init__(self, app: Any) -> None:
        self.app = app
        self.logger = get_logger("request")

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        import uuid

        request_id = str(uuid.uuid4())
        structlog.contextvars.bind_contextvars(
            request_id=request_id, method=scope.get("method"), path=scope.get("path")
        )
        self.logger.info("request_started")
        status_code = 500

        async def send_wrapper(message: dict[str, Any]) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = int(message.get("status", 500))
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
            self.logger.info("request_completed", status_code=status_code)
        except Exception:
            self.logger.exception("request_failed", status_code=status_code)
            raise
        finally:
            structlog.contextvars.clear_contextvars()


configure_logging()
