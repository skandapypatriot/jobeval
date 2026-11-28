"""Job management endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.schemas.cad_specs import CreateProjectRequest, ProjectDetail, ProjectSummary

router = APIRouter(prefix="/projects", tags=["Jobs"])


@router.post("", response_model=ProjectDetail, status_code=status.HTTP_201_CREATED)
async def create_project(
    request: CreateProjectRequest,
    db: AsyncSession = Depends(get_db_session),
):
    """Create a new project."""
    # TODO: Implement project creation
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("", response_model=list[ProjectSummary])
async def list_projects(
    page: int = 1,
    page_size: int = 20,
    status: str | None = None,
    db: AsyncSession = Depends(get_db_session),
):
    """List projects with pagination."""
    # TODO: Implement project listing
    return []


@router.get("/{project_id}", response_model=ProjectDetail)
async def get_project(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
):
    """Get project details."""
    # TODO: Implement project retrieval
    raise HTTPException(status_code=404, detail="Project not found")


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_project(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
):
    """Delete a project."""
    # TODO: Implement project deletion
    raise HTTPException(status_code=501, detail="Not implemented")


@router.get("/{project_id}/status")
async def get_job_status(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
):
    """Get job processing status."""
    # TODO: Implement status retrieval
    raise HTTPException(status_code=404, detail="Job not found")


@router.get("/{project_id}/results")
async def get_job_results(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
):
    """Get job results (cad_specs.json)."""
    # TODO: Implement results retrieval
    raise HTTPException(status_code=404, detail="Results not found")
