"""In-process local analysis worker.

The worker owns its own database session, so it is safe to run after the
request session has closed.  It intentionally has no broker dependency.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import select

from app.core.database import db_manager
from app.models.jobeval import AnalysisJob, ManufacturingPlan, ProjectAnalysis, ProjectFile
from app.services.cad_service import CADService
from app.services.manufacturing_service import ManufacturingService


def _cancel_requested(session: Any, job: AnalysisJob) -> bool:
    session.refresh(job)
    return bool(job.cancel_requested) or job.status == "cancelled"


def run_analysis_job(job_id: str) -> None:
    """Execute one CAD analysis job and persist its result."""

    db_manager.init()
    session = db_manager.session_factory()
    try:
        job = session.get(AnalysisJob, job_id)
        if job is None:
            return
        if job.cancel_requested:
            job.status = "cancelled"
            job.stage = "cancelled"
            job.progress = 0.0
            job.completed_at = __import__("datetime").datetime.now(
                __import__("datetime").timezone.utc
            )
            session.commit()
            return
        job.status = "running"
        job.stage = "importing"
        job.progress = 0.1
        job.started_at = __import__("datetime").datetime.now(__import__("datetime").timezone.utc)
        session.commit()
        file = session.get(ProjectFile, job.file_id) if job.file_id else None
        if file is None:
            model_files = (
                session.execute(
                    select(ProjectFile).where(
                        ProjectFile.project_id == job.project_id, ProjectFile.role == "model_3d"
                    )
                )
                .scalars()
                .all()
            )
            file = model_files[0] if model_files else None
        if file is None:
            raise ValueError("No STEP model file is available for analysis")
        if _cancel_requested(session, job):
            return
        job.stage = "analyzing"
        job.progress = 0.35
        session.commit()
        from app.core.config import get_settings

        settings = get_settings()
        path = settings.upload_root / file.relative_path
        result = CADService().process_step(path, file.id)
        if _cancel_requested(session, job):
            return
        job.stage = "recognizing"
        job.progress = 0.8
        session.commit()
        analysis_row = (
            session.execute(
                select(ProjectAnalysis).where(ProjectAnalysis.project_id == job.project_id)
            )
            .scalars()
            .first()
        )
        if analysis_row is None:
            from uuid import uuid4

            analysis_row = ProjectAnalysis(id=str(uuid4()), project_id=job.project_id, data={})
            session.add(analysis_row)
        analysis_row.data = result
        analysis_row.updated_at = __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        )
        session.flush()
        plan = ManufacturingService().analyze_manufacturability(result)
        plan_row = (
            session.execute(
                select(ManufacturingPlan).where(ManufacturingPlan.project_id == job.project_id)
            )
            .scalars()
            .first()
        )
        if plan_row is None:
            from uuid import uuid4

            plan_row = ManufacturingPlan(id=str(uuid4()), project_id=job.project_id, data={})
            session.add(plan_row)
        plan_row.data = plan
        job.stage = "completed"
        job.status = "completed"
        job.progress = 1.0
        job.current_step = "analysis complete"
        job.result = {
            "analysis_id": analysis_row.id,
            "feature_count": len(result.get("features", [])),
        }
        job.completed_at = __import__("datetime").datetime.now(__import__("datetime").timezone.utc)
        session.commit()
    except Exception as exc:
        session.rollback()
        job = session.get(AnalysisJob, job_id)
        if job is not None:
            job.status = "failed"
            job.stage = "failed"
            job.error = str(exc)
            job.current_step = "analysis failed"
            job.completed_at = __import__("datetime").datetime.now(
                __import__("datetime").timezone.utc
            )
            session.commit()
    finally:
        session.close()


def run_job_in_background(job_id: str) -> None:
    """Small wrapper that catches unexpected worker failures."""

    try:
        run_analysis_job(job_id)
    except Exception:
        # The worker itself records job errors; this guard prevents a broken
        # task from escaping into the ASGI server.
        return
