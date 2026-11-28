"""Celery tasks for LLM integration."""

import logging

from app.core.celery_app import celery_app
from app.services.llm_service import LLMService

logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3)
def analyze_with_llm(self, project_id: str, prompt_type: str) -> dict:
    """Analyze CAD data with LLM."""
    try:
        # TODO: Load CAD specs from database
        # cad_specs = ...

        service = LLMService()
        # result = await service.analyze_features(cad_specs, prompt_type)
        # await service.close()

        # TODO: Save to database

        return {
            "status": "completed",
            "job_id": project_id,
            "prompt_type": prompt_type,
        }
    except Exception as exc:
        logger.exception(f"LLM analysis failed for {project_id}")
        raise self.retry(exc=exc, countdown=60)
