"""CAD Specifications Schema — Core data models for cad_specs.json v1.0"""

from datetime import datetime
from enum import Enum
from typing import Any, Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator


class UnitSystem(str, Enum):
    """Supported unit systems."""

    MM = "mm"
    CM = "cm"
    M = "m"
    INCH = "inch"
    FOOT = "foot"


class FileRole(str, Enum):
    """Role of a source file."""

    MODEL_3D = "model_3d"
    DRAWING_2D = "drawing_2d"
    REFERENCE = "reference"


class FileFormat(str, Enum):
    """Supported file formats."""

    STEP = "STEP"
    IGES = "IGES"
    STL = "STL"
    BREP = "BREP"
    DXF = "DXF"
    DWG = "DWG"
    PDF = "PDF"
    SVG = "SVG"
    PNG = "PNG"
    JPEG = "JPEG"


class FeatureType(str, Enum):
    """Manufacturing feature types."""

    THROUGH_HOLE = "through_hole"
    BLIND_HOLE = "blind_hole"
    COUNTERBORE = "counterbore"
    COUNTERSINK = "countersink"
    TAPPED_HOLE_CANDIDATE = "tapped_hole_candidate"
    REAMED_HOLE_CANDIDATE = "reamed_hole_candidate"
    CYLINDRICAL_BORE = "cylindrical_bore"
    OPEN_SLOT = "open_slot"
    CLOSED_SLOT = "closed_slot"
    T_SLOT = "t_slot"
    DOVETAIL_SLOT = "dovetail_slot"
    POCKET_RECTANGULAR = "rectangular_pocket"
    POCKET_CIRCULAR = "circular_pocket"
    POCKET_COMPLEX = "complex_pocket"
    STEP = "step"
    SHOULDER = "shoulder"
    EXTERNAL_PROFILE = "external_profile"
    INTERNAL_PROFILE = "internal_profile"
    FLAT_FACE = "flat_face"
    PLANAR_FACE = "planar_face"
    INCLINED_FACE = "inclined_face"
    ANGLED_WALL = "angled_wall"
    CHAMFER = "chamfer"
    FILLET = "fillet"
    ROUNDED_CORNER = "rounded_corner"
    GROOVE = "groove"
    RECESS = "recess"
    BOSS = "boss"
    RIB = "rib"
    THIN_WALL = "thin_wall"
    TAPERED_SURFACE = "tapered_surface"
    CURVED_SURFACE = "curved_surface"
    UNDERCUT_CANDIDATE = "undercut_candidate"
    THREAD_GEOMETRY = "thread_geometry"
    UNKNOWN_FEATURE = "unknown_feature"
    CANDIDATE_FEATURE = "candidate_feature"


class DetectionMethod(str, Enum):
    """How a feature was detected."""

    CYLINDRICAL_FACE_PAIR = "cylindrical_face_pair_with_planar_caps"
    CONICAL_FACE_ANALYSIS = "conical_face_analysis"
    PARALLEL_FACE_PAIR = "parallel_face_pair_with_end_conditions"
    CLOSED_LOOP_PLANAR_BOTTOM = "closed_loop_with_planar_bottom"
    FACE_ADJACENCY_HEIGHT_DELTA = "face_adjacency_height_delta"
    TOROIDAL_FACE_BETWEEN_PLANES = "toroidal_face_between_planes"
    CONICAL_FACE_BETWEEN_PLANES = "conical_face_between_planes"
    PROTRUDING_VOLUME_ANALYSIS = "protruding_volume_analysis"
    PATTERN_RECOGNITION = "pattern_recognition"
    SYMMETRY_ANALYSIS = "symmetry_analysis"
    MANUAL_ANNOTATION = "manual_annotation"
    DRAWING_ASSOCIATION = "drawing_association"


class DepthType(str, Enum):
    """Hole/feature depth type."""

    THROUGH = "through"
    BLIND = "blind"
    UNKNOWN = "unknown"


class AccessibilityRating(str, Enum):
    """Tool accessibility rating."""

    GOOD = "good"
    LIMITED = "limited"
    DIFFICULT = "difficult"
    INACCESSIBLE = "inaccessible"


class RelationshipType(str, Enum):
    """Feature relationship types."""

    CONTAINMENT = "containment"
    PATTERN = "pattern"
    SHARED_AXIS = "shared_axis"
    SAME_PLANE = "same_plane"
    INTERSECTION = "intersection"
    SETUP_DEPENDENCY = "setup_dependency"
    SYMMETRY = "symmetry"


class DimensionType(str, Enum):
    """Drawing dimension types."""

    LINEAR = "linear"
    ANGULAR = "angular"
    DIAMETER = "diameter"
    RADIUS = "radius"
    DEPTH = "depth"
    THREAD = "thread"
    CHAMFER_DIM = "chamfer"
    FILLET_RADIUS = "fillet_radius"


class ToleranceType(str, Enum):
    """Tolerance types."""

    BILATERAL = "bilateral"
    UNILATERAL = "unilateral"
    LIMIT = "limit"
    GEOMETRIC = "geometric"


class GDTSymbol(str, Enum):
    """GD&T symbol types."""

    FLATNESS = "flatness"
    STRAIGHTNESS = "straightness"
    CIRCULARITY = "circularity"
    CYLINDRICITY = "cylindricity"
    PROFILE_LINE = "profile_line"
    PROFILE_SURFACE = "profile_surface"
    PARALLELISM = "parallelism"
    PERPENDICULARITY = "perpendicularity"
    ANGULARITY = "angularity"
    POSITION = "position"
    CONCENTRICITY = "concentricity"
    SYMMETRY = "symmetry"
    CIRCULAR_RUNOUT = "circular_runout"
    TOTAL_RUNOUT = "total_runout"


class ValidationStatus(str, Enum):
    """Cross-validation status."""

    MATCH = "match"
    MISMATCH = "mismatch"
    DRAWING_ONLY = "drawing_only"
    MODEL_ONLY = "model_only"
    WITHIN_TOLERANCE = "within_tolerance"


class ConfidenceLevel(str, Enum):
    """Confidence level categories."""

    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    UNKNOWN = "unknown"


class OperationType(str, Enum):
    """CNC operation types."""

    FACE_MILLING = "face_milling"
    POCKET_MILLING = "pocket_milling"
    SLOT_MILLING = "slot_milling"
    PROFILE_MILLING = "profile_milling"
    DRILLING = "drilling"
    REAMING = "reaming"
    TAPPING = "tapping"
    BORING = "boring"
    COUNTERBORING = "counterboring"
    COUNTERSINKING = "countersinking"
    CHAMFERING = "chamfering"
    ENGRAVING = "engraving"
    DEBURRING = "deburring"
    INSPECTION = "inspection"


class ToolCategory(str, Enum):
    """Tool categories."""

    END_MILL = "end_mill"
    BALL_END_MILL = "ball_end_mill"
    FACE_MILL = "face_mill"
    DRILL = "drill"
    REAMER = "reamer"
    TAP = "tap"
    BORING_BAR = "boring_bar"
    COUNTERBORE_TOOL = "counterbore_tool"
    COUNTERSINK_TOOL = "countersink_tool"
    CHAMFER_TOOL = "chamfer_tool"
    THREAD_MILL = "thread_mill"
    SLOT_DRILL = "slot_drill"
    T_SLOT_CUTTER = "t_slot_cutter"
    DOVETAIL_CUTTER = "dovetail_cutter"


# =============================================================================
# Base Models
# =============================================================================


class Vector3D(BaseModel):
    """3D vector."""

    x: float
    y: float
    z: float


class BoundingBox3D(BaseModel):
    """3D bounding box."""

    min: Vector3D
    max: Vector3D


class Plane3D(BaseModel):
    """3D plane definition."""

    origin: Vector3D
    normal: Vector3D


class SourceFile(BaseModel):
    """Source file metadata."""

    role: FileRole
    path: str
    format: FileFormat
    size_bytes: int
    sha256: str
    pages: int | None = None


class UnitsInfo(BaseModel):
    """Units information."""

    source: UnitSystem
    normalized: UnitSystem
    confidence: float = Field(ge=0.0, le=1.0, default=1.0)
    conversion_factor: float = 1.0


# =============================================================================
# Geometry Summary
# =============================================================================


class GeometrySummary(BaseModel):
    """Overall geometry summary."""

    num_bodies: int = Field(ge=0)
    num_shells: int = Field(ge=0)
    num_faces: int = Field(ge=0)
    num_edges: int = Field(ge=0)
    num_vertices: int = Field(ge=0)
    volume: float = Field(ge=0.0)
    surface_area: float = Field(ge=0.0)
    bbox: BoundingBox3D
    center_of_mass: Vector3D
    principal_axes: list[Vector3D] = Field(min_length=3, max_length=3)
    symmetry: dict[str, Any] = Field(default_factory=dict)


class SolidBody(BaseModel):
    """Solid body information."""

    body_id: str
    volume: float
    surface_area: float
    bbox: BoundingBox3D
    center_of_mass: Vector3D
    num_faces: int
    num_edges: int
    num_vertices: int
    is_valid: bool
    validation_errors: list[str] = Field(default_factory=list)


# =============================================================================
# Features
# =============================================================================


class FeatureDimensions(BaseModel):
    """Feature dimensions (all optional, only populated when known)."""

    diameter: float | None = Field(default=None, gt=0)
    radius: float | None = Field(default=None, gt=0)
    width: float | None = Field(default=None, gt=0)
    length: float | None = Field(default=None, gt=0)
    depth: float | None = Field(default=None, ge=0)
    height: float | None = Field(default=None, gt=0)
    angle: float | None = Field(default=None, ge=0, le=180)
    corner_radius: float | None = Field(default=None, ge=0)
    chamfer_distance: float | None = Field(default=None, ge=0)
    pitch: float | None = Field(default=None, gt=0)
    major_diameter: float | None = Field(default=None, gt=0)
    minor_diameter: float | None = Field(default=None, gt=0)


class FeatureAccessibility(BaseModel):
    """Feature machining accessibility."""

    approach_vectors: list[Vector3D] = Field(default_factory=list)
    collision_risk: AccessibilityRating = AccessibilityRating.GOOD
    tool_reach_required: float | None = Field(default=None, ge=0)
    setup_required: str | None = None
    notes: list[str] = Field(default_factory=list)


class Feature(BaseModel):
    """Manufacturing feature."""

    feature_id: str = Field(default_factory=lambda: f"F-{uuid4().hex[:6].upper()}")
    type: FeatureType
    subtype: str | None = None
    position: Vector3D
    axis: Vector3D | None = None
    plane: Plane3D | None = None
    dimensions: FeatureDimensions = Field(default_factory=FeatureDimensions)
    depth_type: DepthType | None = None
    faces: list[str] = Field(default_factory=list)
    edges: list[str] = Field(default_factory=list)
    open: bool = False
    through: bool = False
    accessibility: FeatureAccessibility = Field(default_factory=FeatureAccessibility)
    confidence: float = Field(ge=0.0, le=1.0)
    detection_method: DetectionMethod | None = None
    pattern_group: str | None = None
    relationships: dict[str, Any] = Field(default_factory=dict)
    source: str = "geometry"
    warnings: list[str] = Field(default_factory=list)


class FeatureRelationship(BaseModel):
    """Relationship between features."""

    type: RelationshipType
    parent: str | None = None
    children: list[str] = Field(default_factory=list)
    features: list[str] = Field(default_factory=list)
    pattern_id: str | None = None
    pattern_type: str | None = None
    spacing: float | None = None
    axis: Vector3D | None = None
    plane: Plane3D | None = None
    details: dict[str, Any] = Field(default_factory=dict)


# =============================================================================
# Drawing Annotations
# =============================================================================


class DrawingView(BaseModel):
    """Drawing view."""

    label: str
    type: str
    bbox: list[float]
    scale: str | None = None
    projection: str | None = None


class DrawingDimension(BaseModel):
    """Extracted drawing dimension."""

    id: str = Field(default_factory=lambda: f"D-{uuid4().hex[:6].upper()}")
    type: DimensionType
    value: float
    unit: UnitSystem
    tolerance: dict[str, Any] | None = None
    text: str
    position: list[float]
    page: int
    view: str | None = None
    associated_feature: str | None = None
    confidence: float = Field(ge=0.0, le=1.0)


class GDTAnnotation(BaseModel):
    """GD&T annotation."""

    id: str = Field(default_factory=lambda: f"GT-{uuid4().hex[:6].upper()}")
    type: GDTSymbol
    value: float | None = None
    datums: list[str] = Field(default_factory=list)
    text: str
    position: list[float]
    page: int
    view: str | None = None
    confidence: float = Field(ge=0.0, le=1.0)


class SurfaceFinishAnnotation(BaseModel):
    """Surface finish annotation."""

    id: str = Field(default_factory=lambda: f"SF-{uuid4().hex[:6].upper()}")
    symbol: str
    ra: float | None = None
    rz: float | None = None
    lay: str | None = None
    text: str
    position: list[float]
    page: int
    confidence: float = Field(ge=0.0, le=1.0)


class DrawingNote(BaseModel):
    """Drawing note."""

    id: str = Field(default_factory=lambda: f"N-{uuid4().hex[:6].upper()}")
    text: str
    category: str
    position: list[float]
    page: int
    confidence: float = Field(ge=0.0, le=1.0)


class TitleBlock(BaseModel):
    """Title block information."""

    part_number: str | None = None
    revision: str | None = None
    title: str | None = None
    material: str | None = None
    finish: str | None = None
    heat_treatment: str | None = None
    scale: str | None = None
    sheet: str | None = None
    total_sheets: int | None = None
    drawn_by: str | None = None
    checked_by: str | None = None
    approved_by: str | None = None
    date: str | None = None
    projection: str | None = None
    units: UnitSystem | None = None


class DrawingPage(BaseModel):
    """Single drawing page."""

    page_num: int
    width: float
    height: float
    unit: UnitSystem
    views: list[DrawingView] = Field(default_factory=list)
    dimensions: list[DrawingDimension] = Field(default_factory=list)
    gd_t: list[GDTAnnotation] = Field(default_factory=list)
    surface_finish: list[SurfaceFinishAnnotation] = Field(default_factory=list)
    notes: list[DrawingNote] = Field(default_factory=list)
    title_block: TitleBlock | None = None
    raw_text: list[dict[str, Any]] = Field(default_factory=list)


class DrawingAnnotations(BaseModel):
    """All drawing annotations."""

    pages: list[DrawingPage] = Field(default_factory=list)
    total_pages: int = 0


# =============================================================================
# Cross Validation
# =============================================================================


class CrossValidationCheck(BaseModel):
    """Single cross-validation check."""

    property: str
    drawing: float | str | int | None = None
    model: float | str | int | None = None
    status: ValidationStatus
    tolerance: float | None = None
    details: str | None = None


class CrossValidationReport(BaseModel):
    """Cross-validation report."""

    checks: list[CrossValidationCheck] = Field(default_factory=list)
    summary: dict[str, int] = Field(
        default_factory=lambda: {
            "matches": 0,
            "mismatches": 0,
            "drawing_only": 0,
            "model_only": 0,
            "within_tolerance": 0,
        }
    )


# =============================================================================
# Manufacturing Analysis
# =============================================================================


class Setup(BaseModel):
    """Machining setup."""

    setup_id: str = Field(default_factory=lambda: f"S-{uuid4().hex[:6].upper()}")
    orientation: Vector3D
    origin: Vector3D
    features: list[str] = Field(default_factory=list)
    description: str = ""


class Operation(BaseModel):
    """Machining operation."""

    operation_id: str = Field(default_factory=lambda: f"OP-{uuid4().hex[:6].upper()}")
    feature_ids: list[str]
    operation_type: OperationType
    tool_category: ToolCategory
    setup_id: str
    estimated_time_min: float = Field(ge=0)
    tool_diameter: float | None = Field(default=None, gt=0)
    tool_length: float | None = Field(default=None, gt=0)
    cutting_speed_m_min: float | None = Field(default=None, gt=0)
    feed_mm_min: float | None = Field(default=None, gt=0)
    depth_of_cut_mm: float | None = Field(default=None, gt=0)
    stepover_mm: float | None = Field(default=None, gt=0)
    passes: int = 1
    assumptions: list[str] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0)
    warnings: list[str] = Field(default_factory=list)


class ManufacturingAnalysis(BaseModel):
    """Manufacturing analysis results."""

    setups: list[Setup] = Field(default_factory=list)
    operations: list[Operation] = Field(default_factory=list)
    total_cutting_time_min: float = 0.0
    total_tool_change_time_min: float = 0.0
    total_setup_time_min: float = 0.0
    total_inspection_time_min: float = 0.0
    total_estimated_time_min: float = 0.0
    material_removal_volume_cm3: float = 0.0
    stock_dimensions: BoundingBox3D | None = None
    stock_volume_cm3: float = 0.0
    stock_weight_kg: float = 0.0
    machining_difficulty: str = "medium"
    inaccessible_features: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


# =============================================================================
# Material & Cost
# =============================================================================


class Material(BaseModel):
    """Material specification."""

    name: str
    grade: str | None = None
    standard: str | None = None
    density_kg_m3: float = Field(gt=0)
    source: str = "drawing"
    confidence: float = Field(ge=0.0, le=1.0)


class MaterialPricing(BaseModel):
    """Material pricing information."""

    material: str
    region: str
    supplier: str | None = None
    stock_dimensions: BoundingBox3D | None = None
    stock_weight_kg: float = 0.0
    price_per_kg: float | None = None
    price_total: float | None = None
    currency: str = "USD"
    availability: str = "unknown"
    lead_time_days: int | None = None
    last_updated: datetime | None = None
    is_verified: bool = False
    notes: list[str] = Field(default_factory=list)


class CostEstimate(BaseModel):
    """Cost estimate breakdown."""

    material_cost: float = 0.0
    machining_cost: float = 0.0
    setup_cost: float = 0.0
    tooling_cost: float = 0.0
    inspection_cost: float = 0.0
    overhead_cost: float = 0.0
    total_cost: float = 0.0
    currency: str = "USD"
    confidence: float = Field(ge=0.0, le=1.0)
    assumptions: list[str] = Field(default_factory=list)
    pricing_sources: list[str] = Field(default_factory=list)


# =============================================================================
# Confidence & Warnings
# =============================================================================


class ConfidenceReport(BaseModel):
    """Overall confidence report."""

    overall_confidence: float = Field(ge=0.0, le=1.0)
    geometry_confidence: float = Field(ge=0.0, le=1.0)
    feature_confidence: float = Field(ge=0.0, le=1.0)
    drawing_confidence: float = Field(ge=0.0, le=1.0)
    manufacturing_confidence: float = Field(ge=0.0, le=1.0)
    cost_confidence: float = Field(ge=0.0, le=1.0)
    low_confidence_items: list[str] = Field(default_factory=list)
    unknown_features: list[str] = Field(default_factory=list)
    assumptions_made: list[str] = Field(default_factory=list)
    data_gaps: list[str] = Field(default_factory=list)


class WarningItem(BaseModel):
    """Warning item."""

    code: str
    message: str
    severity: str = "warning"
    category: str = "general"
    related_features: list[str] = Field(default_factory=list)
    related_files: list[str] = Field(default_factory=list)


# =============================================================================
# Project & API Schemas
# =============================================================================


class ProjectSummary(BaseModel):
    """Project summary for API responses."""

    id: str
    name: str
    description: str | None = None
    status: str
    created_at: datetime
    updated_at: datetime | None = None
    file_count: int = 0
    has_results: bool = False


class ProjectDetail(ProjectSummary):
    """Full project details including results."""

    files: list[dict] = Field(default_factory=list)
    cad_specs: Optional["CADSpecs"] = None
    manufacturing_analysis: ManufacturingAnalysis | None = None
    cost_estimate: CostEstimate | None = None
    reports: list[dict] = Field(default_factory=list)


class CreateProjectRequest(BaseModel):
    """Request to create a new project."""

    name: str
    description: str | None = None


class UploadInitRequest(BaseModel):
    """Request to initialize file upload."""

    project_id: str
    filename: str
    file_size: int
    mime_type: str
    role: str


class UploadInitResponse(BaseModel):
    """Response for upload initialization."""

    upload_id: str
    upload_url: str
    object_key: str
    chunk_size: int = 5 * 1024 * 1024
    max_parts: int = 10000


class UploadCompleteResponse(BaseModel):
    """Response for upload completion."""

    file_id: str
    object_key: str
    status: str


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    version: str


class ReadinessResponse(BaseModel):
    """Readiness check response."""

    status: str
    checks: dict[str, str]


class CadProcessRequest(BaseModel):
    """CAD processing request."""

    project_id: str
    file_id: str
    options: dict[str, Any] = Field(default_factory=dict)


class CadProcessResponse(BaseModel):
    """CAD processing response."""

    job_id: str
    status: str


class CadExportRequest(BaseModel):
    """CAD export request."""

    project_id: str
    format: str
    feature_ids: list[str] | None = None


class CadExportResponse(BaseModel):
    """CAD export response."""

    download_url: str
    format: str


class DrawingProcessRequest(BaseModel):
    """Drawing processing request."""

    project_id: str
    file_id: str
    options: dict[str, Any] = Field(default_factory=dict)


class DrawingProcessResponse(BaseModel):
    """Drawing processing response."""

    job_id: str
    status: str


class ManufacturingRequest(BaseModel):
    """Manufacturing analysis request."""

    project_id: str
    machine_id: str
    material_id: str
    options: dict[str, Any] = Field(default_factory=dict)


class CostEstimateRequest(BaseModel):
    """Cost estimation request."""

    project_id: str
    material_id: str
    region: str
    quantity: int
    options: dict[str, Any] = Field(default_factory=dict)


class ReportGenerationRequest(BaseModel):
    """Report generation request."""

    project_id: str
    template: str
    sections: list[str] = Field(default_factory=list)
    format: str = "pdf"
    options: dict[str, Any] = Field(default_factory=dict)


class ReportGenerationResponse(BaseModel):
    """Report generation response."""

    report_id: str
    status: str
    download_url: str | None = None


class LlmAnalysisRequest(BaseModel):
    """LLM analysis request."""

    project_id: str
    prompt_type: str
    context: dict[str, Any] = Field(default_factory=dict)


class LlmAnalysisResponse(BaseModel):
    """LLM analysis response."""

    analysis: str
    sources: list[str] = Field(default_factory=list)
    confidence: float
    warnings: list[str] = Field(default_factory=list)


class LlmReportRequest(BaseModel):
    """LLM report request."""

    project_id: str
    report_type: str
    options: dict[str, Any] = Field(default_factory=dict)


class LlmReportResponse(BaseModel):
    """LLM report response."""

    report: str
    sources: list[str] = Field(default_factory=list)
    confidence: float


class MaterialPricingRequest(BaseModel):
    """Material pricing request."""

    material_id: str
    region: str
    stock_dimensions: BoundingBox3D | None = None
    quantity: int = 1


class JobStatus(BaseModel):
    """Job processing status."""

    project_id: str
    stage: str
    progress: float
    current_step: str | None = None
    error: str | None = None
    started_at: datetime
    completed_at: datetime | None = None


class PaginatedResponse(BaseModel):
    """Generic paginated response."""

    items: list[dict]
    total: int
    page: int
    page_size: int
    total_pages: int


class FeatureRecognitionResult(BaseModel):
    """Feature recognition result."""

    features: list[Feature]
    relationships: list[FeatureRelationship]
    processing_time_seconds: float


# =============================================================================
# Main CAD Specs
# =============================================================================


class CADSpecs(BaseModel):
    """Complete CAD specifications — root model for cad_specs.json"""

    version: str = "1.0"
    job_id: str = Field(default_factory=lambda: uuid4().hex)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    source_files: list[SourceFile] = Field(default_factory=list)
    units: UnitsInfo = Field(
        default_factory=lambda: UnitsInfo(
            source=UnitSystem.MM, normalized=UnitSystem.MM, confidence=1.0
        )
    )

    geometry_summary: GeometrySummary | None = None
    solid_bodies: list[SolidBody] = Field(default_factory=list)

    features: list[Feature] = Field(default_factory=list)
    feature_relationships: list[FeatureRelationship] = Field(default_factory=list)

    drawing_annotations: DrawingAnnotations | None = None
    cross_validation: CrossValidationReport | None = None

    manufacturing_analysis: ManufacturingAnalysis | None = None
    material: Material | None = None
    cost_estimate: CostEstimate | None = None

    confidence_report: ConfidenceReport | None = None
    warnings: list[WarningItem] = Field(default_factory=list)

    # Metadata
    processing_time_seconds: float = 0.0
    engine_version: str = "0.1.0"
    schema_version: str = "1.0"

    @field_validator("updated_at", mode="before")
    @classmethod
    def set_updated_at(cls, v):
        return datetime.utcnow()

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v),
        }
        use_enum_values = True
