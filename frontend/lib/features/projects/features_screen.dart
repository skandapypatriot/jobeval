import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/project_models.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class FeaturesScreen extends ConsumerStatefulWidget {
  const FeaturesScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends ConsumerState<FeaturesScreen> {
  bool _lowConfidenceOnly = false;
  String _reviewFilter = 'all';
  String? _savingFeatureId;

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresProvider(widget.projectId));
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Feature review',
            subtitle:
                'Review geometry-derived records. Confidence bands are heuristic review aids, not measured precision.',
            actions: [
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(featuresProvider(widget.projectId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          features.when(
            loading: () => const SizedBox(
              height: 360,
              child: LoadingPanel(label: 'Loading feature records…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Features could not be loaded',
              message: apiErrorMessage(error),
              onRetry: () => ref.invalidate(featuresProvider(widget.projectId)),
            ),
            data: (items) {
              final records = items.map(FeatureRecord.fromJson).toList();
              final filtered = records.where((feature) {
                if (_lowConfidenceOnly &&
                    (feature.confidence == null ||
                        feature.confidence! >= 0.5)) {
                  return false;
                }
                if (_reviewFilter != 'all') {
                  final normalized = feature.reviewStatus
                      .toLowerCase()
                      .replaceAll(' ', '_')
                      .replaceAll('-', '_');
                  return normalized == _reviewFilter;
                }
                return true;
              }).toList();
              return Column(
                children: [
                  SectionCard(
                    title: 'Review filters',
                    subtitle:
                        '${filtered.length} of ${records.length} records shown.',
                    leading: const Icon(Icons.filter_alt_outlined),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          selected: _lowConfidenceOnly,
                          avatar: const Icon(Icons.warning_amber_outlined,
                              size: 17),
                          label: const Text('Low confidence band (< 0.50)'),
                          onSelected: (value) =>
                              setState(() => _lowConfidenceOnly = value),
                        ),
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<String>(
                            initialValue: _reviewFilter,
                            decoration: const InputDecoration(
                              labelText: 'Review status',
                              prefixIcon: Icon(Icons.fact_check_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All statuses')),
                              DropdownMenuItem(
                                value: 'needs_review',
                                child: Text('Needs review'),
                              ),
                              DropdownMenuItem(
                                value: 'confirmed',
                                child: Text('Confirmed'),
                              ),
                              DropdownMenuItem(
                                value: 'corrected',
                                child: Text('Corrected'),
                              ),
                              DropdownMenuItem(
                                value: 'manual',
                                child: Text('Manual'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _reviewFilter = value ?? 'all',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Feature records',
                    subtitle:
                        'Source labels identify backend, default, inferred, or user-edited values.',
                    leading: const Icon(Icons.table_rows_outlined),
                    child: filtered.isEmpty
                        ? EmptyPanel(
                            title: records.isEmpty
                                ? 'No features available'
                                : 'No records match these filters',
                            message: records.isEmpty
                                ? 'The backend returned no feature records for this project.'
                                : 'Clear a filter to review the remaining records.',
                            icon: Icons.architecture_outlined,
                          )
                        : _FeatureTable(
                            records: filtered,
                            savingFeatureId: _savingFeatureId,
                            onConfirm: (feature) => _patch(
                              feature,
                              {'review_status': 'confirmed'},
                            ),
                            onCorrect: (feature) => _edit(feature, 'corrected'),
                            onManual: (feature) => _edit(feature, 'manual'),
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _patch(
    FeatureRecord feature,
    JsonMap changes,
  ) async {
    setState(() => _savingFeatureId = feature.id);
    try {
      final response = await ref.read(apiClientProvider).updateFeature(
            widget.projectId,
            feature.id,
            changes,
          );
      ref.invalidate(featuresProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${feature.id} updated: ${JsonData.status(response, fallback: 'saved')}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _savingFeatureId = null);
    }
  }

  Future<void> _edit(FeatureRecord feature, String initialStatus) async {
    final changes = await showDialog<JsonMap>(
      context: context,
      builder: (context) => _FeatureEditDialog(
        feature: feature,
        initialStatus: initialStatus,
      ),
    );
    if (changes == null || !mounted) return;
    await _patch(feature, changes);
  }
}

class _FeatureTable extends StatelessWidget {
  const _FeatureTable({
    required this.records,
    required this.savingFeatureId,
    required this.onConfirm,
    required this.onCorrect,
    required this.onManual,
  });

  final List<FeatureRecord> records;
  final String? savingFeatureId;
  final ValueChanged<FeatureRecord> onConfirm;
  final ValueChanged<FeatureRecord> onCorrect;
  final ValueChanged<FeatureRecord> onManual;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 86,
          columns: const [
            DataColumn(label: Text('ID / type')),
            DataColumn(label: Text('Dimensions')),
            DataColumn(label: Text('Depth')),
            DataColumn(label: Text('Axis')),
            DataColumn(label: Text('Confidence band')),
            DataColumn(label: Text('Evidence / reason')),
            DataColumn(label: Text('Review / source')),
            DataColumn(label: Text('Actions')),
          ],
          rows: records.map((feature) {
            final saving = savingFeatureId == feature.id;
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.id,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          feature.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                    SizedBox(width: 170, child: Text(_dimensions(feature)))),
                DataCell(
                  SizedBox(
                    width: 95,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feature.depthType),
                        Text(feature.through
                            ? 'through = true'
                            : 'through = false'),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 115,
                    child: Text(feature.axis?.toString() ?? 'Not supplied'),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 135,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(
                          label: feature.confidenceBand,
                          tone: _confidenceTone(context, feature.confidence),
                        ),
                        if (feature.confidence != null)
                          Text(
                              '${formatNumber(feature.confidence!, decimals: 3)} score'),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      feature.evidence.isEmpty
                          ? feature.reason.isEmpty
                              ? 'No evidence supplied'
                              : feature.reason
                          : feature.evidence.join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 185,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(label: feature.reviewStatus),
                        const SizedBox(height: 3),
                        Text('Source: ${feature.source}'),
                        Text(
                          'Provenance: ${_provenanceLabel(feature)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 145,
                    child: saving
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : PopupMenuButton<String>(
                            tooltip: 'Review ${feature.id}',
                            onSelected: (value) {
                              if (value == 'confirm') onConfirm(feature);
                              if (value == 'correct') onCorrect(feature);
                              if (value == 'manual') onManual(feature);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'confirm',
                                child: Text('Confirm as reviewed'),
                              ),
                              PopupMenuItem(
                                value: 'correct',
                                child: Text('Correct values'),
                              ),
                              PopupMenuItem(
                                value: 'manual',
                                child: Text('Mark as manual'),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _dimensions(FeatureRecord feature) {
    if (feature.dimensions.isEmpty) return 'Not supplied';
    return feature.dimensions.entries
        .where((entry) => entry.value is num || entry.value is String)
        .map((entry) => '${humanizeKey(entry.key)}: ${entry.value}')
        .join('\n');
  }

  String _provenanceLabel(FeatureRecord feature) {
    if (feature.provenance.isEmpty) return 'backend supplied';
    final values = feature.provenance.values
        .map((value) => value is Map
            ? JsonData.text(value['source'] ?? value['origin'])
            : JsonData.text(value))
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(', ');
    return values.isEmpty ? 'backend supplied' : values;
  }

  Color _confidenceTone(BuildContext context, double? confidence) {
    final scheme = Theme.of(context).colorScheme;
    if (confidence == null) return scheme.onSurfaceVariant;
    if (confidence < 0.5) return scheme.error;
    if (confidence < 0.75) return scheme.secondary;
    return scheme.tertiary;
  }
}

class _FeatureEditDialog extends StatefulWidget {
  const _FeatureEditDialog({
    required this.feature,
    required this.initialStatus,
  });

  final FeatureRecord feature;
  final String initialStatus;

  @override
  State<_FeatureEditDialog> createState() => _FeatureEditDialogState();
}

class _FeatureEditDialogState extends State<_FeatureEditDialog> {
  late final TextEditingController _type;
  late final TextEditingController _diameter;
  late final TextEditingController _width;
  late final TextEditingController _length;
  late final TextEditingController _depth;
  late final TextEditingController _axisX;
  late final TextEditingController _axisY;
  late final TextEditingController _axisZ;
  late final TextEditingController _reason;
  late String _depthType;
  late bool _through;
  late String _reviewStatus;

  @override
  void initState() {
    super.initState();
    final feature = widget.feature;
    _type = TextEditingController(text: feature.type);
    _diameter = TextEditingController(
      text: _number(feature.dimensions['diameter']),
    );
    _width = TextEditingController(text: _number(feature.dimensions['width']));
    _length =
        TextEditingController(text: _number(feature.dimensions['length']));
    _depth = TextEditingController(text: _number(feature.dimensions['depth']));
    final axis = feature.axis;
    _axisX =
        TextEditingController(text: axis == null ? '' : formatNumber(axis.x));
    _axisY =
        TextEditingController(text: axis == null ? '' : formatNumber(axis.y));
    _axisZ =
        TextEditingController(text: axis == null ? '' : formatNumber(axis.z));
    _reason = TextEditingController(text: feature.reason);
    final normalizedDepth =
        feature.depthType.toLowerCase().replaceAll('-', '_');
    _depthType = normalizedDepth == 'through'
        ? 'through'
        : normalizedDepth == 'blind'
            ? 'blind'
            : 'unknown';
    _through = feature.through;
    _reviewStatus = widget.initialStatus;
  }

  @override
  void dispose() {
    _type.dispose();
    _diameter.dispose();
    _width.dispose();
    _length.dispose();
    _depth.dispose();
    _axisX.dispose();
    _axisY.dispose();
    _axisZ.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Review ${widget.feature.id}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original source: ${widget.feature.source}. Saved edits are labeled as user-edited by review status and provenance returned by the API.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _type,
                decoration: const InputDecoration(labelText: 'Feature type'),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: TextField(
                          controller: _diameter,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Diameter'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: TextField(
                          controller: _width,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Width'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: TextField(
                          controller: _length,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Length'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: TextField(
                          controller: _depth,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Depth'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _depthType,
                decoration: const InputDecoration(labelText: 'Depth type'),
                items: const [
                  DropdownMenuItem(value: 'through', child: Text('Through')),
                  DropdownMenuItem(value: 'blind', child: Text('Blind')),
                  DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                ],
                onChanged: (value) =>
                    setState(() => _depthType = value ?? 'unknown'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Through feature'),
                value: _through,
                onChanged: (value) => setState(() => _through = value),
              ),
              const SizedBox(height: 6),
              Text('Axis', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _axisField(_axisX, 'X')),
                  const SizedBox(width: 8),
                  Expanded(child: _axisField(_axisY, 'Y')),
                  const SizedBox(width: 8),
                  Expanded(child: _axisField(_axisZ, 'Z')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Evidence / correction reason',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reviewStatus,
                decoration: const InputDecoration(labelText: 'Review status'),
                items: const [
                  DropdownMenuItem(
                    value: 'confirmed',
                    child: Text('Confirmed'),
                  ),
                  DropdownMenuItem(
                    value: 'corrected',
                    child: Text('Corrected'),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Manual'),
                  ),
                  DropdownMenuItem(
                    value: 'needs_review',
                    child: Text('Needs review'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _reviewStatus = value ?? 'needs_review'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save review'),
        ),
      ],
    );
  }

  Widget _axisField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: '$label axis'),
    );
  }

  void _save() {
    final dimensions = <String, dynamic>{};
    void putIfChanged(String key, TextEditingController controller) {
      final value = double.tryParse(controller.text.trim());
      if (value != null) dimensions[key] = value;
    }

    putIfChanged('diameter', _diameter);
    putIfChanged('width', _width);
    putIfChanged('length', _length);
    putIfChanged('depth', _depth);
    final axisValues = [
      double.tryParse(_axisX.text.trim()),
      double.tryParse(_axisY.text.trim()),
      double.tryParse(_axisZ.text.trim()),
    ];
    final axis = axisValues.every((value) => value != null)
        ? {
            'x': axisValues[0],
            'y': axisValues[1],
            'z': axisValues[2],
          }
        : null;
    Navigator.pop(context, {
      'type': _type.text.trim(),
      if (dimensions.isNotEmpty) 'dimensions': dimensions,
      'depth_type': _depthType,
      'through': _through,
      if (axis != null) 'axis': axis,
      if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      'review_status': _reviewStatus,
      'edited_by': 'user',
    });
  }

  String _number(dynamic value) {
    if (value is num) return formatNumber(value.toDouble());
    if (value is String) return value;
    return '';
  }
}
