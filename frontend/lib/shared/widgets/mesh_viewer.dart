import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/mesh_model.dart';

enum MeshInteractionMode { orbit, pan }

class MeshViewer extends StatefulWidget {
  const MeshViewer({
    super.key,
    required this.mesh,
    this.selectedBodyId,
    this.selectedFaceIds = const {},
    this.selectedVertexIds = const {},
    this.showAxes = true,
    this.showBoundingBox = true,
  });

  final TriMesh mesh;
  final String? selectedBodyId;
  final Set<String> selectedFaceIds;
  final Set<String> selectedVertexIds;
  final bool showAxes;
  final bool showBoundingBox;

  @override
  State<MeshViewer> createState() => _MeshViewerState();
}

class _MeshViewerState extends State<MeshViewer> {
  double _yaw = 0.72;
  double _pitch = 0.48;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  MeshInteractionMode _mode = MeshInteractionMode.orbit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Interactive triangulated 3D model. Drag to orbit, use the mouse wheel to zoom, and switch to pan mode to move the model.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: const Color(0xFF111D25),
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerSignal: _handlePointerSignal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) {},
                    onScaleUpdate: _handleScaleUpdate,
                    child: CustomPaint(
                      painter: _MeshPainter(
                        mesh: widget.mesh,
                        yaw: _yaw,
                        pitch: _pitch,
                        zoom: _zoom,
                        pan: _pan,
                        selectedBodyId: widget.selectedBodyId,
                        selectedFaceIds: widget.selectedFaceIds,
                        selectedVertexIds: widget.selectedVertexIds,
                        showAxes: widget.showAxes,
                        showBoundingBox: widget.showBoundingBox,
                        brightness: Theme.of(context).brightness,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: _ViewerToolbar(
                  mode: _mode,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onZoomIn: () => setState(
                    () => _zoom = (_zoom * 1.18).clamp(0.15, 12).toDouble(),
                  ),
                  onZoomOut: () => setState(
                    () => _zoom = (_zoom / 1.18).clamp(0.15, 12).toDouble(),
                  ),
                  onFit: _fit,
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xCC172630),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF425764)),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Text(
                      '${widget.mesh.vertices.length} vertices · ${widget.mesh.faces.length} triangles · ${widget.mesh.units}',
                      style: const TextStyle(
                        color: Color(0xFFD7E4EA),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (_mode == MeshInteractionMode.pan || details.pointerCount >= 2) {
        _pan += details.focalPointDelta;
        _zoom = (_zoom * details.scale).clamp(0.15, 12).toDouble();
      } else {
        _yaw += details.focalPointDelta.dx * 0.009;
        _pitch = (_pitch + details.focalPointDelta.dy * 0.009)
            .clamp(-math.pi / 2 + 0.05, math.pi / 2 - 0.05);
      }
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    setState(() => _zoom = (_zoom * factor).clamp(0.15, 12).toDouble());
  }

  void _fit() {
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
    });
  }
}

class _ViewerToolbar extends StatelessWidget {
  const _ViewerToolbar({
    required this.mode,
    required this.onModeChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final MeshInteractionMode mode;
  final ValueChanged<MeshInteractionMode> onModeChanged;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6172630),
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(
              icon: Icons.threed_rotation,
              tooltip: 'Orbit drag',
              selected: mode == MeshInteractionMode.orbit,
              onPressed: () => onModeChanged(MeshInteractionMode.orbit),
            ),
            _ToolButton(
              icon: Icons.pan_tool_alt_outlined,
              tooltip: 'Pan drag',
              selected: mode == MeshInteractionMode.pan,
              onPressed: () => onModeChanged(MeshInteractionMode.pan),
            ),
            const SizedBox(width: 3),
            Container(width: 1, height: 24, color: const Color(0xFF425764)),
            const SizedBox(width: 3),
            _ToolButton(
              icon: Icons.remove,
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
            ),
            _ToolButton(
              icon: Icons.add,
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
            ),
            _ToolButton(
              icon: Icons.fit_screen_outlined,
              tooltip: 'Fit model to view',
              onPressed: onFit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 19,
        color: selected ? const Color(0xFFFFC857) : const Color(0xFFD7E4EA),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.mesh,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.selectedBodyId,
    required this.selectedFaceIds,
    required this.selectedVertexIds,
    required this.showAxes,
    required this.showBoundingBox,
    required this.brightness,
  });

  final TriMesh mesh;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;
  final String? selectedBodyId;
  final Set<String> selectedFaceIds;
  final Set<String> selectedVertexIds;
  final bool showAxes;
  final bool showBoundingBox;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    if (mesh.isEmpty) return;
    final center = (mesh.minimum + mesh.maximum) * 0.5;
    final extent = mesh.maximum - mesh.minimum;
    final radius = math.max(extent.length / 2, 0.5);
    final baseScale = math.min(size.width, size.height) / (radius * 2.65);
    final scale = baseScale * zoom;
    final screenCenter = size.center(Offset.zero) + pan;

    _drawGrid(canvas, size, center, radius, scale, screenCenter);

    final projectedVertices = mesh.vertices
        .map((vertex) => _project(vertex, center, scale, screenCenter))
        .toList(growable: false);
    final faceOrder = List<int>.generate(mesh.faces.length, (index) => index)
      ..sort((a, b) {
        final depthA = _faceDepth(mesh.faces[a], projectedVertices);
        final depthB = _faceDepth(mesh.faces[b], projectedVertices);
        return depthB.compareTo(depthA);
      });

    for (final faceIndex in faceOrder) {
      final face = mesh.faces[faceIndex];
      if (face.indices.any(
        (index) => index < 0 || index >= projectedVertices.length,
      )) {
        continue;
      }
      final points =
          face.indices.map((index) => projectedVertices[index].point).toList();
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      final selectedFace = _faceIsSelected(face, faceIndex);
      final selectedBody =
          selectedBodyId != null && face.bodyId == selectedBodyId;
      final normal = _normal(face, center);
      final light = const Vec3(-0.4, 0.7, -0.6).normalized;
      final shade = (0.42 + 0.58 * normal.dot(light).abs()).clamp(0.28, 1.0);
      final baseColor = selectedFace
          ? const Color(0xFFF2A900)
          : selectedBody
              ? const Color(0xFF23A695)
              : Color.lerp(
                  const Color(0xFF547B94),
                  const Color(0xFFB8D1DF),
                  shade,
                )!;
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor.withValues(
            alpha: selectedFace || selectedBody ? 0.92 : 0.82);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selectedFace || selectedBody ? 1.4 : 0.55
        ..color = selectedFace
            ? const Color(0xFFFFE09A)
            : selectedBody
                ? const Color(0xFF8DE3D6)
                : const Color(0x99394F5D);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    _drawSelectedVertices(canvas, projectedVertices);
    if (showAxes) _drawAxes(canvas, center, radius, scale, screenCenter);
    if (showBoundingBox) {
      _drawBounds(canvas, projectedVertices, size);
    }
  }

  bool _faceIsSelected(MeshFace face, int faceIndex) {
    if (face.faceId != null && selectedFaceIds.contains(face.faceId))
      return true;
    return selectedFaceIds.contains(faceIndex.toString());
  }

  void _drawGrid(
    Canvas canvas,
    Size size,
    Vec3 center,
    double radius,
    double scale,
    Offset screenCenter,
  ) {
    final gridPaint = Paint()
      ..color = const Color(0xFF263945)
      ..strokeWidth = 0.7;
    final extent = radius * 1.25;
    final spacing = extent / 5;
    for (var index = -5; index <= 5; index++) {
      final offset = spacing * index;
      final a = _project(
        Vec3(center.x - extent, center.y + offset, center.z),
        center,
        scale,
        screenCenter,
      );
      final b = _project(
        Vec3(center.x + extent, center.y + offset, center.z),
        center,
        scale,
        screenCenter,
      );
      canvas.drawLine(a.point, b.point, gridPaint);
      final c = _project(
        Vec3(center.x + offset, center.y - extent, center.z),
        center,
        scale,
        screenCenter,
      );
      final d = _project(
        Vec3(center.x + offset, center.y + extent, center.z),
        center,
        scale,
        screenCenter,
      );
      canvas.drawLine(c.point, d.point, gridPaint);
    }
  }

  _Projection _project(
      Vec3 vertex, Vec3 center, double scale, Offset screenCenter) {
    final local = vertex - center;
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final x1 = cosYaw * local.x + sinYaw * local.z;
    final z1 = -sinYaw * local.x + cosYaw * local.z;
    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final y2 = cosPitch * local.y - sinPitch * z1;
    final z2 = sinPitch * local.y + cosPitch * z1;
    return _Projection(
      screenCenter + Offset(x1 * scale, -y2 * scale),
      z2,
    );
  }

  double _faceDepth(MeshFace face, List<_Projection> vertices) {
    var depth = 0.0;
    for (final index in face.indices) {
      if (index >= 0 && index < vertices.length) depth += vertices[index].depth;
    }
    return face.indices.isEmpty ? 0 : depth / face.indices.length;
  }

  Vec3 _normal(MeshFace face, Vec3 center) {
    if (face.indices.length < 3) return const Vec3(0, 0, 1);
    final first = mesh.vertices[face.indices[0]] - center;
    final second = mesh.vertices[face.indices[1]] - center;
    final third = mesh.vertices[face.indices[2]] - center;
    return (second - first).cross(third - first).normalized;
  }

  void _drawSelectedVertices(
    Canvas canvas,
    List<_Projection> projectedVertices,
  ) {
    final indexes = <int>{};
    for (final id in selectedVertexIds) {
      final numeric = int.tryParse(id);
      if (numeric != null &&
          numeric >= 0 &&
          numeric < projectedVertices.length) {
        indexes.add(numeric);
        continue;
      }
      final vertexIndex = mesh.vertexIds.indexOf(id);
      if (vertexIndex >= 0) indexes.add(vertexIndex);
    }
    if (indexes.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFFFFC857)
      ..style = PaintingStyle.fill;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final index in indexes) {
      final point = projectedVertices[index].point;
      canvas.drawCircle(point, 5, paint);
      canvas.drawCircle(point, 5, ring);
    }
  }

  void _drawAxes(
    Canvas canvas,
    Vec3 center,
    double radius,
    double scale,
    Offset screenCenter,
  ) {
    final length = radius * 0.34;
    final origin = _project(center, center, scale, screenCenter).point;
    final axes = [
      (Vec3(length, 0, 0), const Color(0xFFFF6B6B), 'X'),
      (Vec3(0, length, 0), const Color(0xFF56D364), 'Y'),
      (Vec3(0, 0, length), const Color(0xFF58A6FF), 'Z'),
    ];
    for (final axis in axes) {
      final endpoint =
          _project(center + axis.$1, center, scale, screenCenter).point;
      canvas.drawLine(
        origin,
        endpoint,
        Paint()
          ..color = axis.$2
          ..strokeWidth = 2,
      );
      _paintText(canvas, axis.$3, endpoint + const Offset(4, -5), axis.$2, 11);
    }
  }

  void _drawBounds(Canvas canvas, List<_Projection> vertices, Size size) {
    if (vertices.isEmpty) return;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final vertex in vertices) {
      minX = math.min(minX, vertex.point.dx);
      minY = math.min(minY, vertex.point.dy);
      maxX = math.max(maxX, vertex.point.dx);
      maxY = math.max(maxY, vertex.point.dy);
    }
    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY).deflate(7);
    canvas.drawRect(
      bounds,
      Paint()
        ..color = const Color(0x667F9AAA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final min = mesh.minimum;
    final max = mesh.maximum;
    final label =
        'BBox ${formatNumber(min.x)}…${formatNumber(max.x)} X · ${formatNumber(min.y)}…${formatNumber(max.y)} Y · ${formatNumber(min.z)}…${formatNumber(max.z)} Z ${mesh.units}';
    final painter = _textPainter(
      label,
      const Color(0xFFB9CAD3),
      fontSize: 10,
    );
    var dx = bounds.left;
    var dy = bounds.top - painter.height - 2;
    if (dy < 0) dy = bounds.top + 3;
    if (dx + painter.width > size.width) dx = size.width - painter.width;
    painter.paint(canvas, Offset(dx, dy));
  }

  TextPainter _textPainter(
    String text,
    Color color, {
    double fontSize = 11,
    FontWeight weight = FontWeight.w700,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter;
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize,
  ) {
    final painter = _textPainter(text, color, fontSize: fontSize);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.mesh != mesh ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan ||
        oldDelegate.selectedBodyId != selectedBodyId ||
        oldDelegate.selectedFaceIds != selectedFaceIds ||
        oldDelegate.selectedVertexIds != selectedVertexIds ||
        oldDelegate.showAxes != showAxes ||
        oldDelegate.showBoundingBox != showBoundingBox;
  }
}

class _Projection {
  const _Projection(this.point, this.depth);

  final Offset point;
  final double depth;
}
