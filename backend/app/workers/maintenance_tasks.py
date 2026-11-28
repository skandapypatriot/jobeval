"""Celery tasks for maintenance and cleanup."""

import logging
from datetime import datetime, timedelta

from app.core.celery_app import celery_app
from app.core.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)


@celery_app.task(bind=True)
def cleanup_expired_jobs(self) -> dict:
    """Clean up expired jobs and associated data."""
    try:
        # TODO: Implement cleanup logic
        # - Delete jobs older than DATA_RETENTION_DAYS
        # - Clean up associated files
        # - Update database

        logger.info("Running expired jobs cleanup")
        return {"status": "completed", "cleaned": 0}
    except Exception as exc:
        logger.exception("Expired jobs cleanup failed")
        raise self.retry(exc=exc, countdown=300)


@celery_app.task(bind=True)
def cleanup_temp_files(self) -> dict:
    """Clean up temporary files."""
    try:
        temp_dir = settings.TEMP_DIR
        cutoff = datetime.now() - timedelta(hours=24)

        cleaned = 0
        for file_path in temp_dir.glob("*"):
            if file_path.is_file():
                mtime = datetime.fromtimestamp(file_path.stat().st_mtime)
                if mtime < cutoff:
                    file_path.unlink()
                    cleaned += 1

        logger.info(f"Cleaned up {cleaned} temporary files")
        return {"status": "completed", "cleaned": cleaned}
    except Exception as exc:
        logger.exception("Temp file cleanup failed")
        raise self.retry(exc=exc, countdown=300)
