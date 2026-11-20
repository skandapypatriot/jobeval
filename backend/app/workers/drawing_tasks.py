"""Celery tasks for drawing processing."""

import logging
from pathlib import Path
from uuid import UUID

from app.core.celery_app import celery_app
from app.services.drawing_service import DrawingService

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3)
def process_drawing_file(self, file_path: str, project_id: str) -> dict:
    """Process a drawing file (PDF/DXF) and extract annotations."""
    try:
        service = DrawingService()
        annotations = service.process_drawing(Path(file_path), UUID(project_id))

        # TODO: Save to database
        # TODO: Update job status

        return {
            "status": "completed",
            "job_id": project_id,
            "pages_processed": annotations.total_pages,
            "dimensions_found": sum(len(p.dimensions) for p in annotations.pages),
        }
    except Exception as exc:
        logger.exception(f"Drawing processing failed for {project_id}")
        raise self.retry(exc=exc, countdown=60)


@celery_app.task(bind=True)
def compare_model_drawing(self, project_id: str) -> dict:
    """Compare 3D model with 2D drawing."""
    # TODO: Implement cross-validation
    return {"status": "completed", "checks": []}