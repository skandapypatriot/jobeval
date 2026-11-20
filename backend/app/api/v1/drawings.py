"""Drawing analysis API endpoints."""

from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.services.drawing_service import DrawingService
from app.services.cross_validation_service import CrossValidationService

router = APIRouter()


@router.post("/process", status_code=status.HTTP_202_ACCEPTED)
async def process_drawing(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    project_name: str | None = None,
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Upload and process an engineering drawing (PDF, DXF)."""
    allowed_extensions = {".pdf", ".dxf"}
    file_ext = Path(file.filename or "").suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file format: {file_ext}",
        )

    project_id = uuid.uuid4()
    project_name = project_name or file.filename or "Untitled Drawing"

    # Save uploaded file
    upload_dir = Path("/app/uploads")
    upload_dir.mkdir(parents=True, exist_ok=True)
    file_path = upload_dir / f"{project_id}{file_ext}"

    content = await file.read()
    file_path.write_bytes(content)

    # Process drawing synchronously (usually fast for PDFs)
    try:
        drawing_service = DrawingService()
        annotations = drawing_service.process_drawing(file_path, str(project_id))

        return {
            "project_id": str(project_id),
            "status": "completed",
            "pages": annotations.total_pages,
            "dimensions_found": sum(len(p.dimensions) for p in annotations.pages),
            "gd_t_found": sum(len(p.gd_t) for p in annotations.pages),
            "surface_finish_found": sum(len(p.surface_finish) for p in annotations.pages),
            "notes_found": sum(len(p.notes) for p in annotations.pages),
            "title_block": annotations.pages[0].title_block.model_dump() if annotations.pages and annotations.pages[0].title_block else None,
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Drawing processing failed: {str(e)}",
        )


@router.get("/extract/{project_id}")
async def extract_annotations(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Get extracted drawing annotations for a project."""
    # TODO: Load from database
    return {
        "project_id": project_id,
        "annotations": {},
        "message": "Drawing annotation retrieval from database not yet implemented",
    }


@router.post("/compare")
async def compare_model_drawing(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """Compare 3D model with 2D drawing annotations."""
    # TODO: Load both CAD specs and drawing annotations from database
    cv_service = CrossValidationService()
    return {
        "project_id": project_id,
        "checks": [],
        "summary": {
            "matches": 0,
            "mismatches": 0,
            "drawing_only": 0,
            "model_only": 0,
        },
        "message": "Cross-validation requires both model and drawing data in database",
    }