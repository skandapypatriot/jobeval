"""Celery application configuration."""

from celery import Celery
from celery.schedules import crontab

from app.core.config import get_settings

settings = get_settings()


def create_celery_app() -> Celery:
    """Create and configure Celery application."""
    celery_app = Celery("jobeval")

    celery_app.conf.update(
        broker_url=settings.CELERY_BROKER_URL,
        result_backend=settings.CELERY_RESULT_BACKEND,
        task_serializer="json",
        result_serializer="json",
        accept_content=["json"],
        timezone="UTC",
        enable_utc=True,
        task_track_started=settings.CELERY_TASK_TRACK_STARTED,
        task_time_limit=settings.CELERY_TASK_TIME_LIMIT,
        task_acks_late=True,
        worker_prefetch_multiplier=settings.CELERY_WORKER_PREFETCH_MULTIPLIER,
        worker_max_tasks_per_child=100,
        result_expires=3600,
        task_routes={
            "app.workers.cad_tasks.*": {"queue": "cad_processing"},
            "app.workers.drawing_tasks.*": {"queue": "drawing_processing"},
            "app.workers.manufacturing_tasks.*": {"queue": "manufacturing"},
            "app.workers.llm_tasks.*": {"queue": "llm"},
        },
        beat_schedule={
            "cleanup-expired-jobs": {
                "task": "app.workers.maintenance_tasks.cleanup_expired_jobs",
                "schedule": crontab(hour=2, minute=0),
            },
            "cleanup-temp-files": {
                "task": "app.workers.maintenance_tasks.cleanup_temp_files",
                "schedule": crontab(hour=3, minute=0),
            },
        },
    )

    # Auto-discover tasks
    celery_app.autodiscover_tasks(
        [
            "app.workers.cad_tasks",
            "app.workers.drawing_tasks",
            "app.workers.manufacturing_tasks",
            "app.workers.llm_tasks",
            "app.workers.maintenance_tasks",
        ]
    )

    return celery_app


celery_app = create_celery_app()


@celery_app.task(bind=True, ignore_result=True)
def debug_task(self):
    """Debug task for testing Celery."""
    print(f"Request: {self.request!r}")
