"""CAD processing API endpoints."""

import uuid
from pathlib import Path
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session

router = APIRouter()


@router.post("/process", status_code=status.HTTP_202_ACCEPTED)
async def process_cad_file(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    project_name: str | None = None,
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Upload and process a CAD file (STEP, IGES, STL, BREP)."""
    # Validate file extension
    allowed_extensions = {".step", ".stp", ".iges", ".igs", ".stl", ".brep"}
    file_ext = Path(file.filename or "").suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file format: {file_ext}",
        )

    # Create project
    project_id = uuid.uuid4()
    project_name = project_name or file.filename or "Untitled Project"

    # Save uploaded file
    upload_dir = Path("/app/uploads")
    upload_dir.mkdir(parents=True, exist_ok=True)
    file_path = upload_dir / f"{project_id}{file_ext}"

    content = await file.read()
    file_path.write_bytes(content)

    # Queue CAD processing task
    from app.workers.cad_tasks import process_cad_file

    background_tasks.add_task(process_cad_file, str(file_path), str(project_id))

    return {
        "project_id": str(project_id),
        "status": "queued",
        "message": "CAD file uploaded and queued for processing",
    }


@router.get("/features/{project_id}")
async def get_features(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Get recognized features for a project."""
    # TODO: Load CAD specs from database
    return {
        "project_id": project_id,
        "features": [],
        "message": "Feature retrieval from database not yet implemented",
    }


@router.get("/views/{project_id}")
async def get_views(
    project_id: str,
) -> dict[str, Any]:
    """Get generated orthographic/isometric views for a project."""
    # TODO: Generate and return view URLs
    return {
        "project_id": project_id,
        "views": [],
        "message": "View generation not yet implemented",
    }


@router.post("/export")
async def export_cad(
    project_id: str,
    format: str = "json",
) -> dict[str, Any]:
    """Export CAD data in specified format."""
    # TODO: Implement export
    return {
        "project_id": project_id,
        "format": format,
        "download_url": None,
        "message": "Export not yet implemented",
    }
