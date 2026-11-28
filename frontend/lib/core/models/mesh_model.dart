import 'dart:math' as math;

import 'package:jobeval/core/models/json_data.dart';

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double factor) => Vec3(x * factor, y * factor, z * factor);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 get normalized {
    final value = length;
    if (value < 1e-12) return const Vec3(0, 0, 0);
    return this * (1 / value);
  }

  static Vec3? fromJson(dynamic value) {
    if (value is List && value.length >= 3) {
      return Vec3(
        JsonData.number(value[0]),
        JsonData.number(value[1]),
        JsonData.number(value[2]),
      );
    }
    if (value is Map) {
      final map = JsonData.map(value);
      return Vec3(
        JsonData.number(map['x']),
        JsonData.number(map['y']),
        JsonData.number(map['z']),
      );
    }
    return null;
  }
}

class MeshFace {
  const MeshFace({
    required this.indices,
    this.bodyId,
    this.faceId,
  });

  final List<int> indices;
  final String? bodyId;
  final String? faceId;
}

class TriMesh {
  const TriMesh({
    required this.vertices,
    required this.faces,
    this.vertexIds = const [],
    this.units = 'mm',
  });

  final List<Vec3> vertices;
  final List<MeshFace> faces;
  final List<String> vertexIds;
  final String units;

  bool get isEmpty => vertices.isEmpty || faces.isEmpty;

  List<String> get bodyIds {
    final ids = <String>{};
    for (final face in faces) {
      final id = face.bodyId;
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    final sorted = ids.toList()..sort();
    return sorted;
  }

  Vec3 get minimum {
    var result = const Vec3(double.infinity, double.infinity, double.infinity);
    for (final vertex in vertices) {
      result = Vec3(
        math.min(result.x, vertex.x),
        math.min(result.y, vertex.y),
        math.min(result.z, vertex.z),
      );
    }
    return result;
  }

  Vec3 get maximum {
    var result =
        const Vec3(-double.infinity, -double.infinity, -double.infinity);
    for (final vertex in vertices) {
      result = Vec3(
        math.max(result.x, vertex.x),
        math.max(result.y, vertex.y),
        math.max(result.z, vertex.z),
      );
    }
    return result;
  }

  static TriMesh fromAnalysis(JsonMap analysis) {
    final roots = <JsonMap>[];
    for (final key in const [
      'mesh',
      'triangulated_mesh',
      'triangulation',
      'geometry',
      'geometry_analysis',
      'result',
      'analysis',
      'data',
    ]) {
      final value = analysis[key];
      if (value is Map) roots.add(JsonData.map(value));
    }
    roots.add(analysis);

    for (final root in roots) {
      final mesh = _parseRoot(root);
      if (!mesh.isEmpty) return mesh;
    }

    for (final root in roots) {
      final bodies = root['bodies'];
      if (bodies is! List) continue;
      final vertices = <Vec3>[];
      final vertexIds = <String>[];
      final faces = <MeshFace>[];
      for (final rawBody in bodies) {
        if (rawBody is! Map) continue;
        final body = JsonData.map(rawBody);
        final bodyId = JsonData.text(
          body['body_id'] ?? body['id'] ?? body['name'],
        );
        final nested = _parseRoot(body, bodyId: bodyId);
        final offset = vertices.length;
        vertices.addAll(nested.vertices);
        vertexIds.addAll(nested.vertexIds);
        faces.addAll(
          nested.faces.map(
            (face) => MeshFace(
              indices: face.indices.map((index) => index + offset).toList(),
              bodyId: face.bodyId ?? (bodyId.isEmpty ? null : bodyId),
              faceId: face.faceId,
            ),
          ),
        );
      }
      if (vertices.isNotEmpty && faces.isNotEmpty) {
        return TriMesh(
          vertices: vertices,
          faces: faces,
          vertexIds: vertexIds,
        );
      }
    }
    return const TriMesh(vertices: [], faces: []);
  }

  static TriMesh _parseRoot(JsonMap root, {String? bodyId}) {
    final vertices = <Vec3>[];
    final vertexIds = <String>[];
    final rawVertices =
        root['vertices'] ?? root['points'] ?? root['mesh_vertices'];
    if (rawVertices is List) {
      for (final raw in rawVertices) {
        final vertex = Vec3.fromJson(raw);
        if (vertex != null) {
          vertices.add(vertex);
          if (raw is Map) {
            final map = JsonData.map(raw);
            vertexIds.add(
              JsonData.text(map['vertex_id'] ?? map['id'] ?? map['index']),
            );
          } else {
            vertexIds.add('');
          }
        }
      }
    }

    final faces = <MeshFace>[];
    final rawFaces = root['faces'] ?? root['triangles'] ?? root['mesh_faces'];
    if (rawFaces is List) {
      for (final raw in rawFaces) {
        final face = _parseFace(raw, bodyId: bodyId);
        if (face != null) faces.add(face);
      }
    }
    final units = JsonData.text(root['units'] ?? root['unit'], fallback: 'mm');
    return TriMesh(
      vertices: vertices,
      faces: faces,
      vertexIds: vertexIds,
      units: units,
    );
  }

  static MeshFace? _parseFace(dynamic raw, {String? bodyId}) {
    List<int>? indices;
    String? faceId;
    String? faceBodyId = bodyId;
    if (raw is List && raw.length >= 3) {
      indices = raw.take(3).map((value) => JsonData.integer(value)).toList();
    } else if (raw is Map) {
      final map = JsonData.map(raw);
      final rawIndices = map['indices'] ??
          map['vertex_indices'] ??
          map['vertices'] ??
          map['triangle'];
      if (rawIndices is List && rawIndices.length >= 3) {
        indices =
            rawIndices.take(3).map((value) => JsonData.integer(value)).toList();
      }
      faceId = JsonData.text(
        map['face_id'] ?? map['id'] ?? map['face'] ?? map['name'],
      );
      final nestedBody = JsonData.text(map['body_id'] ?? map['body']);
      if (nestedBody.isNotEmpty) faceBodyId = nestedBody;
    }
    if (indices == null || indices.any((index) => index < 0)) return null;
    return MeshFace(
      indices: indices,
      bodyId: faceBodyId == null || faceBodyId.isEmpty ? null : faceBodyId,
      faceId: faceId == null || faceId.isEmpty ? null : faceId,
    );
  }
}
