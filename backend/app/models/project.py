"""Project-related SQLAlchemy models."""

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Enum, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ProjectStatus(str, enum.Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    ARCHIVED = "archived"


class FileRole(str, enum.Enum):
    MODEL_3D = "model_3d"
    DRAWING_2D = "drawing_2d"
    REFERENCE = "reference"


class FileStatus(str, enum.Enum):
    UPLOADED = "uploaded"
    PROCESSING = "processing"
    PROCESSED = "processed"
    FAILED = "failed"


class Project(Base):
    """Project model."""

    __tablename__ = "projects"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ProjectStatus] = mapped_column(
        Enum(ProjectStatus, name="project_status", create_constraint=True),
        nullable=False,
        default=ProjectStatus.PENDING,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    files: Mapped[list["ProjectFile"]] = relationship(
        "ProjectFile",
        back_populates="project",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    job_status: Mapped["JobStatus | None"] = relationship(
        "JobStatus",
        back_populates="project",
        uselist=False,
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    cad_specs: Mapped["CADSpecs | None"] = relationship(
        "CADSpecs",
        back_populates="project",
        uselist=False,
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    manufacturing_analysis: Mapped["ManufacturingAnalysis | None"] = relationship(
        "ManufacturingAnalysis",
        back_populates="project",
        uselist=False,
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    cost_estimates: Mapped[list["CostEstimate"]] = relationship(
        "CostEstimate",
        back_populates="project",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    reports: Mapped[list["Report"]] = relationship(
        "Report",
        back_populates="project",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    __table_args__ = (
        Index("idx_projects_status", "status"),
        Index("idx_projects_created_at", "created_at"),
    )


class ProjectFile(Base):
    """Project file model."""

    __tablename__ = "project_files"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    project_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(100), nullable=False)
    size_bytes: Mapped[int] = mapped_column(nullable=False)
    role: Mapped[FileRole] = mapped_column(
        Enum(FileRole, name="file_role", create_constraint=True),
        nullable=False,
    )
    status: Mapped[FileStatus] = mapped_column(
        Enum(FileStatus, name="file_status", create_constraint=True),
        nullable=False,
        default=FileStatus.UPLOADED,
    )
    sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    processed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    project: Mapped[Project] = relationship("Project", back_populates="files")

    __table_args__ = (
        Index("idx_project_files_project_id", "project_id"),
        Index("idx_project_files_status", "status"),
    )


class JobStage(str, enum.Enum):
    QUEUED = "queued"
    IMPORTING = "importing"
    ANALYZING = "analyzing"
    RECOGNIZING = "recognizing"
    DRAWING = "drawing"
    MANUFACTURING = "manufacturing"
    ESTIMATING = "estimating"
    REPORTING = "reporting"
    COMPLETED = "completed"
    FAILED = "failed"


class JobStatus(Base):
    """Job processing status model."""

    __tablename__ = "job_status"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    project_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    stage: Mapped[JobStage] = mapped_column(
        Enum(JobStage, name="job_stage", create_constraint=True),
        nullable=False,
        default=JobStage.QUEUED,
    )
    progress: Mapped[float] = mapped_column(nullable=False, default=0.0)
    current_step: Mapped[str | None] = mapped_column(String(255), nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # Relationships
    project: Mapped[Project] = relationship("Project", back_populates="job_status")

    __table_args__ = (
        Index("idx_job_status_project_id", "project_id"),
        Index("idx_job_status_stage", "stage"),
    )
