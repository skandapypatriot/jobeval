"""CAD Specifications Schema — Core data models for cad_specs.json v1.0"""

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional, Union
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
    pages: Optional[int] = None


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
    principal_axes: List[Vector3D] = Field(min_length=3, max_length=3)
    symmetry: Dict[str, Any] = Field(default_factory=dict)


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
    validation_errors: List[str] = Field(default_factory=list)


# =============================================================================
# Features
# =============================================================================

class FeatureDimensions(BaseModel):
    """Feature dimensions (all optional, only populated when known)."""
    diameter: Optional[float] = Field(default=None, gt=0)
    radius: Optional[float] = Field(default=None, gt=0)
    width: Optional[float] = Field(default=None, gt=0)
    length: Optional[float] = Field(default=None, gt=0)
    depth: Optional[float] = Field(default=None, ge=0)
    height: Optional[float] = Field(default=None, gt=0)
    angle: Optional[float] = Field(default=None, ge=0, le=180)
    corner_radius: Optional[float] = Field(default=None, ge=0)
    chamfer_distance: Optional[float] = Field(default=None, ge=0)
    pitch: Optional[float] = Field(default=None, gt=0)
    major_diameter: Optional[float] = Field(default=None, gt=0)
    minor_diameter: Optional[float] = Field(default=None, gt=0)


class FeatureAccessibility(BaseModel):
    """Feature machining accessibility."""
    approach_vectors: List[Vector3D] = Field(default_factory=list)
    collision_risk: AccessibilityRating = AccessibilityRating.GOOD
    tool_reach_required: Optional[float] = Field(default=None, ge=0)
    setup_required: Optional[str] = None
    notes: List[str] = Field(default_factory=list)


class Feature(BaseModel):
    """Manufacturing feature."""
    feature_id: str = Field(default_factory=lambda: f"F-{uuid4().hex[:6].upper()}")
    type: FeatureType
    subtype: Optional[str] = None
    position: Vector3D
    axis: Optional[Vector3D] = None
    plane: Optional[Plane3D] = None
    dimensions: FeatureDimensions = Field(default_factory=FeatureDimensions)
    depth_type: Optional[DepthType] = None
    faces: List[str] = Field(default_factory=list)
    edges: List[str] = Field(default_factory=list)
    open: bool = False
    through: bool = False
    accessibility: FeatureAccessibility = Field(default_factory=FeatureAccessibility)
    confidence: float = Field(ge=0.0, le=1.0)
    detection_method: Optional[DetectionMethod] = None
    pattern_group: Optional[str] = None
    relationships: Dict[str, Any] = Field(default_factory=dict)
    source: str = "geometry"
    warnings: List[str] = Field(default_factory=list)


class FeatureRelationship(BaseModel):
    """Relationship between features."""
    type: RelationshipType
    parent: Optional[str] = None
    children: List[str] = Field(default_factory=list)
    features: List[str] = Field(default_factory=list)
    pattern_id: Optional[str] = None
    pattern_type: Optional[str] = None
    spacing: Optional[float] = None
    axis: Optional[Vector3D] = None
    plane: Optional[Plane3D] = None
    details: Dict[str, Any] = Field(default_factory=dict)


# =============================================================================
# Drawing Annotations
# =============================================================================

class DrawingView(BaseModel):
    """Drawing view."""
    label: str
    type: str
    bbox: List[float]
    scale: Optional[str] = None
    projection: Optional[str] = None


class DrawingDimension(BaseModel):
    """Extracted drawing dimension."""
    id: str = Field(default_factory=lambda: f"D-{uuid4().hex[:6].upper()}")
    type: DimensionType
    value: float
    unit: UnitSystem
    tolerance: Optional[Dict[str, Any]] = None
    text: str
    position: List[float]
    page: int
    view: Optional[str] = None
    associated_feature: Optional[str] = None
    confidence: float = Field(ge=0.0, le=1.0)


class GDTAnnotation(BaseModel):
    """GD&T annotation."""
    id: str = Field(default_factory=lambda: f"GT-{uuid4().hex[:6].upper()}")
    type: GDTSymbol
    value: Optional[float] = None
    datums: List[str] = Field(default_factory=list)
    text: str
    position: List[float]
    page: int
    view: Optional[str] = None
    confidence: float = Field(ge=0.0, le=1.0)


class SurfaceFinishAnnotation(BaseModel):
    """Surface finish annotation."""
    id: str = Field(default_factory=lambda: f"SF-{uuid4().hex[:6].upper()}")
    symbol: str
    ra: Optional[float] = None
    rz: Optional[float] = None
    lay: Optional[str] = None
    text: str
    position: List[float]
    page: int
    confidence: float = Field(ge=0.0, le=1.0)


class DrawingNote(BaseModel):
    """Drawing note."""
    id: str = Field(default_factory=lambda: f"N-{uuid4().hex[:6].upper()}")
    text: str
    category: str
    position: List[float]
    page: int
    confidence: float = Field(ge=0.0, le=1.0)


class TitleBlock(BaseModel):
    """Title block information."""
    part_number: Optional[str] = None
    revision: Optional[str] = None
    title: Optional[str] = None
    material: Optional[str] = None
    finish: Optional[str] = None
    heat_treatment: Optional[str] = None
    scale: Optional[str] = None
    sheet: Optional[str] = None
    total_sheets: Optional[int] = None
    drawn_by: Optional[str] = None
    checked_by: Optional[str] = None
    approved_by: Optional[str] = None
    date: Optional[str] = None
    projection: Optional[str] = None
    units: Optional[UnitSystem] = None


class DrawingPage(BaseModel):
    """Single drawing page."""
    page_num: int
    width: float
    height: float
    unit: UnitSystem
    views: List[DrawingView] = Field(default_factory=list)
    dimensions: List[DrawingDimension] = Field(default_factory=list)
    gd_t: List[GDTAnnotation] = Field(default_factory=list)
    surface_finish: List[SurfaceFinishAnnotation] = Field(default_factory=list)
    notes: List[DrawingNote] = Field(default_factory=list)
    title_block: Optional[TitleBlock] = None
    raw_text: List[Dict[str, Any]] = Field(default_factory=list)


class DrawingAnnotations(BaseModel):
    """All drawing annotations."""
    pages: List[DrawingPage] = Field(default_factory=list)
    total_pages: int = 0


# =============================================================================
# Cross Validation
# =============================================================================

class CrossValidationCheck(BaseModel):
    """Single cross-validation check."""
    property: str
    drawing: Optional[Union[float, str, int]] = None
    model: Optional[Union[float, str, int]] = None
    status: ValidationStatus
    tolerance: Optional[float] = None
    details: Optional[str] = None


class CrossValidationReport(BaseModel):
    """Cross-validation report."""
    checks: List[CrossValidationCheck] = Field(default_factory=list)
    summary: Dict[str, int] = Field(default_factory=lambda: {
        "matches": 0,
        "mismatches": 0,
        "drawing_only": 0,
        "model_only": 0,
        "within_tolerance": 0,
    })


# =============================================================================
# Manufacturing Analysis
# =============================================================================

class Setup(BaseModel):
    """Machining setup."""
    setup_id: str = Field(default_factory=lambda: f"S-{uuid4().hex[:6].upper()}")
    orientation: Vector3D
    origin: Vector3D
    features: List[str] = Field(default_factory=list)
    description: str = ""


class Operation(BaseModel):
    """Machining operation."""
    operation_id: str = Field(default_factory=lambda: f"OP-{uuid4().hex[:6].upper()}")
    feature_ids: List[str]
    operation_type: OperationType
    tool_category: ToolCategory
    setup_id: str
    estimated_time_min: float = Field(ge=0)
    tool_diameter: Optional[float] = Field(default=None, gt=0)
    tool_length: Optional[float] = Field(default=None, gt=0)
    cutting_speed_m_min: Optional[float] = Field(default=None, gt=0)
    feed_mm_min: Optional[float] = Field(default=None, gt=0)
    depth_of_cut_mm: Optional[float] = Field(default=None, gt=0)
    stepover_mm: Optional[float] = Field(default=None, gt=0)
    passes: int = 1
    assumptions: List[str] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0)
    warnings: List[str] = Field(default_factory=list)


class ManufacturingAnalysis(BaseModel):
    """Manufacturing analysis results."""
    setups: List[Setup] = Field(default_factory=list)
    operations: List[Operation] = Field(default_factory=list)
    total_cutting_time_min: float = 0.0
    total_tool_change_time_min: float = 0.0
    total_setup_time_min: float = 0.0
    total_inspection_time_min: float = 0.0
    total_estimated_time_min: float = 0.0
    material_removal_volume_cm3: float = 0.0
    stock_dimensions: Optional[BoundingBox3D] = None
    stock_volume_cm3: float = 0.0
    stock_weight_kg: float = 0.0
    machining_difficulty: str = "medium"
    inaccessible_features: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)


# =============================================================================
# Material & Cost
# =============================================================================

class Material(BaseModel):
    """Material specification."""
    name: str
    grade: Optional[str] = None
    standard: Optional[str] = None
    density_kg_m3: float = Field(gt=0)
    source: str = "drawing"
    confidence: float = Field(ge=0.0, le=1.0)


class MaterialPricing(BaseModel):
    """Material pricing information."""
    material: str
    region: str
    supplier: Optional[str] = None
    stock_dimensions: Optional[BoundingBox3D] = None
    stock_weight_kg: float = 0.0
    price_per_kg: Optional[float] = None
    price_total: Optional[float] = None
    currency: str = "USD"
    availability: str = "unknown"
    lead_time_days: Optional[int] = None
    last_updated: Optional[datetime] = None
    is_verified: bool = False
    notes: List[str] = Field(default_factory=list)


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
    assumptions: List[str] = Field(default_factory=list)
    pricing_sources: List[str] = Field(default_factory=list)


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
    low_confidence_items: List[str] = Field(default_factory=list)
    unknown_features: List[str] = Field(default_factory=list)
    assumptions_made: List[str] = Field(default_factory=list)
    data_gaps: List[str] = Field(default_factory=list)


class WarningItem(BaseModel):
    """Warning item."""
    code: str
    message: str
    severity: str = "warning"
    category: str = "general"
    related_features: List[str] = Field(default_factory=list)
    related_files: List[str] = Field(default_factory=list)


# =============================================================================
# Project & API Schemas
# =============================================================================

class ProjectSummary(BaseModel):
    """Project summary for API responses."""
    id: str
    name: str
    description: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    file_count: int = 0
    has_results: bool = False


class ProjectDetail(ProjectSummary):
    """Full project details including results."""
    files: List[dict] = Field(default_factory=list)
    cad_specs: Optional["CADSpecs"] = None
    manufacturing_analysis: Optional[ManufacturingAnalysis] = None
    cost_estimate: Optional[CostEstimate] = None
    reports: List[dict] = Field(default_factory=list)


class CreateProjectRequest(BaseModel):
    """Request to create a new project."""
    name: str
    description: Optional[str] = None


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
    checks: Dict[str, str]


class CadProcessRequest(BaseModel):
    """CAD processing request."""
    project_id: str
    file_id: str
    options: Dict[str, Any] = Field(default_factory=dict)


class CadProcessResponse(BaseModel):
    """CAD processing response."""
    job_id: str
    status: str


class CadExportRequest(BaseModel):
    """CAD export request."""
    project_id: str
    format: str
    feature_ids: Optional[List[str]] = None


class CadExportResponse(BaseModel):
    """CAD export response."""
    download_url: str
    format: str


class DrawingProcessRequest(BaseModel):
    """Drawing processing request."""
    project_id: str
    file_id: str
    options: Dict[str, Any] = Field(default_factory=dict)


class DrawingProcessResponse(BaseModel):
    """Drawing processing response."""
    job_id: str
    status: str


class ManufacturingRequest(BaseModel):
    """Manufacturing analysis request."""
    project_id: str
    machine_id: str
    material_id: str
    options: Dict[str, Any] = Field(default_factory=dict)


class CostEstimateRequest(BaseModel):
    """Cost estimation request."""
    project_id: str
    material_id: str
    region: str
    quantity: int
    options: Dict[str, Any] = Field(default_factory=dict)


class ReportGenerationRequest(BaseModel):
    """Report generation request."""
    project_id: str
    template: str
    sections: List[str] = Field(default_factory=list)
    format: str = "pdf"
    options: Dict[str, Any] = Field(default_factory=dict)


class ReportGenerationResponse(BaseModel):
    """Report generation response."""
    report_id: str
    status: str
    download_url: Optional[str] = None


class LlmAnalysisRequest(BaseModel):
    """LLM analysis request."""
    project_id: str
    prompt_type: str
    context: Dict[str, Any] = Field(default_factory=dict)


class LlmAnalysisResponse(BaseModel):
    """LLM analysis response."""
    analysis: str
    sources: List[str] = Field(default_factory=list)
    confidence: float
    warnings: List[str] = Field(default_factory=list)


class LlmReportRequest(BaseModel):
    """LLM report request."""
    project_id: str
    report_type: str
    options: Dict[str, Any] = Field(default_factory=dict)


class LlmReportResponse(BaseModel):
    """LLM report response."""
    report: str
    sources: List[str] = Field(default_factory=list)
    confidence: float


class MaterialPricingRequest(BaseModel):
    """Material pricing request."""
    material_id: str
    region: str
    stock_dimensions: Optional[BoundingBox3D] = None
    quantity: int = 1


class JobStatus(BaseModel):
    """Job processing status."""
    project_id: str
    stage: str
    progress: float
    current_step: Optional[str] = None
    error: Optional[str] = None
    started_at: datetime
    completed_at: Optional[datetime] = None


class PaginatedResponse(BaseModel):
    """Generic paginated response."""
    items: List[dict]
    total: int
    page: int
    page_size: int
    total_pages: int


class FeatureRecognitionResult(BaseModel):
    """Feature recognition result."""
    features: List[Feature]
    relationships: List[FeatureRelationship]
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

    source_files: List[SourceFile] = Field(default_factory=list)
    units: UnitsInfo = Field(default_factory=lambda: UnitsInfo(
        source=UnitSystem.MM,
        normalized=UnitSystem.MM,
        confidence=1.0
    ))

    geometry_summary: Optional[GeometrySummary] = None
    solid_bodies: List[SolidBody] = Field(default_factory=list)

    features: List[Feature] = Field(default_factory=list)
    feature_relationships: List[FeatureRelationship] = Field(default_factory=list)

    drawing_annotations: Optional[DrawingAnnotations] = None
    cross_validation: Optional[CrossValidationReport] = None

    manufacturing_analysis: Optional[ManufacturingAnalysis] = None
    material: Optional[Material] = None
    cost_estimate: Optional[CostEstimate] = None

    confidence_report: Optional[ConfidenceReport] = None
    warnings: List[WarningItem] = Field(default_factory=list)

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