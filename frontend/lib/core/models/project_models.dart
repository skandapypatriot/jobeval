import 'package:jobeval/core/models/json_data.dart';

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.fileCount,
    required this.hasResults,
    required this.raw,
  });

  factory ProjectSummary.fromJson(JsonMap json) {
    return ProjectSummary(
      id: JsonData.text(json['id'] ?? json['project_id']),
      name: JsonData.displayName(json),
      description: JsonData.text(json['description']),
      status: JsonData.status(json),
      createdAt: JsonData.date(json['created_at']),
      updatedAt: JsonData.date(json['updated_at']),
      fileCount: JsonData.integer(
        json['file_count'] ?? json['files_count'] ?? json['total_files'],
      ),
      hasResults: JsonData.boolean(
        json['has_results'] ?? json['has_analysis'],
      ),
      raw: json,
    );
  }

  final String id;
  final String name;
  final String description;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int fileCount;
  final bool hasResults;
  final JsonMap raw;
}

class ProjectFile {
  const ProjectFile({
    required this.id,
    required this.name,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.role,
    required this.status,
    required this.uploadedAt,
    required this.raw,
  });

  factory ProjectFile.fromJson(JsonMap json) {
    return ProjectFile(
      id: JsonData.text(json['id'] ?? json['file_id']),
      name: JsonData.text(
        json['filename'] ?? json['original_filename'] ?? json['name'],
      ),
      originalName: JsonData.text(
        json['original_filename'] ?? json['filename'] ?? json['name'],
      ),
      mimeType: JsonData.text(json['mime_type'] ?? json['content_type']),
      sizeBytes: JsonData.integer(
        json['size_bytes'] ?? json['file_size'] ?? json['size'],
      ),
      role: JsonData.text(json['role'] ?? json['file_role'],
          fallback: 'reference'),
      status: JsonData.status(json),
      uploadedAt: JsonData.date(json['uploaded_at'] ?? json['created_at']),
      raw: json,
    );
  }

  final String id;
  final String name;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String role;
  final String status;
  final DateTime? uploadedAt;
  final JsonMap raw;
}

class FeatureRecord {
  const FeatureRecord({
    required this.id,
    required this.type,
    required this.dimensions,
    required this.depthType,
    required this.through,
    required this.axis,
    required this.confidence,
    required this.reviewStatus,
    required this.source,
    required this.evidence,
    required this.reason,
    required this.faceIds,
    required this.bodyId,
    required this.vertexIds,
    required this.provenance,
    required this.raw,
  });

  factory FeatureRecord.fromJson(JsonMap json) {
    final dimensions = JsonData.firstMap(json, const [
      'dimensions',
      'dimension',
      'size',
    ]);
    final axisValue = json['axis'];
    final axis = VecAxis.fromJson(axisValue);
    return FeatureRecord(
      id: JsonData.text(
        json['feature_id'] ?? json['id'] ?? json['name'],
      ),
      type: JsonData.text(json['type'] ?? json['feature_type'],
          fallback: 'unknown'),
      dimensions: dimensions,
      depthType: JsonData.text(
        json['depth_type'] ?? json['depth_class'],
        fallback:
            JsonData.boolean(json['through']) ? 'through' : 'not specified',
      ),
      through: JsonData.boolean(json['through']),
      axis: axis,
      confidence: json['confidence'] == null
          ? null
          : JsonData.number(json['confidence']),
      reviewStatus: JsonData.text(
        json['review_status'] ?? json['status'] ?? json['review'],
        fallback: 'needs_review',
      ),
      source:
          JsonData.text(json['source'] ?? json['origin'], fallback: 'unknown'),
      evidence: _textValues(json['evidence'] ?? json['evidence_ids']),
      reason: JsonData.text(
        json['reason'] ?? json['detection_reason'] ?? json['detection_method'],
      ),
      faceIds: JsonData.strings(
        json['face_ids'] ?? json['faces'] ?? json['mapped_faces'],
      ),
      bodyId: JsonData.text(json['body_id'] ?? json['body']),
      vertexIds: JsonData.strings(
        json['vertex_ids'] ?? json['vertices'] ?? json['mapped_vertices'],
      ),
      provenance: JsonData.firstMap(json, const [
        'provenance',
        'field_sources',
        'sources',
      ]),
      raw: json,
    );
  }

  static List<String> _textValues(dynamic value) {
    if (value is String) return [value];
    if (value is List) {
      return value
          .map((item) => item is Map
              ? JsonData.text(item['text'] ?? item['reason'] ?? item['id'])
              : item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  final String id;
  final String type;
  final JsonMap dimensions;
  final String depthType;
  final bool through;
  final VecAxis? axis;
  final double? confidence;
  final String reviewStatus;
  final String source;
  final List<String> evidence;
  final String reason;
  final List<String> faceIds;
  final String bodyId;
  final List<String> vertexIds;
  final JsonMap provenance;
  final JsonMap raw;

  String get confidenceBand {
    final value = confidence;
    if (value == null) return 'Not scored';
    if (value < 0.5) return 'Low band';
    if (value < 0.75) return 'Medium band';
    return 'High band';
  }
}

class VecAxis {
  const VecAxis(this.x, this.y, this.z);

  static VecAxis? fromJson(dynamic value) {
    if (value is List && value.length >= 3) {
      return VecAxis(
        JsonData.number(value[0]),
        JsonData.number(value[1]),
        JsonData.number(value[2]),
      );
    }
    if (value is Map) {
      final map = JsonData.map(value);
      return VecAxis(
        JsonData.number(map['x']),
        JsonData.number(map['y']),
        JsonData.number(map['z']),
      );
    }
    return null;
  }

  final double x;
  final double y;
  final double z;

  @override
  String toString() =>
      '(${formatNumber(x)}, ${formatNumber(y)}, ${formatNumber(z)})';
}
