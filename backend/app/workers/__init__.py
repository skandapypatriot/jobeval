"""Celery workers package."""

from app.workers import cad_tasks, drawing_tasks, manufacturing_tasks, llm_tasks, maintenance_tasks

__all__ = [
    "cad_tasks",
    "drawing_tasks",
    "manufacturing_tasks",
    "llm_tasks",
    "maintenance_tasks",
]