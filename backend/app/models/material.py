"""Material-related SQLAlchemy models."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Material(Base):
    """Material model."""

    __tablename__ = "materials"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    grade: Mapped[str | None] = mapped_column(String(50), nullable=True)
    standard: Mapped[str | None] = mapped_column(String(50), nullable=True)
    category: Mapped[str] = mapped_column(String(50), nullable=False)
    density_kg_m3: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    properties: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    is_active: Mapped[bool] = mapped_column(nullable=False, default=True)
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
    pricing: Mapped[list["MaterialPricing"]] = relationship(
        "MaterialPricing",
        back_populates="material",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    __table_args__ = (
        Index("idx_materials_category", "category"),
        Index("idx_materials_name", "name"),
    )


class MaterialPricing(Base):
    """Material pricing model."""

    __tablename__ = "material_pricing"

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    material_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("materials.id", ondelete="CASCADE"),
        nullable=False,
    )
    region: Mapped[str] = mapped_column(String(100), nullable=False)
    supplier: Mapped[str | None] = mapped_column(String(255), nullable=True)
    stock_dimensions: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    stock_weight_kg: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    price_per_kg: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    price_total: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="USD")
    availability: Mapped[str] = mapped_column(String(50), nullable=False, default="unknown")
    lead_time_days: Mapped[int | None] = mapped_column(nullable=True)
    last_updated: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_verified: Mapped[bool] = mapped_column(nullable=False, default=False)
    notes: Mapped[list] = mapped_column(JSONB, nullable=False, default=list)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    # Relationships
    material: Mapped[Material] = relationship("Material", back_populates="pricing")

    __table_args__ = (
        Index("idx_material_pricing_material_id", "material_id"),
        Index("idx_material_pricing_region", "region"),
    )