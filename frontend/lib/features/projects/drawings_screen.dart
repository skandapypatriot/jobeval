import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class DrawingsScreen extends ConsumerStatefulWidget {
  const DrawingsScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<DrawingsScreen> createState() => _DrawingsScreenState();
}

class _DrawingsScreenState extends ConsumerState<DrawingsScreen> {
  bool _parsing = false;

  @override
  Widget build(BuildContext context) {
    final drawings = ref.watch(drawingsProvider(widget.projectId));
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Drawing annotations',
            subtitle:
                'Original text is kept beside normalized values, units, tolerance, confidence, and source locations.',
            actions: [
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(drawingsProvider(widget.projectId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: _parsing ? null : _parse,
                icon: _parsing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(_parsing ? 'Parsing…' : 'Parse drawings'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          drawings.when(
            loading: () => const SizedBox(
              height: 340,
              child: LoadingPanel(label: 'Loading drawing annotations…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Drawing annotations could not be loaded',
              message: apiErrorMessage(error),
              onRetry: () => ref.invalidate(drawingsProvider(widget.projectId)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyPanel(
                  title: 'No drawing annotations',
                  message:
                      'Upload a PDF or DXF file, then parse the drawing to extract pages and annotations.',
                  icon: Icons.description_outlined,
                  action: FilledButton.icon(
                    onPressed: _parsing ? null : _parse,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Parse drawings'),
                  ),
                );
              }
              return Column(
                children: items.asMap().entries.map((entry) {
                  final page = _DrawingPage.fromJson(
                    entry.value,
                    fallbackNumber: entry.key + 1,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _DrawingPageCard(page: page),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _parse() async {
    setState(() => _parsing = true);
    try {
      final response =
          await ref.read(apiClientProvider).parseDrawings(widget.projectId);
      ref.invalidate(drawingsProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Drawing parse ${JsonData.status(response, fallback: 'completed')}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }
}

class _DrawingPageCard extends StatelessWidget {
  const _DrawingPageCard({required this.page});

  final _DrawingPage page;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Page ${page.number}',
      subtitle:
          '${page.annotations.length} extracted annotation${page.annotations.length == 1 ? '' : 's'} · ${page.rawText.length} raw text item${page.rawText.length == 1 ? '' : 's'}',
      leading: const Icon(Icons.find_in_page_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page.width != null || page.height != null || page.unit.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 18,
                children: [
                  if (page.width != null)
                    Text('Width: ${formatNumber(page.width!)} ${page.unit}'),
                  if (page.height != null)
                    Text('Height: ${formatNumber(page.height!)} ${page.unit}'),
                ],
              ),
            ),
          if (page.annotations.isEmpty)
            const Text('No structured annotations were returned for this page.')
          else
            Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 42,
                  dataRowMinHeight: 54,
                  dataRowMaxHeight: 88,
                  columns: const [
                    DataColumn(label: Text('Type / ID')),
                    DataColumn(label: Text('Original text')),
                    DataColumn(label: Text('Normalized value')),
                    DataColumn(label: Text('Tolerance')),
                    DataColumn(label: Text('Confidence band')),
                    DataColumn(label: Text('Source')),
                  ],
                  rows: page.annotations.map((annotation) {
                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 135,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  annotation.type,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  annotation.id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              annotation.originalText.isEmpty
                                  ? 'Not supplied'
                                  : annotation.originalText,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 145,
                            child: Text(
                              annotation.normalizedValue.isEmpty
                                  ? 'Not supplied'
                                  : '${annotation.normalizedValue} ${annotation.unit}',
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              annotation.tolerance.isEmpty
                                  ? 'Not supplied'
                                  : annotation.tolerance,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 130,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StatusPill(
                                  label: annotation.confidenceBand,
                                  tone: _confidenceTone(
                                      context, annotation.confidence),
                                ),
                                if (annotation.confidence != null)
                                  Text(
                                    '${formatNumber(annotation.confidence!, decimals: 3)} score',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Page ${annotation.sourcePage}'),
                                Text(
                                  annotation.bbox.isEmpty
                                      ? 'BBox not supplied'
                                      : 'BBox ${annotation.bbox}',
                                  style: Theme.of(context).textTheme.labelSmall,
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
            ),
          if (page.rawText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Original text',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(7),
              ),
              child: SelectableText(page.rawText.join('\n')),
            ),
          ],
        ],
      ),
    );
  }

  Color _confidenceTone(BuildContext context, double? confidence) {
    final scheme = Theme.of(context).colorScheme;
    if (confidence == null) return scheme.onSurfaceVariant;
    if (confidence < 0.5) return scheme.error;
    if (confidence < 0.75) return scheme.secondary;
    return scheme.tertiary;
  }
}

class _DrawingPage {
  const _DrawingPage({
    required this.number,
    required this.width,
    required this.height,
    required this.unit,
    required this.annotations,
    required this.rawText,
  });

  factory _DrawingPage.fromJson(JsonMap json, {required int fallbackNumber}) {
    final annotations = <_DrawingAnnotation>[];
    final direct = JsonData.firstMaps(json, const [
      'annotations',
      'extracted_annotations',
      'dimensions',
      'items',
    ]);
    for (final annotation in direct) {
      annotations.add(_DrawingAnnotation.fromJson(annotation));
    }
    for (final key in const [
      'gdt',
      'gd_t',
      'surface_finish',
      'notes',
      'title_block',
    ]) {
      final nested = json[key];
      if (nested is List) {
        for (final item in nested) {
          if (item is Map) {
            final map = JsonData.map(item);
            map['type'] ??= key;
            annotations.add(_DrawingAnnotation.fromJson(map));
          }
        }
      }
    }
    final rawText = <String>[];
    final raw = json['raw_text'];
    if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          rawText.add(item);
        } else if (item is Map) {
          final text = JsonData.text(item['text'] ?? item['content']);
          if (text.isNotEmpty) rawText.add(text);
        }
      }
    } else if (raw is String) {
      rawText.add(raw);
    }
    return _DrawingPage(
      number: JsonData.integer(
        json['page_num'] ?? json['page_number'] ?? json['number'],
        fallback: fallbackNumber,
      ),
      width: json['width'] == null ? null : JsonData.number(json['width']),
      height: json['height'] == null ? null : JsonData.number(json['height']),
      unit: JsonData.text(json['unit'] ?? json['units']),
      annotations: annotations,
      rawText: rawText,
    );
  }

  final int number;
  final double? width;
  final double? height;
  final String unit;
  final List<_DrawingAnnotation> annotations;
  final List<String> rawText;
}

class _DrawingAnnotation {
  const _DrawingAnnotation({
    required this.id,
    required this.type,
    required this.originalText,
    required this.normalizedValue,
    required this.unit,
    required this.tolerance,
    required this.confidence,
    required this.sourcePage,
    required this.bbox,
  });

  factory _DrawingAnnotation.fromJson(JsonMap json) {
    final toleranceValue = json['tolerance'];
    final tolerance = toleranceValue is Map
        ? toleranceValue.entries
            .map((entry) => '${humanizeKey(entry.key)}: ${entry.value}')
            .join(', ')
        : JsonData.text(toleranceValue);
    final bboxValue = json['bbox'] ?? json['bounding_box'] ?? json['position'];
    final bbox = bboxValue is List
        ? bboxValue
            .map((value) => formatNumber(JsonData.number(value)))
            .join(', ')
        : JsonData.text(bboxValue);
    final confidence =
        json['confidence'] == null ? null : JsonData.number(json['confidence']);
    return _DrawingAnnotation(
      id: JsonData.text(json['id'] ?? json['annotation_id']),
      type: JsonData.text(json['type'] ?? json['kind'], fallback: 'annotation'),
      originalText: JsonData.text(
        json['original_text'] ?? json['raw_text'] ?? json['text'],
      ),
      normalizedValue: JsonData.text(
        json['normalized_value'] ?? json['value'] ?? json['normalized'],
      ),
      unit: JsonData.text(json['unit'] ?? json['units']),
      tolerance: tolerance,
      confidence: confidence,
      sourcePage: JsonData.integer(
        json['source_page'] ?? json['page'] ?? json['page_num'],
        fallback: 1,
      ),
      bbox: bbox,
    );
  }

  final String id;
  final String type;
  final String originalText;
  final String normalizedValue;
  final String unit;
  final String tolerance;
  final double? confidence;
  final int sourcePage;
  final String bbox;

  String get confidenceBand {
    if (confidence == null) return 'Not scored';
    if (confidence! < 0.5) return 'Low band';
    if (confidence! < 0.75) return 'Medium band';
    return 'High band';
  }
}
