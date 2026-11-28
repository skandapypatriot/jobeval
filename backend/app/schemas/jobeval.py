"""Pydantic v2 contracts used by the local JobEval API."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class APIModel(BaseModel):
    model_config = ConfigDict(extra="allow", populate_by_name=True)


class ProjectCreate(APIModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=10000)
    is_demo: bool = False


class ProjectPatch(APIModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=10000)
    status: Literal["pending", "processing", "completed", "failed", "archived"] | None = None


class AnalysisRequest(APIModel):
    file_id: str | None = None
    wait: bool = False


class FeatureReviewRequest(APIModel):
    """Review/correction fields.

    ``raw`` is never changed by this request.  A corrected feature is stored as
    a separate reviewed projection keyed by the original stable feature ID.
    """

    review_state: Literal["raw", "reviewed", "corrected", "rejected", "needs_review"] | None = None
    status: Literal["raw", "reviewed", "corrected", "rejected", "needs_review"] | None = None
    action: Literal["review", "correct", "reject", "restore"] | None = None
    reviewed: bool | None = None
    feature_type: str | None = None
    type: str | None = None
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)
    accessibility: dict[str, Any] | None = None
    dimensions: dict[str, Any] | None = None
    evidence: dict[str, Any] | list[Any] | None = None
    notes: str | None = None
    correction: dict[str, Any] | None = None

    @model_validator(mode="after")
    def normalize_review_state(self) -> FeatureReviewRequest:
        if self.review_state is None and self.status is not None:
            object.__setattr__(self, "review_state", self.status)
        if self.review_state is None and self.action is not None:
            object.__setattr__(
                self,
                "review_state",
                {
                    "review": "reviewed",
                    "correct": "corrected",
                    "reject": "rejected",
                    "restore": "raw",
                }.get(self.action, "needs_review"),
            )
        if self.reviewed is True and self.review_state in (None, "raw"):
            object.__setattr__(self, "review_state", "reviewed")
        return self


class DrawingParseRequest(APIModel):
    file_id: str | None = None


class CrossValidationRequest(APIModel):
    tolerances: dict[str, float] = Field(default_factory=dict)
    dimension_tolerance_mm: float | None = Field(default=None, ge=0.0)
    hole_diameter_tolerance_mm: float | None = Field(default=None, ge=0.0)
    count_tolerance: int | None = Field(default=None, ge=0)


class DiscrepancyReviewRequest(APIModel):
    review_state: Literal["unreviewed", "reviewed", "accepted", "rejected", "needs_review"] = (
        "reviewed"
    )
    reviewer: str | None = Field(default=None, max_length=255)
    note: str | None = Field(default=None, max_length=5000)


class PlanOperation(APIModel):
    operation_id: str = Field(default="", max_length=100)
    feature_ids: list[str] = Field(default_factory=list)
    operation_type: str = Field(min_length=1, max_length=100)
    setup_id: str | None = None
    estimated_time_min: float = Field(default=0.0, ge=0.0)
    status: Literal["suggested", "confirmed", "edited", "rejected"] = "suggested"
    machine: str = "generic_3axis"
    tool: str | None = None
    rate: float | None = Field(default=None, ge=0.0)
    fixed_cost: float | None = Field(default=None, ge=0.0)
    assumptions: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


class ManufacturingPlanUpdate(APIModel):
    machine: str = Field(default="generic_3axis", max_length=100)
    machine_axis_count: int = Field(default=3, ge=1, le=5)
    status: Literal["suggested", "confirmed", "edited"] = "suggested"
    setups: list[dict[str, Any]] = Field(default_factory=list)
    operations: list[PlanOperation] = Field(default_factory=list)
    assumptions: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    notes: str | None = None


class Allowance(APIModel):
    """Per-side allowance in millimetres.

    A value of zero is valid.  The JSON representation also accepts a plain
    mapping such as ``{"x": 0, "y": 2, "z": 2}`` through the pricing
    normalisation service.
    """

    x: float = Field(default=2.0, ge=0.0)
    y: float = Field(default=2.0, ge=0.0)
    z: float = Field(default=2.0, ge=0.0)

    @property
    def total(self) -> dict[str, float]:
        return {"x": self.x * 2.0, "y": self.y * 2.0, "z": self.z * 2.0}


class PricingConfigUpdate(APIModel):
    material: str = Field(default="aluminum_6061", min_length=1, max_length=255)
    density_kg_m3: float | None = Field(default=None, gt=0.0)
    price: float | None = Field(default=None, ge=0.0)
    price_per_kg: float | None = Field(default=None, ge=0.0)
    price_basis: Literal["kg", "piece", "volume_cm3", "volume_m3", "sheet"] = "kg"
    currency: str = Field(default="USD", min_length=3, max_length=3)
    stock_shape: Literal["rectangular", "round"] = "rectangular"
    stock_dimensions: dict[str, float] | None = None
    stock_diameter_mm: float | None = Field(default=None, gt=0.0)
    stock_thickness_mm: float | None = Field(default=None, gt=0.0)
    selected_blank: dict[str, Any] | None = None
    allowance_mm: float | None = Field(default=None, ge=0.0)
    allowance_per_side_mm: float | None = Field(default=None, ge=0.0)
    allowances: dict[str, float] | Allowance | None = None
    finished_bbox: dict[str, Any] | None = None
    quantity: int = Field(default=1, ge=1)
    minimum_quantity: int = Field(default=1, ge=1)
    overhead_percent: float = Field(default=0.0, ge=0.0)
    margin_percent: float = Field(default=0.0, ge=0.0)
    contingency_percent: float = Field(default=0.0, ge=0.0)
    tax_percent: float = Field(default=0.0, ge=0.0)
    rates: dict[str, float | None] = Field(default_factory=dict)
    operation_rates: dict[str, float | None] = Field(default_factory=dict)
    fixed_overrides: dict[str, float | None] = Field(default_factory=dict)
    overrides: dict[str, float | None] = Field(default_factory=dict)
    notes: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def normalize_allowance(self) -> PricingConfigUpdate:
        if self.allowance_per_side_mm is None and self.allowance_mm is not None:
            object.__setattr__(self, "allowance_per_side_mm", self.allowance_mm)
        if self.allowances is None:
            value = self.allowance_per_side_mm if self.allowance_per_side_mm is not None else 2.0
            object.__setattr__(self, "allowances", {"x": value, "y": value, "z": value})
        elif isinstance(self.allowances, Allowance):
            object.__setattr__(self, "allowances", self.allowances.model_dump())
        else:
            for axis in ("x", "y", "z"):
                self.allowances.setdefault(
                    axis,
                    self.allowance_per_side_mm if self.allowance_per_side_mm is not None else 2.0,
                )
                if self.allowances[axis] < 0:
                    raise ValueError("stock allowances cannot be negative")
        return self


class EstimateRequest(APIModel):
    quantity: int | None = Field(default=None, ge=1)
    pricing: PricingConfigUpdate | None = None
    note: str | None = None


class ExplanationRequest(APIModel):
    question: str = Field(
        default="Explain the manufacturing implications of this analysis.", max_length=4000
    )
    format: Literal["structured", "text"] = "structured"
    provider: Literal["openrouter", "nvidia_nim"] | None = Field(
        default=None,
        description="LLM provider to use. Defaults to server LLM_PROVIDER setting.",
    )


class HealthResponse(APIModel):
    status: str
    version: str
    service: str = "jobeval-backend"
    database: str = "ok"
    storage: str = "ok"


class ErrorResponse(APIModel):
    error: str
    detail: str | None = None
    request_id: str | None = None


# ---------------------------------------------------------------------------
# Chat schemas
# ---------------------------------------------------------------------------

class ChatMessageSend(APIModel):
    message: str = Field(min_length=1, max_length=4000)
    project_id: str | None = Field(default=None, description="Project ID for context")
    provider: Literal["openrouter", "nvidia_nim"] | None = Field(
        default=None,
        description="LLM provider to use. Defaults to server LLM_PROVIDER setting.",
    )


class ChatMessageResponse(APIModel):
    message_id: str
    role: str = "assistant"
    content: str
    provider: str | None = None
    model: str | None = None
    created_at: str
    calculations_unchanged: bool = True


class ChatHistoryResponse(APIModel):
    messages: list[dict[str, Any]]
    total: int
