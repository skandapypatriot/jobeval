import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';

class CncAnalysisScreen extends ConsumerStatefulWidget {
  final String projectId;

  const CncAnalysisScreen({super.key, required this.projectId});

  @override
  ConsumerState<CncAnalysisScreen> createState() => _CncAnalysisScreenState();
}

class _CncAnalysisScreenState extends ConsumerState<CncAnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CNC Manufacturing Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<ManufacturingAnalysis>(
        future: ref.watch(manufacturingAnalysisProvider(widget.projectId).future),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final analysis = snapshot.data!;
          if (analysis.operations.isEmpty) {
            return EmptyState(
              icon: Icons.factory_outlined,
              title: 'No Manufacturing Data',
              message: 'Run CNC analysis to see setup plans and operations.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary stats
                _buildSummaryStats(analysis, theme, colorScheme),
                const SizedBox(height: 24),

                // Setups
                _buildSectionHeader('Machining Setups', Icons.factory, theme),
                const SizedBox(height: 12),
                ...analysis.setups.map((s) => _buildSetupCard(s, theme, colorScheme)).toList(),
                const SizedBox(height: 24),

                // Operations
                _buildSectionHeader('Operations', Icons.build, theme),
                const SizedBox(height: 12),
                ...analysis.operations.map((op) => _buildOperationCard(op, theme, colorScheme)).toList(),
                const SizedBox(height: 24),

                // Warnings
                if (analysis.warnings.isNotEmpty) ...[
                  _buildSectionHeader('Warnings', Icons.warning, theme),
                  const SizedBox(height: 12),
                  ...analysis.warnings.map((w) => _buildWarningCard(w, theme, colorScheme)).toList(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryStats(ManufacturingAnalysis a, ThemeData t, ColorScheme c) {
    return Row(
      children: [
        _buildStatCard(
          'Total Time',
          '${a.totalEstimatedTimeMin.toInt()} min',
          Icons.access_time,
          c.primary,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Setups',
          '${a.setups.length}',
          Icons.factory,
          c.tertiary,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Operations',
          '${a.operations.length}',
          Icons.build,
          c.secondary,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Difficulty',
          a.machiningDifficulty.toUpperCase(),
          Icons.rule,
          _getDifficultyColor(a.machiningDifficulty, c),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: t.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSetupCard(Setup s, ThemeData theme, ColorScheme c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.factory, color: c.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.setupId,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        s.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${s.features.length} features',
                    style: TextStyle(
                      color: c.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDetailChip('Orientation', '(${s.orientation.x.toStringAsFixed(1)}, ${s.orientation.y.toStringAsFixed(1)}, ${s.orientation.z.toStringAsFixed(1)})', theme),
                const SizedBox(width: 8),
                _buildDetailChip('Origin', '(${s.origin.x.toStringAsFixed(1)}, ${s.origin.y.toStringAsFixed(1)}, ${s.origin.z.toStringAsFixed(1)})', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard(Operation op, ThemeData theme, ColorScheme c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getOpIcon(op.operationType), color: c.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        op.operationType.name.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        op.toolCategory.name.toUpperCase().replaceAll('_', ' '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(op.confidence).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(op.confidence * 100).toInt()}%',
                    style: TextStyle(
                      color: _getConfidenceColor(op.confidence),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDetailChip('Time', '${op.estimatedTimeMin.toInt()} min', theme),
                const SizedBox(width: 8),
                _buildDetailChip('Setup', op.setupId, theme),
                if (op.toolDiameter != null) ...[
                  const SizedBox(width: 8),
                  _buildDetailChip('Tool Ø', '${op.toolDiameter!.toStringAsFixed(1)} mm', theme),
                ],
              ],
            ),
            if (op.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning, size: 16, color: c.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      op.warnings.first,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard(String w, ThemeData theme, ColorScheme c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning, color: c.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                w,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
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

  Color _getDifficultyColor(String difficulty, ColorScheme c) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.amber;
      case 'hard':
        return Colors.orange;
      case 'very_hard':
        return c.error;
      default:
        return c.onSurfaceVariant;
    }
  }

  IconData _getOpIcon(OperationType type) {
    switch (type) {
      case OperationType.DRILLING:
        return Icons.circle;
      case OperationType.POCKET_MILLING:
        return Icons.crop_square;
      case OperationType.SLOT_MILLING:
        return Icons.sports_score;
      case OperationType.PROFILE_MILLING:
        return Icons.layers;
      case OperationType.FACE_MILLING:
        return Icons.layers;
      case OperationType.CHAMFERING:
        return Icons.border_all;
      case OperationType.TAPPING:
        return Icons.build;
      case OperationType.BORING:
        return Icons.circle_outlined;
      case OperationType.COUNTERBORING:
        return Icons.circle;
      case OperationType.COUNTERSINKING:
        return Icons.trip_origin;
      case OperationType.REAMING:
        return Icons.circle_outlined;
      case OperationType.INSPECTION:
        return Icons.visibility;
      default:
        return Icons.build;
    }
  }
}