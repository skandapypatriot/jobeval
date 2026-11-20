import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';
import 'package:jobeval/shared/widgets/empty_state.dart';

class DrawingAnalysisScreen extends ConsumerStatefulWidget {
  final String projectId;

  const DrawingAnalysisScreen({super.key, required this.projectId});

  @override
  ConsumerState<DrawingAnalysisScreen> createState() => _DrawingAnalysisScreenState();
}

class _DrawingAnalysisScreenState extends ConsumerState<DrawingAnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<DrawingAnnotations>(
        future: ref.watch(drawingAnnotationsProvider(widget.projectId).future),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final annotations = snapshot.data!;
          if (annotations.pages.isEmpty) {
            return EmptyState(
              icon: Icons.description_outlined,
              title: 'No Drawing Data',
              message: 'Upload a PDF or DXF drawing to extract annotations.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: annotations.pages.length,
            itemBuilder: (context, index) {
              final page = annotations.pages[index];
              return _buildPageCard(page, theme, colorScheme);
            },
          );
        },
      ),
    );
  }

  Widget _buildPageCard(DrawingPage page, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Page ${page.pageNum}',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${page.dimensions.length} dimensions, ${page.gdT.length} GD&T, ${page.notes.length} notes',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dimensions
                if (page.dimensions.isNotEmpty) ...[
                  _buildSectionHeader('Dimensions', Icons.straighten, theme),
                  const SizedBox(height: 8),
                  ...page.dimensions.map((d) => _buildDimensionRow(d, theme)).toList(),
                  const SizedBox(height: 16),
                ],

                // GD&T
                if (page.gdT.isNotEmpty) ...[
                  _buildSectionHeader('GD&T', Icons.strikethrough_s, theme),
                  const SizedBox(height: 8),
                  ...page.gdT.map((g) => _buildGDTRow(g, theme)).toList(),
                  const SizedBox(height: 16),
                ],

                // Surface Finish
                if (page.surfaceFinish.isNotEmpty) ...[
                  _buildSectionHeader('Surface Finish', Icons.layers, theme),
                  const SizedBox(height: 8),
                  ...page.surfaceFinish.map((s) => _buildSurfaceFinishRow(s, theme)).toList(),
                  const SizedBox(height: 16),
                ],

                // Notes
                if (page.notes.isNotEmpty) ...[
                  _buildSectionHeader('Notes', Icons.note, theme),
                  const SizedBox(height: 8),
                  ...page.notes.map((n) => _buildNoteRow(n, theme)).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionRow(DrawingDimension d, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              d.type.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.text,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${d.value.toStringAsFixed(2)} ${d.unit.toUpperCase()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getConfidenceColor(d.confidence).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(d.confidence * 100).toInt()}%',
              style: TextStyle(
                color: _getConfidenceColor(d.confidence),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGDTRow(GDTAnnotation g, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.strikethrough_s, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.type.toUpperCase(),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (g.value != null)
                  Text(
                    '${g.value?.toStringAsFixed(2) ?? '0'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (g.datums.isNotEmpty)
                  Text(
                    'Datums: ${g.datums.join(', ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getConfidenceColor(g.confidence).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(g.confidence * 100).toInt()}%',
              style: TextStyle(
                color: _getConfidenceColor(g.confidence),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurfaceFinishRow(SurfaceFinishAnnotation s, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.layers, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.text,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  s.ra != null ? 'Ra ${s.ra!.toStringAsFixed(2)}' : s.symbol,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteRow(DrawingNote n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.note, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.category.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  n.text,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.amber;
    return Colors.red;
  }
}