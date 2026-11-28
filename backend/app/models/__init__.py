"""JobEval persistence models."""

from app.models.jobeval import (
    AnalysisJob,
    ChatMessage,
    CostEstimate,
    CostEstimateSnapshot,
    CrossValidation,
    DrawingAnalysis,
    JobStatus,
    ManufacturingAnalysis,
    ManufacturingPlan,
    PricingConfig,
    Project,
    ProjectAnalysis,
    ProjectFile,
    ReportRecord,
)

__all__ = [
    "AnalysisJob",
    "CADSpecs",
    "ChatMessage",
    "CostEstimate",
    "CostEstimateSnapshot",
    "CrossValidation",
    "DrawingAnalysis",
    "JobStatus",
    "ManufacturingAnalysis",
    "ManufacturingPlan",
    "PricingConfig",
    "Project",
    "ProjectAnalysis",
    "ProjectFile",
    "ReportRecord",
]

# Keep the old public name available without importing the PostgreSQL-specific
# scaffold models.
CADSpecs = ProjectAnalysis
