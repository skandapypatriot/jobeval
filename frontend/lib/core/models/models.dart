// Core data models for JobEval Flutter app

// =============================================================================
// Common
// =============================================================================

class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = json['data'] as List? ?? json['items'] as List? ?? [];
    return PaginatedResponse(
      items: data.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? data.length,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? data.length,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}

// =============================================================================
// Health
// =============================================================================

class HealthResponse {
  final String status;
  final String version;

  HealthResponse({required this.status, required this.version});

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      version: json['version'] as String,
    );
  }
}

class ReadinessResponse {
  final String status;
  final Map<String, String> checks;

  ReadinessResponse({required this.status, required this.checks});

  factory ReadinessResponse.fromJson(Map<String, dynamic> json) {
    return ReadinessResponse(
      status: json['status'] as String,
      checks: Map<String, String>.from(json['checks'] as Map),
    );
  }
}

// =============================================================================
// Auth / User
// =============================================================================

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? avatarUrl;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'avatar_url': avatarUrl,
        'created_at': createdAt?.toIso8601String(),
      };
}

// =============================================================================
// Projects
// =============================================================================

enum ProjectStatus { pending, processing, completed, failed, archived }

class ProjectSummary {
  final String id;
  final String name;
  final String? description;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int fileCount;
  final bool hasResults;

  ProjectSummary({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.fileCount,
    required this.hasResults,
  });

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: ProjectStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      fileCount: json['file_count'] as int? ?? 0,
      hasResults: json['has_results'] as bool? ?? false,
    );
  }
}

class ProjectDetail extends ProjectSummary {
  final List<ProjectFile> files;
  final CadSpecs? cadSpecs;
  final ManufacturingAnalysis? manufacturingAnalysis;
  final CostEstimate? costEstimate;
  final List<Report> reports;

  ProjectDetail({
    required super.id,
    required super.name,
    super.description,
    required super.status,
    required super.createdAt,
    super.updatedAt,
    required super.fileCount,
    required super.hasResults,
    required this.files,
    this.cadSpecs,
    this.manufacturingAnalysis,
    this.costEstimate,
    required this.reports,
  });

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    final base = ProjectSummary.fromJson(json);
    return ProjectDetail(
      id: base.id,
      name: base.name,
      description: base.description,
      status: base.status,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      fileCount: base.fileCount,
      hasResults: base.hasResults,
      files: (json['files'] as List? ?? [])
          .map((e) => ProjectFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      cadSpecs: json['cad_specs'] != null
          ? CadSpecs.fromJson(json['cad_specs'] as Map<String, dynamic>)
          : null,
      manufacturingAnalysis: json['manufacturing_analysis'] != null
          ? ManufacturingAnalysis.fromJson(json['manufacturing_analysis'] as Map<String, dynamic>)
          : null,
      costEstimate: json['cost_estimate'] != null
          ? CostEstimate.fromJson(json['cost_estimate'] as Map<String, dynamic>)
          : null,
      reports: (json['reports'] as List? ?? [])
          .map((e) => Report.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProjectFile {
  final String id;
  final String projectId;
  final String filename;
  final String originalFilename;
  final String mimeType;
  final int sizeBytes;
  final String role; // model_3d, drawing_2d, reference
  final String status; // uploaded, processing, processed, failed
  final String? sha256;
  final DateTime uploadedAt;

  ProjectFile({
    required this.id,
    required this.projectId,
    required this.filename,
    required this.originalFilename,
    required this.mimeType,
    required this.sizeBytes,
    required this.role,
    required this.status,
    this.sha256,
    required this.uploadedAt,
  });

  factory ProjectFile.fromJson(Map<String, dynamic> json) {
    return ProjectFile(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      filename: json['filename'] as String,
      originalFilename: json['original_filename'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      role: json['role'] as String,
      status: json['status'] as String,
      sha256: json['sha256'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class CreateProjectRequest {
  final String name;
  final String? description;

  CreateProjectRequest({required this.name, this.description});

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}

// =============================================================================
// Job Status
// =============================================================================

enum JobStage { queued, importing, analyzing, recognizing, drawing, manufacturing, estimating, reporting, completed, failed }

class JobStatus {
  final String projectId;
  final JobStage stage;
  final double progress; // 0.0 - 1.0
  final String? currentStep;
  final String? error;
  final DateTime startedAt;
  final DateTime? completedAt;

  JobStatus({
    required this.projectId,
    required this.stage,
    required this.progress,
    this.currentStep,
    this.error,
    required this.startedAt,
    this.completedAt,
  });

  factory JobStatus.fromJson(Map<String, dynamic> json) {
    return JobStatus(
      projectId: json['project_id'] as String,
      stage: JobStage.values.byName(json['stage'] as String),
      progress: (json['progress'] as num).toDouble(),
      currentStep: json['current_step'] as String?,
      error: json['error'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

// =============================================================================
// File Upload
// =============================================================================

class UploadInitRequest {
  final String projectId;
  final String filename;
  final int fileSize;
  final String mimeType;
  final String role;

  UploadInitRequest({
    required this.projectId,
    required this.filename,
    required this.fileSize,
    required this.mimeType,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'filename': filename,
        'file_size': fileSize,
        'mime_type': mimeType,
        'role': role,
      };
}

class UploadInitResponse {
  final String uploadId;
  final String uploadUrl;
  final String objectKey;
  final int chunkSize;
  final int maxParts;

  UploadInitResponse({
    required this.uploadId,
    required this.uploadUrl,
    required this.objectKey,
    required this.chunkSize,
    required this.maxParts,
  });

  factory UploadInitResponse.fromJson(Map<String, dynamic> json) {
    return UploadInitResponse(
      uploadId: json['upload_id'] as String,
      uploadUrl: json['upload_url'] as String,
      objectKey: json['object_key'] as String,
      chunkSize: json['chunk_size'] as int? ?? 5 * 1024 * 1024,
      maxParts: json['max_parts'] as int? ?? 10000,
    );
  }
}

class UploadCompleteResponse {
  final String fileId;
  final String objectKey;
  final String status;

  UploadCompleteResponse({
    required this.fileId,
    required this.objectKey,
    required this.status,
  });

  factory UploadCompleteResponse.fromJson(Map<String, dynamic> json) {
    return UploadCompleteResponse(
      fileId: json['file_id'] as String,
      objectKey: json['object_key'] as String,
      status: json['status'] as String,
    );
  }
}

// =============================================================================
// CAD Specs (simplified for frontend)
// =============================================================================

class CadSpecs {
  final String version;
  final String jobId;
  final DateTime createdAt;
  final List<SourceFile> sourceFiles;
  final UnitsInfo units;
  final GeometrySummary? geometrySummary;
  final List<SolidBody> solidBodies;
  final List<Feature> features;
  final List<FeatureRelationship> featureRelationships;
  final DrawingAnnotations? drawingAnnotations;
  final CrossValidationReport? crossValidation;
  final ManufacturingAnalysis? manufacturingAnalysis;
  final CadMaterial? material;
  final CostEstimate? costEstimate;
  final ConfidenceReport? confidenceReport;
  final List<WarningItem> warnings;

  CadSpecs({
    required this.version,
    required this.jobId,
    required this.createdAt,
    required this.sourceFiles,
    required this.units,
    this.geometrySummary,
    required this.solidBodies,
    required this.features,
    required this.featureRelationships,
    this.drawingAnnotations,
    this.crossValidation,
    this.manufacturingAnalysis,
    this.material,
    this.costEstimate,
    this.confidenceReport,
    required this.warnings,
  });

  factory CadSpecs.fromJson(Map<String, dynamic> json) {
    return CadSpecs(
      version: json['version'] as String,
      jobId: json['job_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      sourceFiles: (json['source_files'] as List? ?? [])
          .map((e) => SourceFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      units: UnitsInfo.fromJson(json['units'] as Map<String, dynamic>),
      geometrySummary: json['geometry_summary'] != null
          ? GeometrySummary.fromJson(json['geometry_summary'] as Map<String, dynamic>)
          : null,
      solidBodies: (json['solid_bodies'] as List? ?? [])
          .map((e) => SolidBody.fromJson(e as Map<String, dynamic>))
          .toList(),
      features: (json['features'] as List? ?? [])
          .map((e) => Feature.fromJson(e as Map<String, dynamic>))
          .toList(),
      featureRelationships: (json['feature_relationships'] as List? ?? [])
          .map((e) => FeatureRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
      drawingAnnotations: json['drawing_annotations'] != null
          ? DrawingAnnotations.fromJson(json['drawing_annotations'] as Map<String, dynamic>)
          : null,
      crossValidation: json['cross_validation'] != null
          ? CrossValidationReport.fromJson(json['cross_validation'] as Map<String, dynamic>)
          : null,
      manufacturingAnalysis: json['manufacturing_analysis'] != null
          ? ManufacturingAnalysis.fromJson(json['manufacturing_analysis'] as Map<String, dynamic>)
          : null,
      material: json['material'] != null
          ? CadMaterial.fromJson(json['material'] as Map<String, dynamic>)
          : null,
      costEstimate: json['cost_estimate'] != null
          ? CostEstimate.fromJson(json['cost_estimate'] as Map<String, dynamic>)
          : null,
      confidenceReport: json['confidence_report'] != null
          ? ConfidenceReport.fromJson(json['confidence_report'] as Map<String, dynamic>)
          : null,
      warnings: (json['warnings'] as List? ?? [])
          .map((e) => WarningItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SourceFile {
  final String role;
  final String path;
  final String format;
  final int sizeBytes;
  final String sha256;
  final int? pages;

  SourceFile({
    required this.role,
    required this.path,
    required this.format,
    required this.sizeBytes,
    required this.sha256,
    this.pages,
  });

  factory SourceFile.fromJson(Map<String, dynamic> json) {
    return SourceFile(
      role: json['role'] as String,
      path: json['path'] as String,
      format: json['format'] as String,
      sizeBytes: json['size_bytes'] as int,
      sha256: json['sha256'] as String,
      pages: json['pages'] as int?,
    );
  }
}

class UnitsInfo {
  final String source;
  final String normalized;
  final double confidence;
  final double conversionFactor;

  UnitsInfo({
    required this.source,
    required this.normalized,
    required this.confidence,
    required this.conversionFactor,
  });

  factory UnitsInfo.fromJson(Map<String, dynamic> json) {
    return UnitsInfo(
      source: json['source'] as String,
      normalized: json['normalized'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      conversionFactor: (json['conversion_factor'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class GeometrySummary {
  final int numBodies;
  final int numShells;
  final int numFaces;
  final int numEdges;
  final int numVertices;
  final double volume;
  final double surfaceArea;
  final BoundingBox3D bbox;
  final Vector3D centerOfMass;
  final List<Vector3D> principalAxes;
  final Map<String, dynamic> symmetry;

  GeometrySummary({
    required this.numBodies,
    required this.numShells,
    required this.numFaces,
    required this.numEdges,
    required this.numVertices,
    required this.volume,
    required this.surfaceArea,
    required this.bbox,
    required this.centerOfMass,
    required this.principalAxes,
    required this.symmetry,
  });

  factory GeometrySummary.fromJson(Map<String, dynamic> json) {
    return GeometrySummary(
      numBodies: json['num_bodies'] as int,
      numShells: json['num_shells'] as int,
      numFaces: json['num_faces'] as int,
      numEdges: json['num_edges'] as int,
      numVertices: json['num_vertices'] as int,
      volume: (json['volume'] as num).toDouble(),
      surfaceArea: (json['surface_area'] as num).toDouble(),
      bbox: BoundingBox3D.fromJson(json['bbox'] as Map<String, dynamic>),
      centerOfMass: Vector3D.fromJson(json['center_of_mass'] as Map<String, dynamic>),
      principalAxes: (json['principal_axes'] as List)
          .map((e) => Vector3D.fromJson(e as Map<String, dynamic>))
          .toList(),
      symmetry: Map<String, dynamic>.from(json['symmetry'] as Map? ?? {}),
    );
  }
}

class BoundingBox3D {
  final Vector3D min;
  final Vector3D max;

  BoundingBox3D({required this.min, required this.max});

  factory BoundingBox3D.fromJson(Map<String, dynamic> json) {
    return BoundingBox3D(
      min: Vector3D.fromJson(json['min'] as Map<String, dynamic>),
      max: Vector3D.fromJson(json['max'] as Map<String, dynamic>),
    );
  }
}

class Vector3D {
  final double x;
  final double y;
  final double z;

  Vector3D({required this.x, required this.y, required this.z});

  factory Vector3D.fromJson(Map<String, dynamic> json) {
    return Vector3D(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }
}

class SolidBody {
  final String bodyId;
  final double volume;
  final double surfaceArea;
  final BoundingBox3D bbox;
  final Vector3D centerOfMass;
  final int numFaces;
  final int numEdges;
  final int numVertices;
  final bool isValid;
  final List<String> validationErrors;

  SolidBody({
    required this.bodyId,
    required this.volume,
    required this.surfaceArea,
    required this.bbox,
    required this.centerOfMass,
    required this.numFaces,
    required this.numEdges,
    required this.numVertices,
    required this.isValid,
    required this.validationErrors,
  });

  factory SolidBody.fromJson(Map<String, dynamic> json) {
    return SolidBody(
      bodyId: json['body_id'] as String,
      volume: (json['volume'] as num).toDouble(),
      surfaceArea: (json['surface_area'] as num).toDouble(),
      bbox: BoundingBox3D.fromJson(json['bbox'] as Map<String, dynamic>),
      centerOfMass: Vector3D.fromJson(json['center_of_mass'] as Map<String, dynamic>),
      numFaces: json['num_faces'] as int,
      numEdges: json['num_edges'] as int,
      numVertices: json['num_vertices'] as int,
      isValid: json['is_valid'] as bool,
      validationErrors: (json['validation_errors'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

// =============================================================================
// Features
// =============================================================================

enum FeatureType {
  throughHole,
  blindHole,
  counterbore,
  countersink,
  tappedHoleCandidate,
  reamedHoleCandidate,
  cylindricalBore,
  openSlot,
  closedSlot,
  tSlot,
  dovetailSlot,
  rectangularPocket,
  circularPocket,
  complexPocket,
  step,
  shoulder,
  externalProfile,
  internalProfile,
  flatFace,
  planarFace,
  inclinedFace,
  angledWall,
  chamfer,
  fillet,
  roundedCorner,
  groove,
  recess,
  boss,
  rib,
  thinWall,
  taperedSurface,
  curvedSurface,
  undercutCandidate,
  threadGeometry,
  unknownFeature,
  candidateFeature,
}

class Feature {
  final String featureId;
  final FeatureType type;
  final String? subtype;
  final Vector3D position;
  final Vector3D? axis;
  final Plane3D? plane;
  final FeatureDimensions dimensions;
  final String? depthType;
  final List<String> faces;
  final List<String> edges;
  final bool open;
  final bool through;
  final FeatureAccessibility accessibility;
  final double confidence;
  final String? detectionMethod;
  final String? patternGroup;
  final Map<String, dynamic> relationships;
  final String source;
  final List<String> warnings;

  Feature({
    required this.featureId,
    required this.type,
    this.subtype,
    required this.position,
    this.axis,
    this.plane,
    required this.dimensions,
    this.depthType,
    required this.faces,
    required this.edges,
    required this.open,
    required this.through,
    required this.accessibility,
    required this.confidence,
    this.detectionMethod,
    this.patternGroup,
    required this.relationships,
    required this.source,
    required this.warnings,
  });

  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      featureId: json['feature_id'] as String,
      type: FeatureType.values.byName(json['type'] as String),
      subtype: json['subtype'] as String?,
      position: Vector3D.fromJson(json['position'] as Map<String, dynamic>),
      axis: json['axis'] != null
          ? Vector3D.fromJson(json['axis'] as Map<String, dynamic>)
          : null,
      plane: json['plane'] != null
          ? Plane3D.fromJson(json['plane'] as Map<String, dynamic>)
          : null,
      dimensions: FeatureDimensions.fromJson(json['dimensions'] as Map<String, dynamic>),
      depthType: json['depth_type'] as String?,
      faces: (json['faces'] as List? ?? []).map((e) => e as String).toList(),
      edges: (json['edges'] as List? ?? []).map((e) => e as String).toList(),
      open: json['open'] as bool? ?? false,
      through: json['through'] as bool? ?? false,
      accessibility: FeatureAccessibility.fromJson(json['accessibility'] as Map<String, dynamic>),
      confidence: (json['confidence'] as num).toDouble(),
      detectionMethod: json['detection_method'] as String?,
      patternGroup: json['pattern_group'] as String?,
      relationships: Map<String, dynamic>.from(json['relationships'] as Map? ?? {}),
      source: json['source'] as String? ?? 'geometry',
      warnings: (json['warnings'] as List? ?? []).map((e) => e as String).toList(),
    );
  }

  String get displayName {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((e) => e.capitalize())
        .join(' ');
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class FeatureDimensions {
  final double? diameter;
  final double? radius;
  final double? width;
  final double? length;
  final double? depth;
  final double? height;
  final double? angle;
  final double? cornerRadius;
  final double? chamferDistance;
  final double? pitch;
  final double? majorDiameter;
  final double? minorDiameter;

  FeatureDimensions({
    this.diameter,
    this.radius,
    this.width,
    this.length,
    this.depth,
    this.height,
    this.angle,
    this.cornerRadius,
    this.chamferDistance,
    this.pitch,
    this.majorDiameter,
    this.minorDiameter,
  });

  factory FeatureDimensions.fromJson(Map<String, dynamic> json) {
    return FeatureDimensions(
      diameter: (json['diameter'] as num?)?.toDouble(),
      radius: (json['radius'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      length: (json['length'] as num?)?.toDouble(),
      depth: (json['depth'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      angle: (json['angle'] as num?)?.toDouble(),
      cornerRadius: (json['corner_radius'] as num?)?.toDouble(),
      chamferDistance: (json['chamfer_distance'] as num?)?.toDouble(),
      pitch: (json['pitch'] as num?)?.toDouble(),
      majorDiameter: (json['major_diameter'] as num?)?.toDouble(),
      minorDiameter: (json['minor_diameter'] as num?)?.toDouble(),
    );
  }
}

class FeatureAccessibility {
  final List<Vector3D> approachVectors;
  final String collisionRisk;
  final double? toolReachRequired;
  final String? setupRequired;
  final List<String> notes;

  FeatureAccessibility({
    required this.approachVectors,
    required this.collisionRisk,
    this.toolReachRequired,
    this.setupRequired,
    required this.notes,
  });

  factory FeatureAccessibility.fromJson(Map<String, dynamic> json) {
    return FeatureAccessibility(
      approachVectors: (json['approach_vectors'] as List? ?? [])
          .map((e) => Vector3D.fromJson(e as Map<String, dynamic>))
          .toList(),
      collisionRisk: json['collision_risk'] as String? ?? 'good',
      toolReachRequired: (json['tool_reach_required'] as num?)?.toDouble(),
      setupRequired: json['setup_required'] as String?,
      notes: (json['notes'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}

class Plane3D {
  final Vector3D origin;
  final Vector3D normal;

  Plane3D({required this.origin, required this.normal});

  factory Plane3D.fromJson(Map<String, dynamic> json) {
    return Plane3D(
      origin: Vector3D.fromJson(json['origin'] as Map<String, dynamic>),
      normal: Vector3D.fromJson(json['normal'] as Map<String, dynamic>),
    );
  }
}

class FeatureRelationship {
  final String type;
  final String? parent;
  final List<String> children;
  final List<String> features;
  final String? patternId;
  final String? patternType;
  final double? spacing;
  final Vector3D? axis;
  final Plane3D? plane;
  final Map<String, dynamic> details;

  FeatureRelationship({
    required this.type,
    this.parent,
    required this.children,
    required this.features,
    this.patternId,
    this.patternType,
    this.spacing,
    this.axis,
    this.plane,
    required this.details,
  });

  factory FeatureRelationship.fromJson(Map<String, dynamic> json) {
    return FeatureRelationship(
      type: json['type'] as String,
      parent: json['parent'] as String?,
      children: (json['children'] as List? ?? []).map((e) => e as String).toList(),
      features: (json['features'] as List? ?? []).map((e) => e as String).toList(),
      patternId: json['pattern_id'] as String?,
      patternType: json['pattern_type'] as String?,
      spacing: (json['spacing'] as num?)?.toDouble(),
      axis: json['axis'] != null
          ? Vector3D.fromJson(json['axis'] as Map<String, dynamic>)
          : null,
      plane: json['plane'] != null
          ? Plane3D.fromJson(json['plane'] as Map<String, dynamic>)
          : null,
      details: Map<String, dynamic>.from(json['details'] as Map? ?? {}),
    );
  }
}

class FeatureRecognitionResult {
  final List<Feature> features;
  final List<FeatureRelationship> relationships;
  final double processingTimeSeconds;

  FeatureRecognitionResult({
    required this.features,
    required this.relationships,
    required this.processingTimeSeconds,
  });

  factory FeatureRecognitionResult.fromJson(Map<String, dynamic> json) {
    return FeatureRecognitionResult(
      features: (json['features'] as List? ?? [])
          .map((e) => Feature.fromJson(e as Map<String, dynamic>))
          .toList(),
      relationships: (json['feature_relationships'] as List? ?? [])
          .map((e) => FeatureRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
      processingTimeSeconds: (json['processing_time_seconds'] as num?)?.toDouble() ?? 0,
    );
  }
}

// =============================================================================
// CAD Views
// =============================================================================

class CadView {
  final String viewId;
  final String name; // top, front, right, isometric, etc.
  final String type; // orthographic, isometric
  final String format; // svg, png, gltf
  final String url;
  final int width;
  final int height;
  final double scale;

  CadView({
    required this.viewId,
    required this.name,
    required this.type,
    required this.format,
    required this.url,
    required this.width,
    required this.height,
    required this.scale,
  });

  factory CadView.fromJson(Map<String, dynamic> json) {
    return CadView(
      viewId: json['view_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      format: json['format'] as String,
      url: json['url'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      scale: (json['scale'] as num).toDouble(),
    );
  }
}

class CadProcessRequest {
  final String projectId;
  final String fileId;
  final Map<String, dynamic> options;

  CadProcessRequest({
    required this.projectId,
    required this.fileId,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'file_id': fileId,
        'options': options,
      };
}

class CadProcessResponse {
  final String jobId;
  final String status;

  CadProcessResponse({required this.jobId, required this.status});

  factory CadProcessResponse.fromJson(Map<String, dynamic> json) {
    return CadProcessResponse(
      jobId: json['job_id'] as String,
      status: json['status'] as String,
    );
  }
}

class CadExportRequest {
  final String projectId;
  final String format; // json, step, stl, gltf
  final List<String>? featureIds;

  CadExportRequest({
    required this.projectId,
    required this.format,
    this.featureIds,
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'format': format,
        'feature_ids': featureIds,
      };
}

class CadExportResponse {
  final String downloadUrl;
  final String format;

  CadExportResponse({required this.downloadUrl, required this.format});

  factory CadExportResponse.fromJson(Map<String, dynamic> json) {
    return CadExportResponse(
      downloadUrl: json['download_url'] as String,
      format: json['format'] as String,
    );
  }
}

// =============================================================================
// Drawing Analysis
// =============================================================================

class DrawingProcessRequest {
  final String projectId;
  final String fileId;
  final Map<String, dynamic> options;

  DrawingProcessRequest({
    required this.projectId,
    required this.fileId,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'file_id': fileId,
        'options': options,
      };
}

class DrawingProcessResponse {
  final String jobId;
  final String status;

  DrawingProcessResponse({required this.jobId, required this.status});

  factory DrawingProcessResponse.fromJson(Map<String, dynamic> json) {
    return DrawingProcessResponse(
      jobId: json['job_id'] as String,
      status: json['status'] as String,
    );
  }
}

class DrawingAnnotations {
  final List<DrawingPage> pages;
  final int totalPages;

  DrawingAnnotations({required this.pages, required this.totalPages});

  factory DrawingAnnotations.fromJson(Map<String, dynamic> json) {
    return DrawingAnnotations(
      pages: (json['pages'] as List? ?? [])
          .map((e) => DrawingPage.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

class DrawingPage {
  final int pageNum;
  final double width;
  final double height;
  final String unit;
  final List<DrawingView> views;
  final List<DrawingDimension> dimensions;
  final List<GDTAnnotation> gdT;
  final List<SurfaceFinishAnnotation> surfaceFinish;
  final List<DrawingNote> notes;
  final TitleBlock? titleBlock;

  DrawingPage({
    required this.pageNum,
    required this.width,
    required this.height,
    required this.unit,
    required this.views,
    required this.dimensions,
    required this.gdT,
    required this.surfaceFinish,
    required this.notes,
    this.titleBlock,
  });

  factory DrawingPage.fromJson(Map<String, dynamic> json) {
    return DrawingPage(
      pageNum: json['page_num'] as int,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      unit: json['unit'] as String,
      views: (json['views'] as List? ?? [])
          .map((e) => DrawingView.fromJson(e as Map<String, dynamic>))
          .toList(),
      dimensions: (json['dimensions'] as List? ?? [])
          .map((e) => DrawingDimension.fromJson(e as Map<String, dynamic>))
          .toList(),
      gdT: (json['gd_t'] as List? ?? [])
          .map((e) => GDTAnnotation.fromJson(e as Map<String, dynamic>))
          .toList(),
      surfaceFinish: (json['surface_finish'] as List? ?? [])
          .map((e) => SurfaceFinishAnnotation.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: (json['notes'] as List? ?? [])
          .map((e) => DrawingNote.fromJson(e as Map<String, dynamic>))
          .toList(),
      titleBlock: json['title_block'] != null
          ? TitleBlock.fromJson(json['title_block'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DrawingView {
  final String label;
  final String type;
  final List<double> bbox;
  final String? scale;
  final String? projection;

  DrawingView({
    required this.label,
    required this.type,
    required this.bbox,
    this.scale,
    this.projection,
  });

  factory DrawingView.fromJson(Map<String, dynamic> json) {
    return DrawingView(
      label: json['label'] as String,
      type: json['type'] as String,
      bbox: (json['bbox'] as List).map((e) => (e as num).toDouble()).toList(),
      scale: json['scale'] as String?,
      projection: json['projection'] as String?,
    );
  }
}

class DrawingDimension {
  final String id;
  final String type;
  final double value;
  final String unit;
  final Map<String, dynamic>? tolerance;
  final String text;
  final List<double> position;
  final int page;
  final String? view;
  final String? associatedFeature;
  final double confidence;

  DrawingDimension({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    this.tolerance,
    required this.text,
    required this.position,
    required this.page,
    this.view,
    this.associatedFeature,
    required this.confidence,
  });

  factory DrawingDimension.fromJson(Map<String, dynamic> json) {
    return DrawingDimension(
      id: json['id'] as String,
      type: json['type'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      tolerance: json['tolerance'] as Map<String, dynamic>?,
      text: json['text'] as String,
      position: (json['position'] as List).map((e) => (e as num).toDouble()).toList(),
      page: json['page'] as int,
      view: json['view'] as String?,
      associatedFeature: json['associated_feature'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class GDTAnnotation {
  final String id;
  final String type;
  final double? value;
  final List<String> datums;
  final String text;
  final List<double> position;
  final int page;
  final String? view;
  final double confidence;

  GDTAnnotation({
    required this.id,
    required this.type,
    this.value,
    required this.datums,
    required this.text,
    required this.position,
    required this.page,
    this.view,
    required this.confidence,
  });

  factory GDTAnnotation.fromJson(Map<String, dynamic> json) {
    return GDTAnnotation(
      id: json['id'] as String,
      type: json['type'] as String,
      value: (json['value'] as num?)?.toDouble(),
      datums: (json['datums'] as List? ?? []).map((e) => e as String).toList(),
      text: json['text'] as String,
      position: (json['position'] as List).map((e) => (e as num).toDouble()).toList(),
      page: json['page'] as int,
      view: json['view'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class SurfaceFinishAnnotation {
  final String id;
  final String symbol;
  final double? ra;
  final double? rz;
  final String? lay;
  final String text;
  final List<double> position;
  final int page;
  final double confidence;

  SurfaceFinishAnnotation({
    required this.id,
    required this.symbol,
    this.ra,
    this.rz,
    this.lay,
    required this.text,
    required this.position,
    required this.page,
    required this.confidence,
  });

  factory SurfaceFinishAnnotation.fromJson(Map<String, dynamic> json) {
    return SurfaceFinishAnnotation(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      ra: (json['ra'] as num?)?.toDouble(),
      rz: (json['rz'] as num?)?.toDouble(),
      lay: json['lay'] as String?,
      text: json['text'] as String,
      position: (json['position'] as List).map((e) => (e as num).toDouble()).toList(),
      page: json['page'] as int,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class DrawingNote {
  final String id;
  final String text;
  final String category;
  final List<double> position;
  final int page;
  final double confidence;

  DrawingNote({
    required this.id,
    required this.text,
    required this.category,
    required this.position,
    required this.page,
    required this.confidence,
  });

  factory DrawingNote.fromJson(Map<String, dynamic> json) {
    return DrawingNote(
      id: json['id'] as String,
      text: json['text'] as String,
      category: json['category'] as String,
      position: (json['position'] as List).map((e) => (e as num).toDouble()).toList(),
      page: json['page'] as int,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class TitleBlock {
  final String? partNumber;
  final String? revision;
  final String? title;
  final String? material;
  final String? finish;
  final String? heatTreatment;
  final String? scale;
  final String? sheet;
  final int? totalSheets;
  final String? drawnBy;
  final String? checkedBy;
  final String? approvedBy;
  final String? date;
  final String? projection;
  final String? units;

  TitleBlock({
    this.partNumber,
    this.revision,
    this.title,
    this.material,
    this.finish,
    this.heatTreatment,
    this.scale,
    this.sheet,
    this.totalSheets,
    this.drawnBy,
    this.checkedBy,
    this.approvedBy,
    this.date,
    this.projection,
    this.units,
  });

  factory TitleBlock.fromJson(Map<String, dynamic> json) {
    return TitleBlock(
      partNumber: json['part_number'] as String?,
      revision: json['revision'] as String?,
      title: json['title'] as String?,
      material: json['material'] as String?,
      finish: json['finish'] as String?,
      heatTreatment: json['heat_treatment'] as String?,
      scale: json['scale'] as String?,
      sheet: json['sheet'] as String?,
      totalSheets: json['total_sheets'] as int?,
      drawnBy: json['drawn_by'] as String?,
      checkedBy: json['checked_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      date: json['date'] as String?,
      projection: json['projection'] as String?,
      units: json['units'] as String?,
    );
  }
}

// =============================================================================
// Cross Validation
// =============================================================================

class CrossValidationReport {
  final List<CrossValidationCheck> checks;
  final Map<String, int> summary;

  CrossValidationReport({required this.checks, required this.summary});

  factory CrossValidationReport.fromJson(Map<String, dynamic> json) {
    return CrossValidationReport(
      checks: (json['checks'] as List? ?? [])
          .map((e) => CrossValidationCheck.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: Map<String, int>.from(json['summary'] as Map? ?? {}),
    );
  }
}

class CrossValidationCheck {
  final String property;
  final dynamic drawing;
  final dynamic model;
  final String status;
  final double? tolerance;
  final String? details;

  CrossValidationCheck({
    required this.property,
    this.drawing,
    this.model,
    required this.status,
    this.tolerance,
    this.details,
  });

  factory CrossValidationCheck.fromJson(Map<String, dynamic> json) {
    return CrossValidationCheck(
      property: json['property'] as String,
      drawing: json['drawing'],
      model: json['model'],
      status: json['status'] as String,
      tolerance: (json['tolerance'] as num?)?.toDouble(),
      details: json['details'] as String?,
    );
  }
}

// =============================================================================
// Manufacturing
// =============================================================================

class ManufacturingRequest {
  final String projectId;
  final String machineId;
  final String materialId;
  final Map<String, dynamic> options;

  ManufacturingRequest({
    required this.projectId,
    required this.machineId,
    required this.materialId,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'machine_id': machineId,
        'material_id': materialId,
        'options': options,
      };
}

class ManufacturingAnalysis {
  final List<Setup> setups;
  final List<Operation> operations;
  final double totalCuttingTimeMin;
  final double totalToolChangeTimeMin;
  final double totalSetupTimeMin;
  final double totalInspectionTimeMin;
  final double totalEstimatedTimeMin;
  final double materialRemovalVolumeCm3;
  final BoundingBox3D? stockDimensions;
  final double stockVolumeCm3;
  final double stockWeightKg;
  final String machiningDifficulty;
  final List<String> inaccessibleFeatures;
  final List<String> warnings;

  ManufacturingAnalysis({
    required this.setups,
    required this.operations,
    required this.totalCuttingTimeMin,
    required this.totalToolChangeTimeMin,
    required this.totalSetupTimeMin,
    required this.totalInspectionTimeMin,
    required this.totalEstimatedTimeMin,
    required this.materialRemovalVolumeCm3,
    this.stockDimensions,
    required this.stockVolumeCm3,
    required this.stockWeightKg,
    required this.machiningDifficulty,
    required this.inaccessibleFeatures,
    required this.warnings,
  });

  factory ManufacturingAnalysis.fromJson(Map<String, dynamic> json) {
    return ManufacturingAnalysis(
      setups: (json['setups'] as List? ?? [])
          .map((e) => Setup.fromJson(e as Map<String, dynamic>))
          .toList(),
      operations: (json['operations'] as List? ?? [])
          .map((e) => Operation.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCuttingTimeMin: (json['total_cutting_time_min'] as num).toDouble(),
      totalToolChangeTimeMin: (json['total_tool_change_time_min'] as num).toDouble(),
      totalSetupTimeMin: (json['total_setup_time_min'] as num).toDouble(),
      totalInspectionTimeMin: (json['total_inspection_time_min'] as num).toDouble(),
      totalEstimatedTimeMin: (json['total_estimated_time_min'] as num).toDouble(),
      materialRemovalVolumeCm3: (json['material_removal_volume_cm3'] as num).toDouble(),
      stockDimensions: json['stock_dimensions'] != null
          ? BoundingBox3D.fromJson(json['stock_dimensions'] as Map<String, dynamic>)
          : null,
      stockVolumeCm3: (json['stock_volume_cm3'] as num).toDouble(),
      stockWeightKg: (json['stock_weight_kg'] as num).toDouble(),
      machiningDifficulty: json['machining_difficulty'] as String,
      inaccessibleFeatures: (json['inaccessible_features'] as List? ?? [])
          .map((e) => e as String)
          .toList(),
      warnings: (json['warnings'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}

class Setup {
  final String setupId;
  final Vector3D orientation;
  final Vector3D origin;
  final List<String> features;
  final String description;

  Setup({
    required this.setupId,
    required this.orientation,
    required this.origin,
    required this.features,
    required this.description,
  });

  factory Setup.fromJson(Map<String, dynamic> json) {
    return Setup(
      setupId: json['setup_id'] as String,
      orientation: Vector3D.fromJson(json['orientation'] as Map<String, dynamic>),
      origin: Vector3D.fromJson(json['origin'] as Map<String, dynamic>),
      features: (json['features'] as List? ?? []).map((e) => e as String).toList(),
      description: json['description'] as String? ?? '',
    );
  }
}

enum OperationType {
  faceMilling,
  pocketMilling,
  slotMilling,
  profileMilling,
  drilling,
  reaming,
  tapping,
  boring,
  counterboring,
  countersinking,
  chamfering,
  engraving,
  deburring,
  inspection,
}

enum ToolCategory {
  endMill,
  ballEndMill,
  faceMill,
  drill,
  reamer,
  tap,
  boringBar,
  counterboreTool,
  countersinkTool,
  chamferTool,
  threadMill,
  slotDrill,
  tSlotCutter,
  dovetailCutter,
}

class Operation {
  final String operationId;
  final List<String> featureIds;
  final OperationType operationType;
  final ToolCategory toolCategory;
  final String setupId;
  final double estimatedTimeMin;
  final double? toolDiameter;
  final double? toolLength;
  final double? cuttingSpeedMMin;
  final double? feedMmMin;
  final double? depthOfCutMm;
  final double? stepoverMm;
  final int passes;
  final List<String> assumptions;
  final double confidence;
  final List<String> warnings;

  Operation({
    required this.operationId,
    required this.featureIds,
    required this.operationType,
    required this.toolCategory,
    required this.setupId,
    required this.estimatedTimeMin,
    this.toolDiameter,
    this.toolLength,
    this.cuttingSpeedMMin,
    this.feedMmMin,
    this.depthOfCutMm,
    this.stepoverMm,
    required this.passes,
    required this.assumptions,
    required this.confidence,
    required this.warnings,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      operationId: json['operation_id'] as String,
      featureIds: (json['feature_ids'] as List? ?? []).map((e) => e as String).toList(),
      operationType: OperationType.values.byName(json['operation_type'] as String),
      toolCategory: ToolCategory.values.byName(json['tool_category'] as String),
      setupId: json['setup_id'] as String,
      estimatedTimeMin: (json['estimated_time_min'] as num).toDouble(),
      toolDiameter: (json['tool_diameter'] as num?)?.toDouble(),
      toolLength: (json['tool_length'] as num?)?.toDouble(),
      cuttingSpeedMMin: (json['cutting_speed_m_min'] as num?)?.toDouble(),
      feedMmMin: (json['feed_mm_min'] as num?)?.toDouble(),
      depthOfCutMm: (json['depth_of_cut_mm'] as num?)?.toDouble(),
      stepoverMm: (json['stepover_mm'] as num?)?.toDouble(),
      passes: json['passes'] as int? ?? 1,
      assumptions: (json['assumptions'] as List? ?? []).map((e) => e as String).toList(),
      confidence: (json['confidence'] as num).toDouble(),
      warnings: (json['warnings'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}

// =============================================================================
// Materials
// =============================================================================

class MaterialInfo {
  final String id;
  final String name;
  final String? grade;
  final String? standard;
  final String category; // aluminum, steel, stainless, brass, copper, plastic, other
  final double densityKgM3;
  final Map<String, dynamic> properties;
  final bool isActive;

  MaterialInfo({
    required this.id,
    required this.name,
    this.grade,
    this.standard,
    required this.category,
    required this.densityKgM3,
    required this.properties,
    required this.isActive,
  });

  factory MaterialInfo.fromJson(Map<String, dynamic> json) {
    return MaterialInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      grade: json['grade'] as String?,
      standard: json['standard'] as String?,
      category: json['category'] as String,
      densityKgM3: (json['density_kg_m3'] as num).toDouble(),
      properties: Map<String, dynamic>.from(json['properties'] as Map? ?? {}),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CadMaterial {
  final String name;
  final String? grade;
  final String? standard;
  final double densityKgM3;
  final String source;
  final double confidence;

  CadMaterial({
    required this.name,
    this.grade,
    this.standard,
    required this.densityKgM3,
    required this.source,
    required this.confidence,
  });

  factory CadMaterial.fromJson(Map<String, dynamic> json) {
    return CadMaterial(
      name: json['name'] as String,
      grade: json['grade'] as String?,
      standard: json['standard'] as String?,
      densityKgM3: (json['density_kg_m3'] as num).toDouble(),
      source: json['source'] as String? ?? 'drawing',
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class MaterialPricingRequest {
  final String materialId;
  final String region;
  final BoundingBox3D stockDimensions;
  final int quantity;

  MaterialPricingRequest({
    required this.materialId,
    required this.region,
    required this.stockDimensions,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'material_id': materialId,
        'region': region,
        'stock_dimensions': {
          'min': {'x': stockDimensions.min.x, 'y': stockDimensions.min.y, 'z': stockDimensions.min.z},
          'max': {'x': stockDimensions.max.x, 'y': stockDimensions.max.y, 'z': stockDimensions.max.z},
        },
        'quantity': quantity,
      };
}

class MaterialPricing {
  final String material;
  final String region;
  final String? supplier;
  final BoundingBox3D? stockDimensions;
  final double stockWeightKg;
  final double? pricePerKg;
  final double? priceTotal;
  final String currency;
  final String availability;
  final int? leadTimeDays;
  final DateTime? lastUpdated;
  final bool isVerified;
  final List<String> notes;

  MaterialPricing({
    required this.material,
    required this.region,
    this.supplier,
    this.stockDimensions,
    required this.stockWeightKg,
    this.pricePerKg,
    this.priceTotal,
    required this.currency,
    required this.availability,
    this.leadTimeDays,
    this.lastUpdated,
    required this.isVerified,
    required this.notes,
  });

  factory MaterialPricing.fromJson(Map<String, dynamic> json) {
    return MaterialPricing(
      material: json['material'] as String,
      region: json['region'] as String,
      supplier: json['supplier'] as String?,
      stockDimensions: json['stock_dimensions'] != null
          ? BoundingBox3D.fromJson(json['stock_dimensions'] as Map<String, dynamic>)
          : null,
      stockWeightKg: (json['stock_weight_kg'] as num).toDouble(),
      pricePerKg: (json['price_per_kg'] as num?)?.toDouble(),
      priceTotal: (json['price_total'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      availability: json['availability'] as String? ?? 'unknown',
      leadTimeDays: json['lead_time_days'] as int?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      isVerified: json['is_verified'] as bool? ?? false,
      notes: (json['notes'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}

// =============================================================================
// Cost Estimation
// =============================================================================

class CostEstimateRequest {
  final String projectId;
  final String materialId;
  final String region;
  final int quantity;
  final Map<String, dynamic> options;

  CostEstimateRequest({
    required this.projectId,
    required this.materialId,
    required this.region,
    required this.quantity,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'material_id': materialId,
        'region': region,
        'quantity': quantity,
        'options': options,
      };
}

class CostEstimate {
  final double materialCost;
  final double machiningCost;
  final double setupCost;
  final double toolingCost;
  final double inspectionCost;
  final double overheadCost;
  final double totalCost;
  final String currency;
  final double confidence;
  final List<String> assumptions;
  final List<String> pricingSources;

  CostEstimate({
    required this.materialCost,
    required this.machiningCost,
    required this.setupCost,
    required this.toolingCost,
    required this.inspectionCost,
    required this.overheadCost,
    required this.totalCost,
    required this.currency,
    required this.confidence,
    required this.assumptions,
    required this.pricingSources,
  });

  factory CostEstimate.fromJson(Map<String, dynamic> json) {
    return CostEstimate(
      materialCost: (json['material_cost'] as num).toDouble(),
      machiningCost: (json['machining_cost'] as num).toDouble(),
      setupCost: (json['setup_cost'] as num).toDouble(),
      toolingCost: (json['tooling_cost'] as num).toDouble(),
      inspectionCost: (json['inspection_cost'] as num).toDouble(),
      overheadCost: (json['overhead_cost'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      confidence: (json['confidence'] as num).toDouble(),
      assumptions: (json['assumptions'] as List? ?? []).map((e) => e as String).toList(),
      pricingSources: (json['pricing_sources'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}

class CostBreakdown {
  final CostEstimate estimate;
  final List<CostItem> items;

  CostBreakdown({required this.estimate, required this.items});

  factory CostBreakdown.fromJson(Map<String, dynamic> json) {
    return CostBreakdown(
      estimate: CostEstimate.fromJson(json['estimate'] as Map<String, dynamic>),
      items: (json['items'] as List? ?? [])
          .map((e) => CostItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CostItem {
  final String category;
  final String description;
  final double quantity;
  final String unit;
  final double unitCost;
  final double totalCost;
  final String? notes;

  CostItem({
    required this.category,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.totalCost,
    this.notes,
  });

  factory CostItem.fromJson(Map<String, dynamic> json) {
    return CostItem(
      category: json['category'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      unitCost: (json['unit_cost'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }
}

// =============================================================================
// Reports
// =============================================================================

class ReportGenerationRequest {
  final String projectId;
  final String template; // technical, executive, manufacturing, full
  final List<String> sections;
  final String format; // pdf, html, json
  final Map<String, dynamic> options;

  ReportGenerationRequest({
    required this.projectId,
    required this.template,
    this.sections = const [],
    this.format = 'pdf',
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'template': template,
        'sections': sections,
        'format': format,
        'options': options,
      };
}

class ReportGenerationResponse {
  final String reportId;
  final String status;
  final String? downloadUrl;

  ReportGenerationResponse({
    required this.reportId,
    required this.status,
    this.downloadUrl,
  });

  factory ReportGenerationResponse.fromJson(Map<String, dynamic> json) {
    return ReportGenerationResponse(
      reportId: json['report_id'] as String,
      status: json['status'] as String,
      downloadUrl: json['download_url'] as String?,
    );
  }
}

class Report {
  final String id;
  final String projectId;
  final String template;
  final String format;
  final String status;
  final String? downloadUrl;
  final DateTime createdAt;
  final DateTime? completedAt;

  Report({
    required this.id,
    required this.projectId,
    required this.template,
    required this.format,
    required this.status,
    this.downloadUrl,
    required this.createdAt,
    this.completedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      template: json['template'] as String,
      format: json['format'] as String,
      status: json['status'] as String,
      downloadUrl: json['download_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

// =============================================================================
// LLM
// =============================================================================

class LlmAnalysisRequest {
  final String projectId;
  final String promptType; // feature_explanation, drawing_interpretation, manufacturing_suggestions
  final Map<String, dynamic> context;

  LlmAnalysisRequest({
    required this.projectId,
    required this.promptType,
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'prompt_type': promptType,
        'context': context,
      };
}

class LlmAnalysisResponse {
  final String analysis;
  final List<String> sources;
  final double confidence;
  final List<String> warnings;

  LlmAnalysisResponse({
    required this.analysis,
    required this.sources,
    required this.confidence,
    required this.warnings,
  });

  factory LlmAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return LlmAnalysisResponse(
      analysis: json['analysis'] as String,
      sources: (json['sources'] as List? ?? []).map((e) => e as String).toList(),
      confidence: (json['confidence'] as num).toDouble(),
      warnings: (json['warnings'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}

class LlmReportRequest {
  final String projectId;
  final String reportType;
  final Map<String, dynamic> options;

  LlmReportRequest({
    required this.projectId,
    required this.reportType,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'report_type': reportType,
        'options': options,
      };
}

class LlmReportResponse {
  final String report;
  final List<String> sources;
  final double confidence;

  LlmReportResponse({
    required this.report,
    required this.sources,
    required this.confidence,
  });

  factory LlmReportResponse.fromJson(Map<String, dynamic> json) {
    return LlmReportResponse(
      report: json['report'] as String,
      sources: (json['sources'] as List? ?? []).map((e) => e as String).toList(),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

// =============================================================================
// Confidence & Warnings
// =============================================================================

class ConfidenceReport {
  final double overallConfidence;
  final double geometryConfidence;
  final double featureConfidence;
  final double drawingConfidence;
  final double manufacturingConfidence;
  final double costConfidence;
  final List<String> lowConfidenceItems;
  final List<String> unknownFeatures;
  final List<String> assumptionsMade;
  final List<String> dataGaps;

  ConfidenceReport({
    required this.overallConfidence,
    required this.geometryConfidence,
    required this.featureConfidence,
    required this.drawingConfidence,
    required this.manufacturingConfidence,
    required this.costConfidence,
    required this.lowConfidenceItems,
    required this.unknownFeatures,
    required this.assumptionsMade,
    required this.dataGaps,
  });

  factory ConfidenceReport.fromJson(Map<String, dynamic> json) {
    return ConfidenceReport(
      overallConfidence: (json['overall_confidence'] as num).toDouble(),
      geometryConfidence: (json['geometry_confidence'] as num).toDouble(),
      featureConfidence: (json['feature_confidence'] as num).toDouble(),
      drawingConfidence: (json['drawing_confidence'] as num).toDouble(),
      manufacturingConfidence: (json['manufacturing_confidence'] as num).toDouble(),
      costConfidence: (json['cost_confidence'] as num).toDouble(),
      lowConfidenceItems: (json['low_confidence_items'] as List? ?? []).map((e) => e as String).toList(),
      unknownFeatures: (json['unknown_features'] as List? ?? []).map((e) => e as String).toList(),
      assumptionsMade: (json['assumptions_made'] as List? ?? []).map((e) => e as String).toList(),
      dataGaps: (json['data_gaps'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}

class WarningItem {
  final String code;
  final String message;
  final String severity;
  final String category;
  final List<String> relatedFeatures;
  final List<String> relatedFiles;

  WarningItem({
    required this.code,
    required this.message,
    required this.severity,
    required this.category,
    required this.relatedFeatures,
    required this.relatedFiles,
  });

  factory WarningItem.fromJson(Map<String, dynamic> json) {
    return WarningItem(
      code: json['code'] as String,
      message: json['message'] as String,
      severity: json['severity'] as String? ?? 'warning',
      category: json['category'] as String? ?? 'general',
      relatedFeatures: (json['related_features'] as List? ?? []).map((e) => e as String).toList(),
      relatedFiles: (json['related_files'] as List? ?? []).map((e) => e as String).toList(),
    );
  }
}