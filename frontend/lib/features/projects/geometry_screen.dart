import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/api/api_exception.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/mesh_model.dart';
import 'package:jobeval/core/models/project_models.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';
import 'package:jobeval/shared/widgets/mesh_viewer.dart';

class GeometryScreen extends ConsumerStatefulWidget {
  const GeometryScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<GeometryScreen> createState() => _GeometryScreenState();
}

class _GeometryScreenState extends ConsumerState<GeometryScreen> {
  String? _selectedFeatureId;
  String? _selectedBodyId;
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final analysis = ref.watch(analysisProvider(widget.projectId));
    final features = ref.watch(featuresProvider(widget.projectId));

    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Geometry & 3D review',
            subtitle:
                'Only triangulated geometry returned by the backend is rendered; no placeholder CAD model is shown.',
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(analysisProvider(widget.projectId));
                  ref.invalidate(featuresProvider(widget.projectId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: _starting ? null : _startAnalysis,
                icon: _starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.architecture_outlined),
                label: Text(_starting ? 'Starting…' : 'Run analysis'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          analysis.when(
            loading: () => const SizedBox(
              height: 420,
              child: LoadingPanel(label: 'Loading triangulated geometry…'),
            ),
            error: (error, _) {
              if (error is ApiException && error.statusCode == 404) {
                return EmptyPanel(
                  title: 'No geometry analysis yet',
                  message:
                      'Run analysis after uploading a model. The viewer will remain empty until real mesh data is available.',
                  icon: Icons.view_in_ar_outlined,
                  action: FilledButton.icon(
                    onPressed: _starting ? null : _startAnalysis,
                    icon: const Icon(Icons.architecture_outlined),
                    label: const Text('Run analysis'),
                  ),
                );
              }
              return ErrorPanel(
                title: 'Geometry could not be loaded',
                message: apiErrorMessage(error),
                onRetry: () =>
                    ref.invalidate(analysisProvider(widget.projectId)),
              );
            },
            data: (data) {
              final mesh = TriMesh.fromAnalysis(data);
              if (mesh.isEmpty) {
                return EmptyPanel(
                  title: 'No triangulated mesh in the analysis response',
                  message:
                      'The analysis request succeeded, but no vertices and triangular faces were returned. Nothing is being rendered in their place.',
                  icon: Icons.data_array_outlined,
                  action: OutlinedButton.icon(
                    onPressed: () =>
                        ref.invalidate(analysisProvider(widget.projectId)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check analysis again'),
                  ),
                );
              }
              return _GeometryContent(
                projectId: widget.projectId,
                analysis: data,
                mesh: mesh,
                features: features.valueOrNull ?? const <JsonMap>[],
                selectedFeatureId: _selectedFeatureId,
                selectedBodyId: _selectedBodyId,
                onFeatureSelected: (id) =>
                    setState(() => _selectedFeatureId = id),
                onBodySelected: (id) => setState(() => _selectedBodyId = id),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startAnalysis() async {
    setState(() => _starting = true);
    try {
      final response =
          await ref.read(apiClientProvider).startAnalysis(widget.projectId);
      ref.invalidate(analysisProvider(widget.projectId));
      ref.invalidate(featuresProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Analysis request ${JsonData.status(response, fallback: 'submitted')}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

class _GeometryContent extends StatelessWidget {
  const _GeometryContent({
    required this.projectId,
    required this.analysis,
    required this.mesh,
    required this.features,
    required this.selectedFeatureId,
    required this.selectedBodyId,
    required this.onFeatureSelected,
    required this.onBodySelected,
  });

  final String projectId;
  final JsonMap analysis;
  final TriMesh mesh;
  final List<JsonMap> features;
  final String? selectedFeatureId;
  final String? selectedBodyId;
  final ValueChanged<String?> onFeatureSelected;
  final ValueChanged<String?> onBodySelected;

  @override
  Widget build(BuildContext context) {
    final records = features.map(FeatureRecord.fromJson).toList();
    FeatureRecord? selected;
    for (final record in records) {
      if (record.id == selectedFeatureId) {
        selected = record;
        break;
      }
    }
    final bodyOptions = <String>{
      ...mesh.bodyIds,
      ...records.map((feature) => feature.bodyId).where((id) => id.isNotEmpty),
    }.toList()
      ..sort();
    final selectedFaces = selected?.faceIds.toSet() ?? <String>{};
    final selectedVertices = selected?.vertexIds.toSet() ?? <String>{};
    final effectiveBody =
        selected?.bodyId.isNotEmpty == true ? selected!.bodyId : selectedBodyId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              label: 'Vertices',
              value: '${mesh.vertices.length}',
              icon: Icons.blur_on_outlined,
            ),
            MetricCard(
              label: 'Triangles',
              value: '${mesh.faces.length}',
              icon: Icons.change_history_outlined,
            ),
            MetricCard(
              label: 'Bodies',
              value: '${bodyOptions.length}',
              icon: Icons.category_outlined,
            ),
            MetricCard(
              label: 'Units',
              value: mesh.units,
              icon: Icons.straighten,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final viewer = SectionCard(
              title: 'Triangulated model',
              subtitle: 'Drag to orbit, wheel to zoom, or switch to pan mode.',
              leading: const Icon(Icons.view_in_ar_outlined),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: effectiveBody ?? '',
                  hint: const Text('All bodies'),
                  onChanged: (value) => onBodySelected(
                      value == null || value.isEmpty ? null : value),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All bodies'),
                    ),
                    ...bodyOptions.map(
                      (id) => DropdownMenuItem<String>(
                        value: id,
                        child: Text(id, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: SizedBox(
                height: 520,
                child: MeshViewer(
                  mesh: mesh,
                  selectedBodyId: effectiveBody,
                  selectedFaceIds: selectedFaces,
                  selectedVertexIds: selectedVertices,
                ),
              ),
            );
            final featurePanel = SectionCard(
              title: 'Feature mapping',
              subtitle:
                  'Select a row to highlight supplied face, body, and vertex mappings.',
              leading: const Icon(Icons.link_outlined),
              child: features.isEmpty
                  ? const Text(
                      'No feature mappings are available. Geometry is still rendered from the returned mesh.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selected != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${selected.type} · ${selected.id}\nFaces: ${selectedFaces.isEmpty ? 'not mapped' : selectedFaces.join(', ')}\nBody: ${selected.bodyId.isEmpty ? 'not mapped' : selected.bodyId}\nVertices: ${selectedVertices.isEmpty ? 'not mapped' : selectedVertices.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          height: 420,
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Feature')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Mapping')),
                                ],
                                rows: records.map((feature) {
                                  final mapped = feature.faceIds.isNotEmpty ||
                                      feature.bodyId.isNotEmpty ||
                                      feature.vertexIds.isNotEmpty;
                                  return DataRow(
                                    onSelectChanged: (_) =>
                                        onFeatureSelected(feature.id),
                                    selected: feature.id == selectedFeatureId,
                                    cells: [
                                      DataCell(Text(feature.id)),
                                      DataCell(Text(feature.type)),
                                      DataCell(
                                        Text(mapped
                                            ? 'Highlight'
                                            : 'Not mapped'),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  viewer,
                  const SizedBox(height: 16),
                  featurePanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: viewer),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: featurePanel),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Analysis payload',
          subtitle: 'Additional geometry values returned by the backend.',
          leading: const Icon(Icons.data_object),
          child: _AnalysisSummary(analysis: analysis, mesh: mesh),
        ),
      ],
    );
  }
}

class _AnalysisSummary extends StatelessWidget {
  const _AnalysisSummary({required this.analysis, required this.mesh});

  final JsonMap analysis;
  final TriMesh mesh;

  @override
  Widget build(BuildContext context) {
    final geometry = JsonData.firstMap(analysis, const [
      'geometry_summary',
      'geometry',
      'summary',
    ]);
    final entries = <MapEntry<String, dynamic>>[
      ...geometry.entries,
      if (analysis['units'] != null && !geometry.containsKey('units'))
        MapEntry('units', analysis['units']),
      if (analysis['job_id'] != null) MapEntry('job_id', analysis['job_id']),
    ].where((entry) => entry.value is num || entry.value is String).toList();
    if (entries.isEmpty) {
      return Text(
        'No scalar geometry summary fields were returned. The viewer used ${mesh.vertices.length} vertices and ${mesh.faces.length} triangles.',
      );
    }
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: entries.map((entry) {
        return SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                humanizeKey(entry.key),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              SelectableText(entry.value.toString()),
            ],
          ),
        );
      }).toList(),
    );
  }
}
