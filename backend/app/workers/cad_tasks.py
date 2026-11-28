"""Celery tasks for CAD processing."""

import logging
from uuid import UUID

from app.core.celery_app import celery_app
from app.services.cad_service import CADService

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3)
def process_cad_file(self, file_path: str, project_id: str) -> dict:
    """Process a CAD file and extract geometry/features."""
    try:
        service = CADService()
        cad_specs = service.process_cad_file(Path(file_path), UUID(project_id))

        # TODO: Save to database
        # TODO: Update job status

        return {
            "status": "completed",
            "job_id": project_id,
            "features_found": len(cad_specs.features),
            "processing_time": cad_specs.processing_time_seconds,
        }
    except Exception as exc:
        logger.exception(f"CAD processing failed for {project_id}")
        raise self.retry(exc=exc, countdown=60)


@celery_app.task(bind=True)
def generate_views(self, file_path: str, project_id: str) -> dict:
    """Generate orthographic and isometric views."""
    # TODO: Implement view generation
    return {"status": "completed", "views": []}


@celery_app.task(bind=True)
def export_cad(self, file_path: str, project_id: str, format: str) -> dict:
    """Export CAD to different format."""
    # TODO: Implement export
    return {"status": "completed", "download_url": ""}
