"""JobEval v1 API routes.

All business endpoints are under ``/api/v1``.  The root ``/health`` alias is
provided by the application factory for shell and container probes.
"""

from __future__ import annotations

import copy
import io
import json
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse, HTMLResponse, PlainTextResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_db_session
from app.models.jobeval import (
    AnalysisJob,
    ChatMessage,
    CostEstimate,
    CrossValidation,
    DrawingAnalysis,
    ManufacturingPlan,
    PricingConfig,
    Project,
    ProjectAnalysis,
    ProjectFile,
    ReportRecord,
)
from app.schemas.jobeval import (
    AnalysisRequest,
    ChatMessageResponse,
    ChatMessageSend,
    ChatHistoryResponse,
    CrossValidationRequest,
    DiscrepancyReviewRequest,
    DrawingParseRequest,
    EstimateRequest,
    ExplanationRequest,
    FeatureReviewRequest,
    ManufacturingPlanUpdate,
    PricingConfigUpdate,
    ProjectCreate,
    ProjectPatch,
)
from app.services.cross_validation_service import CrossValidationService
from app.services.drawing_service import DrawingService
from app.services.llm_service import LLMService
from app.services.manufacturing_service import ManufacturingService
from app.services.pricing_service import PricingService
from app.services.reports_service import build_report, report_csv, report_html, report_json
from app.services.storage import LocalStorage, StorageError
from app.workers.local_analysis import run_job_in_background

router = APIRouter()


def _now() -> datetime:
    return datetime.now(UTC)


def _project_dict(project: Project, db: Session | None = None) -> dict[str, Any]:
    file_count = 0
    if db is not None:
        file_count = len(session_files(db, project.id))
    return {
        "id": project.id,
        "name": project.name,
        "description": project.description,
        "status": project.status,
        "is_demo": project.is_demo,
        "created_at": project.created_at,
        "updated_at": project.updated_at,
        "file_count": file_count,
    }


def session_files(db: Session, project_id: str) -> list[ProjectFile]:
    return list(
        db.execute(
            select(ProjectFile)
            .where(ProjectFile.project_id == project_id)
            .order_by(ProjectFile.uploaded_at)
        )
        .scalars()
        .all()
    )


def _file_dict(file: ProjectFile) -> dict[str, Any]:
    return {
        "id": file.id,
        "project_id": file.project_id,
        "filename": file.original_filename,
        "original_filename": file.original_filename,
        "stored_filename": file.stored_filename,
        "extension": file.extension,
        "mime_type": file.mime_type,
        "size_bytes": file.size_bytes,
        "sha256": file.sha256,
        "role": file.role,
        "status": file.status,
        "uploaded_at": file.uploaded_at,
        "download_url": f"/api/v1/files/{file.id}/download",
    }


def _get_project(db: Session, project_id: str) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=404, detail=f"Project '{project_id}' was not found")
    return project


def _get_file(db: Session, file_id: str) -> ProjectFile:
    file = db.get(ProjectFile, file_id)
    if file is None:
        raise HTTPException(status_code=404, detail=f"File '{file_id}' was not found")
    return file


def _get_analysis(db: Session, project_id: str) -> ProjectAnalysis:
    analysis = (
        db.execute(select(ProjectAnalysis).where(ProjectAnalysis.project_id == project_id))
        .scalars()
        .first()
    )
    if analysis is None:
        raise HTTPException(
            status_code=404, detail="No CAD analysis exists for this project; run analysis first"
        )
    return analysis


def _job_dict(job: AnalysisJob) -> dict[str, Any]:
    return {
        "id": job.id,
        "job_id": job.id,
        "project_id": job.project_id,
        "file_id": job.file_id,
        "kind": job.kind,
        "status": job.status,
        "state": job.status,
        "stage": job.stage,
        "progress": round(float(job.progress or 0.0), 4),
        "current_step": job.current_step,
        "error": job.error,
        "cancel_requested": job.cancel_requested,
        "result": job.result,
        "created_at": job.created_at,
        "started_at": job.started_at,
        "completed_at": job.completed_at,
        "updated_at": job.updated_at,
    }


# ---------------------------------------------------------------------------
# Projects
# ---------------------------------------------------------------------------
@router.get("/projects", tags=["Projects"])
def list_projects(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    status_filter: str | None = Query(default=None, alias="status"),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    statement = select(Project).order_by(Project.created_at.desc())
    if status_filter:
        statement = statement.where(Project.status == status_filter)
    projects = list(db.execute(statement).scalars().all())
    start = (page - 1) * page_size
    page_items = projects[start : start + page_size]
    return {
        "items": [_project_dict(project, db) for project in page_items],
        "projects": [_project_dict(project, db) for project in page_items],
        "total": len(projects),
        "page": page,
        "page_size": page_size,
        "total_pages": (len(projects) + page_size - 1) // page_size,
    }


@router.post("/projects", status_code=status.HTTP_201_CREATED, tags=["Projects"])
def create_project(request: ProjectCreate, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    project = Project(
        id=str(uuid.uuid4()),
        name=request.name.strip(),
        description=request.description,
        status="pending",
        is_demo=request.is_demo,
    )
    db.add(project)
    db.flush()
    return _project_dict(project, db)


@router.post("/projects/demo", status_code=status.HTTP_201_CREATED, tags=["Projects"])
def create_demo_project(db: Session = Depends(get_db_session)) -> dict[str, Any]:
    project = Project(
        id=str(uuid.uuid4()),
        name="DEMO — Local JobEval example",
        description="Clearly labelled demo project. Upload a STEP model and a PDF/DXF drawing to exercise the local workflow.",
        status="pending",
        is_demo=True,
    )
    db.add(project)
    db.flush()
    return _project_dict(project, db)


@router.get("/projects/{project_id}", tags=["Projects"])
def get_project(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    project = _get_project(db, project_id)
    files = session_files(db, project.id)
    analysis = (
        db.execute(select(ProjectAnalysis).where(ProjectAnalysis.project_id == project.id))
        .scalars()
        .first()
    )
    plan = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project.id))
        .scalars()
        .first()
    )
    estimates = (
        db.execute(
            select(CostEstimate)
            .where(CostEstimate.project_id == project.id)
            .order_by(CostEstimate.created_at.desc())
        )
        .scalars()
        .all()
    )
    result = _project_dict(project, db)
    result.update(
        files=[_file_dict(file) for file in files],
        has_analysis=analysis is not None,
        has_manufacturing_plan=plan is not None,
        estimate_count=len(estimates),
    )
    return result


@router.patch("/projects/{project_id}", tags=["Projects"])
def patch_project(
    project_id: str, request: ProjectPatch, db: Session = Depends(get_db_session)
) -> dict[str, Any]:
    project = _get_project(db, project_id)
    values = request.model_dump(exclude_unset=True)
    if "name" in values:
        project.name = values["name"].strip()
    if "description" in values:
        project.description = values["description"]
    if "status" in values and values["status"] is not None:
        project.status = values["status"]
    project.updated_at = _now()
    db.flush()
    return _project_dict(project, db)


@router.delete("/projects/{project_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Projects"])
def delete_project(project_id: str, db: Session = Depends(get_db_session)) -> Response:
    project = _get_project(db, project_id)
    settings = get_settings()
    root = (settings.upload_root / project.id).resolve()
    try:
        if root.exists() and root.is_dir() and root.is_relative_to(settings.upload_root.resolve()):
            import shutil

            shutil.rmtree(root)
    except OSError:
        pass
    db.delete(project)
    db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------
@router.get("/projects/{project_id}/files", tags=["Files"])
def list_files(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    project = _get_project(db, project_id)
    files = session_files(db, project.id)
    return {
        "project_id": project.id,
        "items": [_file_dict(file) for file in files],
        "files": [_file_dict(file) for file in files],
        "total": len(files),
    }


@router.post("/projects/{project_id}/files", status_code=status.HTTP_201_CREATED, tags=["Files"])
async def upload_file(
    project_id: str,
    file: UploadFile = File(...),
    role: str | None = Form(default=None),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    project = _get_project(db, project_id)
    settings = get_settings()
    # Read in bounded chunks so an oversized request cannot be accumulated in
    # memory before validation.
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = await file.read(1024 * 1024)
        if not chunk:
            break
        total += len(chunk)
        if total > settings.max_file_size_bytes:
            raise HTTPException(
                status_code=413,
                detail=f"File exceeds the maximum upload size of {settings.MAX_FILE_SIZE_MB} MB",
            )
        chunks.append(chunk)
    content = b"".join(chunks)
    if not content:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    storage = LocalStorage()
    try:
        stored = storage.save_upload(project.id, file.filename or "upload", io.BytesIO(content))
    except StorageError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    extension = stored.extension
    inferred_role = role
    if inferred_role not in {"model_3d", "drawing_2d", "reference"}:
        inferred_role = (
            "model_3d"
            if extension in {".step", ".stp"}
            else ("drawing_2d" if extension in {".pdf", ".dxf"} else "reference")
        )
    record = ProjectFile(
        id=stored.path.stem,
        project_id=project.id,
        original_filename=stored.original_filename,
        stored_filename=stored.path.name,
        relative_path=stored.relative_path,
        extension=extension,
        mime_type=stored.mime_type,
        size_bytes=stored.size_bytes,
        sha256=stored.sha256,
        role=inferred_role,
        status="uploaded",
    )
    db.add(record)
    db.flush()
    return _file_dict(record)


@router.get("/files/{file_id}", tags=["Files"])
def get_file(file_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    return _file_dict(_get_file(db, file_id))


@router.get("/files/{file_id}/download", tags=["Files"])
def download_file(file_id: str, db: Session = Depends(get_db_session)) -> FileResponse:
    record = _get_file(db, file_id)
    storage = LocalStorage()
    try:
        path = storage.resolve(record.relative_path)
    except StorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if not path.exists() or not path.is_file():
        raise HTTPException(status_code=404, detail="The stored file is no longer available")
    return FileResponse(path, media_type=record.mime_type, filename=record.original_filename)


@router.delete("/files/{file_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Files"])
def delete_file(file_id: str, db: Session = Depends(get_db_session)) -> Response:
    record = _get_file(db, file_id)
    storage = LocalStorage()
    try:
        storage.delete(record.relative_path)
    except StorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    db.delete(record)
    db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------------------------------------------------------------------------
# Analysis and jobs
# ---------------------------------------------------------------------------
@router.post(
    "/projects/{project_id}/analysis", status_code=status.HTTP_202_ACCEPTED, tags=["Analysis"]
)
def start_analysis(
    project_id: str,
    background_tasks: BackgroundTasks,
    request: AnalysisRequest | None = Body(default=None),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    project = _get_project(db, project_id)
    request = request or AnalysisRequest()
    selected: ProjectFile | None = None
    if request.file_id:
        selected = _get_file(db, request.file_id)
        if selected.project_id != project.id:
            raise HTTPException(
                status_code=400, detail="The selected file does not belong to this project"
            )
    else:
        candidates = [
            file
            for file in session_files(db, project.id)
            if file.role == "model_3d" and file.extension in {".step", ".stp"}
        ]
        selected = candidates[0] if candidates else None
    if selected is None:
        raise HTTPException(
            status_code=400, detail="Upload a STEP (.step/.stp) model before starting analysis"
        )
    job = AnalysisJob(
        id=str(uuid.uuid4()),
        project_id=project.id,
        file_id=selected.id,
        kind="cad_analysis",
        status="queued",
        stage="queued",
        progress=0.0,
    )
    db.add(job)
    project.status = "processing"
    db.flush()
    # Commit before the local worker starts; otherwise a separate SQLite
    # connection can observe the job before the request transaction is visible.
    db.commit()
    background_tasks.add_task(run_job_in_background, job.id)
    return {
        "project_id": project.id,
        "job_id": job.id,
        "id": job.id,
        "status": "queued",
        "state": "queued",
        "progress": 0.0,
        "message": "Analysis queued in the local worker",
    }


@router.get("/jobs/{job_id}", tags=["Analysis"])
def get_job(job_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    job = db.get(AnalysisJob, job_id)
    if job is None:
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' was not found")
    return _job_dict(job)


@router.get("/jobs", tags=["Analysis"])
def list_jobs(db: Session = Depends(get_db_session)) -> dict[str, Any]:
    jobs = list(
        db.execute(select(AnalysisJob).order_by(AnalysisJob.created_at.desc())).scalars().all()
    )
    return {
        "items": [_job_dict(job) for job in jobs],
        "jobs": [_job_dict(job) for job in jobs],
        "total": len(jobs),
    }


@router.post("/jobs/{job_id}/cancel", tags=["Analysis"])
def cancel_job(job_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    job = db.get(AnalysisJob, job_id)
    if job is None:
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' was not found")
    if job.status in {"completed", "failed", "cancelled"}:
        return _job_dict(job)
    job.cancel_requested = True
    job.status = "cancelled" if job.status == "queued" else job.status
    job.stage = "cancelled" if job.status == "cancelled" else job.stage
    if job.status == "cancelled":
        job.progress = 0.0
        job.completed_at = _now()
    db.flush()
    return _job_dict(job)


@router.get("/projects/{project_id}/analysis", tags=["Analysis"])
def get_analysis(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    analysis = _get_analysis(db, project_id)
    data = copy.deepcopy(analysis.data)
    data.setdefault("raw_features", data.get("features", []))
    data.setdefault("reviewed_features", {})
    data["project_id"] = project_id
    return data


@router.get("/projects/{project_id}/features", tags=["Analysis"])
def get_features(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    analysis = _get_analysis(db, project_id)
    raw = list(analysis.data.get("raw_features") or analysis.data.get("features") or [])
    reviewed = analysis.data.get("reviewed_features") or {}
    features = []
    for feature in raw:
        feature_id = feature.get("feature_id")
        features.append(
            copy.deepcopy(reviewed.get(feature_id, feature))
            if isinstance(reviewed, dict)
            else copy.deepcopy(feature)
        )
    return {
        "project_id": project_id,
        "items": features,
        "features": features,
        "raw_count": len(raw),
        "reviewed_count": len(reviewed) if isinstance(reviewed, dict) else 0,
        "min_costing_confidence": get_settings().MIN_FEATURE_CONFIDENCE,
    }


@router.patch("/projects/{project_id}/features/{feature_id}", tags=["Analysis"])
def review_feature(
    project_id: str,
    feature_id: str,
    request: FeatureReviewRequest,
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    analysis = _get_analysis(db, project_id)
    raw = list(analysis.data.get("raw_features") or analysis.data.get("features") or [])
    source = next((item for item in raw if item.get("feature_id") == feature_id), None)
    if source is None:
        raise HTTPException(status_code=404, detail=f"Feature '{feature_id}' was not found")
    reviewed = analysis.data.get("reviewed_features")
    if not isinstance(reviewed, dict):
        reviewed = {}
    state = request.review_state or request.status or ("reviewed" if request.reviewed else "raw")
    if state == "raw" or request.action == "restore":
        reviewed.pop(feature_id, None)
        result = copy.deepcopy(source)
    else:
        result = copy.deepcopy(reviewed.get(feature_id, source))
        result["review_state"] = state
        result["reviewed"] = state in {"reviewed", "corrected"}
        if request.feature_type or request.type:
            result["type"] = request.feature_type or request.type
        if request.confidence is not None:
            result["confidence"] = request.confidence
        if request.accessibility is not None:
            result["accessibility"] = request.accessibility
        if request.dimensions is not None:
            result["dimensions"] = request.dimensions
        if request.evidence is not None:
            result["evidence"] = request.evidence
        if request.notes is not None:
            result["notes"] = request.notes
        if request.correction is not None:
            result["correction"] = request.correction
        reviewed[feature_id] = result
    analysis.data["reviewed_features"] = reviewed
    analysis.data["features"] = [
        copy.deepcopy(reviewed.get(item.get("feature_id"), item)) for item in raw
    ]
    analysis.updated_at = _now()
    db.flush()
    return {
        "project_id": project_id,
        "feature": result,
        "raw_unchanged": True,
        "review_state": state,
    }


# ---------------------------------------------------------------------------
# Drawings
# ---------------------------------------------------------------------------
@router.post("/projects/{project_id}/drawings/parse", tags=["Drawings"])
def parse_drawings(
    project_id: str,
    request: DrawingParseRequest | None = Body(default=None),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    project = _get_project(db, project_id)
    request = request or DrawingParseRequest()
    selected = None
    if request.file_id:
        selected = _get_file(db, request.file_id)
        if selected.project_id != project.id:
            raise HTTPException(
                status_code=400, detail="The selected file does not belong to this project"
            )
    else:
        candidates = [
            file for file in session_files(db, project.id) if file.extension in {".pdf", ".dxf"}
        ]
        selected = candidates[0] if candidates else None
    if selected is None:
        raise HTTPException(status_code=400, detail="Upload a PDF or DXF drawing before parsing")
    settings = get_settings()
    path = settings.upload_root / selected.relative_path
    try:
        result = DrawingService().process_drawing(path, project.id)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Drawing parsing failed: {exc}") from exc
    row = (
        db.execute(select(DrawingAnalysis).where(DrawingAnalysis.project_id == project.id))
        .scalars()
        .first()
    )
    if row is None:
        row = DrawingAnalysis(id=str(uuid.uuid4()), project_id=project.id, data={})
        db.add(row)
    row.data = result
    row.updated_at = _now()
    db.flush()
    return {"project_id": project.id, "file_id": selected.id, "analysis": result}


@router.get("/projects/{project_id}/drawings", tags=["Drawings"])
def get_drawings(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    row = (
        db.execute(select(DrawingAnalysis).where(DrawingAnalysis.project_id == project_id))
        .scalars()
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="No drawing analysis exists for this project")
    return {"project_id": project_id, "analysis": row.data, **row.data}


# ---------------------------------------------------------------------------
# Cross-validation
# ---------------------------------------------------------------------------
@router.post("/projects/{project_id}/cross-validation", tags=["Cross-validation"])
def create_cross_validation(
    project_id: str,
    request: CrossValidationRequest | None = Body(default=None),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    project = _get_project(db, project_id)
    analysis = _get_analysis(db, project_id)
    drawing_row = (
        db.execute(select(DrawingAnalysis).where(DrawingAnalysis.project_id == project.id))
        .scalars()
        .first()
    )
    if drawing_row is None:
        raise HTTPException(
            status_code=400, detail="Parse a drawing before running cross-validation"
        )
    request = request or CrossValidationRequest()
    tolerances = dict(request.tolerances)
    if request.dimension_tolerance_mm is not None:
        tolerances["dimension_mm"] = request.dimension_tolerance_mm
    if request.hole_diameter_tolerance_mm is not None:
        tolerances["hole_diameter_mm"] = request.hole_diameter_tolerance_mm
    if request.count_tolerance is not None:
        tolerances["count"] = request.count_tolerance
    result = CrossValidationService(tolerances).validate(drawing_row.data, analysis.data)
    row = (
        db.execute(select(CrossValidation).where(CrossValidation.project_id == project.id))
        .scalars()
        .first()
    )
    if row is None:
        row = CrossValidation(id=str(uuid.uuid4()), project_id=project.id, data={})
        db.add(row)
    row.data = result
    row.updated_at = _now()
    db.flush()
    return {"project_id": project.id, **result}


@router.get("/projects/{project_id}/cross-validation", tags=["Cross-validation"])
def get_cross_validation(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    row = (
        db.execute(select(CrossValidation).where(CrossValidation.project_id == project_id))
        .scalars()
        .first()
    )
    if row is None:
        raise HTTPException(
            status_code=404, detail="No cross-validation report exists for this project"
        )
    return {"project_id": project_id, **row.data}


@router.patch(
    "/projects/{project_id}/cross-validation/discrepancies/{check_id}", tags=["Cross-validation"]
)
def review_discrepancy(
    project_id: str,
    check_id: str,
    request: DiscrepancyReviewRequest,
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    row = (
        db.execute(select(CrossValidation).where(CrossValidation.project_id == project_id))
        .scalars()
        .first()
    )
    if row is None:
        raise HTTPException(
            status_code=404, detail="No cross-validation report exists for this project"
        )
    checks = row.data.get("checks", [])
    check = next((item for item in checks if item.get("id") == check_id), None)
    if check is None:
        raise HTTPException(status_code=404, detail=f"Discrepancy '{check_id}' was not found")
    check["review_state"] = request.review_state
    check["reviewer"] = request.reviewer
    check["note"] = request.note
    row.data["checks"] = checks
    row.updated_at = _now()
    db.flush()
    return {"project_id": project_id, "discrepancy": check}


# ---------------------------------------------------------------------------
# Manufacturing plan
# ---------------------------------------------------------------------------
@router.get("/projects/{project_id}/manufacturing-plan", tags=["Manufacturing"])
def get_manufacturing_plan(
    project_id: str, db: Session = Depends(get_db_session)
) -> dict[str, Any]:
    _get_project(db, project_id)
    row = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project_id))
        .scalars()
        .first()
    )
    if row is None:
        analysis = _get_analysis(db, project_id)
        plan = ManufacturingService().analyze_manufacturability(analysis.data)
        row = ManufacturingPlan(id=str(uuid.uuid4()), project_id=project_id, data=plan)
        db.add(row)
        db.flush()
    return {"project_id": project_id, **row.data}


@router.put("/projects/{project_id}/manufacturing-plan", tags=["Manufacturing"])
def put_manufacturing_plan(
    project_id: str, request: ManufacturingPlanUpdate, db: Session = Depends(get_db_session)
) -> dict[str, Any]:
    _get_project(db, project_id)
    try:
        plan = ManufacturingService().validate_plan(request.model_dump())
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    row = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project_id))
        .scalars()
        .first()
    )
    if row is None:
        row = ManufacturingPlan(id=str(uuid.uuid4()), project_id=project_id, data={})
        db.add(row)
    row.data = plan
    row.updated_at = _now()
    db.flush()
    return {"project_id": project_id, **plan}


@router.patch(
    "/projects/{project_id}/manufacturing-plan/operations/{operation_id}", tags=["Manufacturing"]
)
def patch_manufacturing_operation(
    project_id: str,
    operation_id: str,
    request: dict[str, Any] = Body(...),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    row = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project_id))
        .scalars()
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="No manufacturing plan exists for this project")
    operations = row.data.get("operations", [])
    operation = next(
        (item for item in operations if item.get("operation_id") == operation_id), None
    )
    if operation is None:
        raise HTTPException(status_code=404, detail=f"Operation '{operation_id}' was not found")
    operation.update(request)
    operation["status"] = "edited"
    row.data["status"] = "edited"
    row.updated_at = _now()
    db.flush()
    return {"project_id": project_id, "operation": operation, "plan": row.data}


# ---------------------------------------------------------------------------
# Pricing and estimates
# ---------------------------------------------------------------------------
def _pricing_payload(request: PricingConfigUpdate, current: dict[str, Any]) -> dict[str, Any]:
    values = request.model_dump(exclude_unset=True)
    merged = copy.deepcopy(current)
    merged.update(values)
    if values.get("allowances") is not None:
        merged["allowances"] = values["allowances"]
    return PricingService()._normalise(merged)


@router.get("/projects/{project_id}/pricing", tags=["Pricing"])
def get_project_pricing(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    _get_project(db, project_id)
    service = PricingService(db)
    row = (
        db.execute(select(PricingConfig).where(PricingConfig.project_id == project_id))
        .scalars()
        .first()
    )
    if row is None:
        global_config = service.get_global_config()
        row = PricingConfig(
            id=f"pricing-project-{project_id}",
            scope="project",
            project_id=project_id,
            data=global_config,
        )
        db.add(row)
        db.flush()
    return {"project_id": project_id, **row.data}


@router.put("/projects/{project_id}/pricing", tags=["Pricing"])
def put_project_pricing(
    project_id: str, request: PricingConfigUpdate, db: Session = Depends(get_db_session)
) -> dict[str, Any]:
    _get_project(db, project_id)
    service = PricingService(db)
    current = service.get_project_config(project_id)
    data = _pricing_payload(request, current)
    service.save_project_config(project_id, data)
    db.flush()
    return {"project_id": project_id, **data}


@router.get("/settings/pricing", tags=["Pricing"])
def get_global_pricing(db: Session = Depends(get_db_session)) -> dict[str, Any]:
    service = PricingService(db)
    row = (
        db.execute(
            select(PricingConfig).where(
                PricingConfig.scope == "global", PricingConfig.project_id.is_(None)
            )
        )
        .scalars()
        .first()
    )
    if row is None:
        data = service.get_global_config()
        row = PricingConfig(id="pricing-global", scope="global", project_id=None, data=data)
        db.add(row)
        db.flush()
    return {"scope": "global", **row.data}


@router.put("/settings/pricing", tags=["Pricing"])
def put_global_pricing(
    request: PricingConfigUpdate, db: Session = Depends(get_db_session)
) -> dict[str, Any]:
    service = PricingService(db)
    current = service.get_global_config()
    data = _pricing_payload(request, current)
    service.save_global_config(data)
    db.flush()
    return {"scope": "global", **data}


@router.post(
    "/projects/{project_id}/estimate", status_code=status.HTTP_201_CREATED, tags=["Pricing"]
)
def create_estimate(
    project_id: str,
    request: EstimateRequest | None = Body(default=None),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    _get_project(db, project_id)
    request = request or EstimateRequest()
    analysis_row = (
        db.execute(select(ProjectAnalysis).where(ProjectAnalysis.project_id == project_id))
        .scalars()
        .first()
    )
    if analysis_row is None:
        raise HTTPException(status_code=400, detail="Run CAD analysis before creating an estimate")
    plan_row = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project_id))
        .scalars()
        .first()
    )
    if plan_row is None:
        plan_row = ManufacturingPlan(
            id=str(uuid.uuid4()),
            project_id=project_id,
            data=ManufacturingService().analyze_manufacturability(analysis_row.data),
        )
        db.add(plan_row)
        db.flush()
    pricing_service = PricingService(db)
    config = pricing_service.get_project_config(project_id)
    if request.pricing is not None:
        config = _pricing_payload(request.pricing, config)
    estimate = pricing_service.calculate(config, analysis_row.data, plan_row.data, request.quantity)
    estimate["project_id"] = project_id
    estimate["immutable"] = True
    estimate["note"] = request.note
    snapshot = CostEstimate(
        id=str(uuid.uuid4()), project_id=project_id, data=copy.deepcopy(estimate), immutable=True
    )
    db.add(snapshot)
    db.flush()
    return {
        "project_id": project_id,
        "estimate_id": snapshot.id,
        "snapshot_id": snapshot.id,
        "estimate": estimate,
        **estimate,
    }


@router.get("/projects/{project_id}/estimate", tags=["Pricing"])
def get_estimates(project_id: str, db: Session = Depends(get_db_session)) -> dict[str, Any]:
    _get_project(db, project_id)
    snapshots = (
        db.execute(
            select(CostEstimate)
            .where(CostEstimate.project_id == project_id)
            .order_by(CostEstimate.created_at.desc())
        )
        .scalars()
        .all()
    )
    items = [
        copy.deepcopy(item.data)
        | {"estimate_id": item.id, "snapshot_id": item.id, "created_at": item.created_at}
        for item in snapshots
    ]
    return {
        "project_id": project_id,
        "items": items,
        "estimates": items,
        "latest": items[0] if items else None,
        "total": len(items),
    }


# ---------------------------------------------------------------------------
# Reports and explanation
# ---------------------------------------------------------------------------
@router.get("/projects/{project_id}/reports", tags=["Reports"])
def get_report(
    project_id: str,
    format: str = Query(default="json", pattern="^(json|html|csv)$"),
    db: Session = Depends(get_db_session),
) -> Response:
    project = _get_project(db, project_id)
    analysis = (
        db.execute(select(ProjectAnalysis).where(ProjectAnalysis.project_id == project_id))
        .scalars()
        .first()
    )
    plan = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project_id))
        .scalars()
        .first()
    )
    estimate = (
        db.execute(
            select(CostEstimate)
            .where(CostEstimate.project_id == project_id)
            .order_by(CostEstimate.created_at.desc())
        )
        .scalars()
        .first()
    )
    drawing = (
        db.execute(select(DrawingAnalysis).where(DrawingAnalysis.project_id == project_id))
        .scalars()
        .first()
    )
    validation = (
        db.execute(select(CrossValidation).where(CrossValidation.project_id == project_id))
        .scalars()
        .first()
    )
    report = build_report(
        project,
        analysis.data if analysis else None,
        plan.data if plan else None,
        estimate.data if estimate else None,
        drawing.data if drawing else None,
        validation.data if validation else None,
    )
    record = ReportRecord(id=str(uuid.uuid4()), project_id=project_id, format=format, data=report)
    db.add(record)
    db.flush()
    if format == "html":
        return HTMLResponse(report_html(report))
    if format == "csv":
        return PlainTextResponse(report_csv(report), media_type="text/csv")
    return Response(content=report_json(report), media_type="application/json")


@router.post("/projects/{project_id}/explanation", tags=["Explanation"])
async def explain_project(
    project_id: str,
    request: ExplanationRequest | None = Body(default=None),
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    project = _get_project(db, project_id)
    request = request or ExplanationRequest()
    settings = get_settings()

    # Determine provider: request override > server default
    provider = request.provider or settings.LLM_PROVIDER
    if provider == "disabled":
        raise HTTPException(
            status_code=503,
            detail="LLM explanations are disabled on this server",
        )

    # Select the correct API key based on provider
    if provider == "nvidia_nim":
        api_key = settings.NVIDIA_NIM_API_KEY
        provider_name = "NVIDIA NIM"
    else:
        api_key = settings.OPENROUTER_API_KEY
        provider_name = "OpenRouter"

    if not api_key:
        raise HTTPException(
            status_code=503,
            detail=f"{provider_name} is not configured; set the corresponding API key to enable explanations",
        )

    analysis_row = (
        db.execute(select(ProjectAnalysis).where(ProjectAnalysis.project_id == project_id))
        .scalars()
        .first()
    )
    plan_row = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project_id))
        .scalars()
        .first()
    )
    # Send only a compact, non-CAD summary.  Raw files, mesh, and geometry
    # coordinates are deliberately excluded from the request.
    summary = {
        "project_name": project.name,
        "analysis_available": analysis_row is not None,
        "feature_count": len((analysis_row.data if analysis_row else {}).get("features", [])),
        "operation_count": len((plan_row.data if plan_row else {}).get("operations", [])),
        "warnings": (plan_row.data if plan_row else {}).get("warnings", []),
    }

    system_prompt = (
        "Explain manufacturing implications using only the supplied JSON summary. "
        "Return strict JSON with keys summary, risks, and suggestions. "
        "Never invent dimensions or change calculations."
    )
    user_prompt = json.dumps({"question": request.question, "summary": summary}, sort_keys=True)

    llm = LLMService()
    # Override provider if the request specified one
    if request.provider:
        llm.provider = request.provider
        if request.provider == "nvidia_nim":
            llm.api_key = settings.NVIDIA_NIM_API_KEY
            llm.base_url = settings.NVIDIA_NIM_BASE_URL
            llm.model = settings.NVIDIA_NIM_MODEL
            llm.timeout = settings.NVIDIA_NIM_TIMEOUT
        else:
            llm.api_key = settings.OPENROUTER_API_KEY
            llm.base_url = settings.OPENROUTER_BASE_URL
            llm.model = settings.OPENROUTER_MODEL
            llm.timeout = settings.OPENROUTER_TIMEOUT

    try:
        result = await llm.complete(system_prompt, user_prompt)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"LLM request failed: {exc}") from exc
    finally:
        await llm.close()

    return {
        "project_id": project_id,
        "explanation": result,
        "calculations_unchanged": True,
        "cad_sent": False,
        "provider": provider,
        "provider_name": provider_name,
    }


# ---------------------------------------------------------------------------
# Chat
# ---------------------------------------------------------------------------

@router.post("/projects/{project_id}/chat", tags=["Chat"])
async def chat_message(
    project_id: str,
    request: ChatMessageSend,
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    """Send a chat message and get an AI response."""
    project = _get_project(db, project_id)
    settings = get_settings()

    # Determine provider
    provider = request.provider or settings.LLM_PROVIDER
    if provider == "disabled":
        raise HTTPException(
            status_code=503,
            detail="LLM chat is disabled on this server",
        )

    # Select the correct API key based on provider
    if provider == "nvidia_nim":
        api_key = settings.NVIDIA_NIM_API_KEY
        provider_name = "NVIDIA NIM"
    else:
        api_key = settings.OPENROUTER_API_KEY
        provider_name = "OpenRouter"

    if not api_key:
        raise HTTPException(
            status_code=503,
            detail=f"{provider_name} is not configured; set the corresponding API key to enable chat",
        )

    # Save user message
    user_msg_id = str(uuid.uuid4())
    user_msg = ChatMessage(
        id=user_msg_id,
        project_id=project_id,
        role="user",
        content=request.message,
        provider=provider,
        model=settings.NVIDIA_NIM_MODEL if provider == "nvidia_nim" else settings.OPENROUTER_MODEL,
    )
    db.add(user_msg)
    db.flush()

    # Build context summary from project data
    analysis_row = (
        db.execute(select(ProjectAnalysis).where(ProjectAnalysis.project_id == project_id))
        .scalars()
        .first()
    )
    plan_row = (
        db.execute(select(ManufacturingPlan).where(ManufacturingPlan.project_id == project_id))
        .scalars()
        .first()
    )
    estimate_row = (
        db.execute(select(CostEstimate).where(CostEstimate.project_id == project_id))
        .scalars()
        .first()
    )

    summary = {
        "project_name": project.name,
        "analysis_available": analysis_row is not None,
        "feature_count": len((analysis_row.data if analysis_row else {}).get("features", [])),
        "operation_count": len((plan_row.data if plan_row else {}).get("operations", [])),
        "estimate_available": estimate_row is not None,
        "estimate_total": (estimate_row.data if estimate_row else {}).get("total"),
        "warnings": (plan_row.data if plan_row else {}).get("warnings", []),
    }

    system_prompt = (
        "You are JobEval, a manufacturing cost estimation assistant. "
        "Answer questions about CAD analysis, manufacturing plans, and cost estimates "
        "based only on the provided project data. "
        "Never invent dimensions, prices, or times. "
        "If information is not available, say so clearly."
    )
    user_prompt = json.dumps(
        {"question": request.message, "project_summary": summary}, sort_keys=True
    )

    llm = LLMService()
    if provider == "nvidia_nim":
        llm.provider = provider
        llm.api_key = settings.NVIDIA_NIM_API_KEY
        llm.base_url = settings.NVIDIA_NIM_BASE_URL
        llm.model = settings.NVIDIA_NIM_MODEL
        llm.timeout = settings.NVIDIA_NIM_TIMEOUT
    else:
        llm.provider = provider
        llm.api_key = settings.OPENROUTER_API_KEY
        llm.base_url = settings.OPENROUTER_BASE_URL
        llm.model = settings.OPENROUTER_MODEL
        llm.timeout = settings.OPENROUTER_TIMEOUT

    try:
        result = await llm.complete(system_prompt, user_prompt)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"LLM request failed: {exc}") from exc
    finally:
        await llm.close()

    # Save assistant response
    assistant_msg_id = str(uuid.uuid4())
    assistant_content = result.get("summary", str(result))
    assistant_msg = ChatMessage(
        id=assistant_msg_id,
        project_id=project_id,
        role="assistant",
        content=assistant_content,
        provider=provider,
        model=llm.model,
    )
    db.add(assistant_msg)
    db.flush()

    return {
        "message_id": assistant_msg_id,
        "role": "assistant",
        "content": assistant_content,
        "provider": provider,
        "model": llm.model,
        "created_at": assistant_msg.created_at.isoformat(),
        "calculations_unchanged": True,
    }


@router.get("/projects/{project_id}/chat", tags=["Chat"])
async def chat_history(
    project_id: str,
    db: Session = Depends(get_db_session),
) -> dict[str, Any]:
    """Get chat history for a project."""
    _get_project(db, project_id)
    messages = (
        db.execute(
            select(ChatMessage)
            .where(ChatMessage.project_id == project_id)
            .order_by(ChatMessage.created_at.asc())
        )
        .scalars()
        .all()
    )
    items = [
        {
            "message_id": m.id,
            "role": m.role,
            "content": m.content,
            "provider": m.provider,
            "model": m.model,
            "created_at": m.created_at.isoformat(),
        }
        for m in messages
    ]
    return {"messages": items, "total": len(items)}


# ---------------------------------------------------------------------------
# File Viewing
# ---------------------------------------------------------------------------

@router.get("/projects/{project_id}/files/{file_id}/view", tags=["Files"])
async def view_file(
    project_id: str,
    file_id: str,
    db: Session = Depends(get_db_session),
) -> Response:
    """View a project file (CAD, PDF, or image) in the browser."""
    record = _get_file(db, file_id)
    if record.project_id != project_id:
        raise HTTPException(status_code=403, detail="File does not belong to this project")

    settings = get_settings()
    storage = LocalStorage()
    try:
        path = storage.resolve(record.relative_path)
    except StorageError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    if not path.exists() or not path.is_file():
        raise HTTPException(status_code=404, detail="The stored file is no longer available")

    # Determine media type
    ext = record.extension.lower()
    media_type = record.mime_type
    if ext == ".step" or ext == ".stp":
        media_type = "application/step"
    elif ext == ".pdf":
        media_type = "application/pdf"
    elif ext == ".dxf":
        media_type = "image/vnd.dxf"
    elif ext == ".png":
        media_type = "image/png"
    elif ext in {".jpg", ".jpeg"}:
        media_type = "image/jpeg"

    return FileResponse(path, media_type=media_type, filename=record.original_filename)


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
@router.get("/dashboard", tags=["Dashboard"])
def dashboard(db: Session = Depends(get_db_session)) -> dict[str, Any]:
    projects = list(db.execute(select(Project).order_by(Project.updated_at.desc())).scalars().all())
    jobs = list(db.execute(select(AnalysisJob)).scalars().all())
    counts = {
        "projects": len(projects),
        "files": db.query(ProjectFile).count(),
        "jobs": len(jobs),
        "queued": sum(job.status == "queued" for job in jobs),
        "running": sum(job.status == "running" for job in jobs),
        "completed": sum(job.status == "completed" for job in jobs),
    }
    return {
        "counts": counts,
        "projects": [_project_dict(project, db) for project in projects],
        "recent_jobs": [
            _job_dict(job)
            for job in sorted(jobs, key=lambda item: item.created_at, reverse=True)[:10]
        ],
    }
