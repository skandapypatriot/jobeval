import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';
import 'package:jobeval/shared/widgets/empty_state.dart';

class FeatureRecognitionScreen extends ConsumerStatefulWidget {
  final String projectId;

  const FeatureRecognitionScreen({super.key, required this.projectId});

  @override
  ConsumerState<FeatureRecognitionScreen> createState() => _FeatureRecognitionScreenState();
}

class _FeatureRecognitionScreenState extends ConsumerState<FeatureRecognitionScreen> {
  String _selectedType = 'All';

  final List<String> _featureTypes = [
    'All',
    'Through Hole',
    'Blind Hole',
    'Counterbore',
    'Countersink',
    'Fillet',
    'Chamfer',
    'Pocket',
    'Slot',
    'Step',
    'Shoulder',
    'Boss',
    'Rib',
    'Fillet',
    'Groove',
    'Thread',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Recognition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Features',
          ),
        ],
      ),
      body: FutureBuilder<CadSpecs>(
        future: ref.watch(cadSpecsProvider(widget.projectId).future),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final specs = snapshot.data!;
          final features = specs.features.where((f) {
            if (_selectedType == 'All') return true;
            return f.type.name.replaceAll('_', ' ').toLowerCase().contains(
              _selectedType.toLowerCase(),
            );
          }).toList();

          if (features.isEmpty) {
            return EmptyState(
              icon: Icons.architecture_outlined,
              title: 'No Features Detected',
              message: 'No manufacturing features were recognized in this model.',
            );
          }

          return Column(
            children: [
              // Summary stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildStatCard(
                      'Total Features',
                      features.length.toString(),
                      Icons.architecture,
                      colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'High Confidence',
                      features.where((f) => f.confidence > 0.8).length.toString(),
                      Icons.check_circle,
                      colorScheme.tertiary,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Patterns',
                      specs.featureRelationships
                          .where((r) => r.type == 'pattern')
                          .length
                          .toString(),
                      Icons.layers,
                      colorScheme.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filter chips
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _featureTypes.length,
                  itemBuilder: (context, index) {
                    final type = _featureTypes[index];
                    final isSelected = _selectedType == type;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(type),
                      onSelected: (selected) => setState(() => _selectedType = type),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Feature list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    final feature = features[index];
                    return _buildFeatureCard(feature, theme, colorScheme);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Feature feature, ThemeData theme, ColorScheme colorScheme) {
    final confidenceColor = _getConfidenceColor(feature.confidence);
    final typeDisplay = feature.type.name.replaceAll('_', ' ').toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
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
                    color: confidenceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFeatureIcon(feature.type),
                    color: confidenceColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeDisplay,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (feature.subtype != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          feature.subtype!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(feature.confidence * 100).toInt()}%',
                    style: TextStyle(
                      color: confidenceColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dimensions
            if (_hasDimensions(feature.dimensions)) ...[
              Row(
                children: [
                  _buildDimensionChip('Ø', '${feature.dimensions.diameter?.toStringAsFixed(2) ?? '-'} mm', theme),
                  if (feature.dimensions.depth != null) ...[
                    const SizedBox(width: 8),
                    _buildDimensionChip('↓', '${feature.dimensions.depth!.toStringAsFixed(2)} mm', theme),
                  ],
                  if (feature.dimensions.width != null) ...[
                    const SizedBox(width: 8),
                    _buildDimensionChip('↔', '${feature.dimensions.width!.toStringAsFixed(2)} mm', theme),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Details
            Row(
              children: [
                _buildDetailChip('Through', feature.through ? 'Yes' : 'No', theme),
                const SizedBox(width: 8),
                _buildDetailChip('Open', feature.open ? 'Yes' : 'No', theme),
                const SizedBox(width: 8),
                if (feature.patternGroup != null) ...[
                  _buildDetailChip('Pattern', feature.patternGroup!, theme),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Detection method
            if (feature.detectionMethod != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  feature.detectionMethod!.replaceAll('_', ' '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasDimensions(FeatureDimensions d) =>
      d.diameter != null || d.depth != null || d.width != null ||
      d.length != null || d.height != null || d.radius != null;

  Widget _buildDimensionChip(String icon, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: theme.textTheme.labelSmall),
          const SizedBox(width: 4),
          Text(value, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
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
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
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

  IconData _getFeatureIcon(FeatureType type) {
    switch (type) {
      case FeatureType.throughHole:
      case FeatureType.blindHole:
      case FeatureType.counterbore:
      case FeatureType.countersink:
        return Icons.circle;
      case FeatureType.fillet:
      case FeatureType.roundedCorner:
        return Icons.rounded_corner;
      case FeatureType.chamfer:
        return Icons.border_all;
      case FeatureType.rectangularPocket:
      case FeatureType.circularPocket:
      case FeatureType.complexPocket:
        return Icons.crop_square;
      case FeatureType.openSlot:
      case FeatureType.closedSlot:
        return Icons.sports_score;
      case FeatureType.step:
      case FeatureType.shoulder:
        return Icons.layers;
      case FeatureType.boss:
        return Icons.lens;
      case FeatureType.rib:
        return Icons.layers_clear;
      default:
        return Icons.architecture;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Features'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _featureTypes.map((type) => ListTile(
            leading: Radio<String>(
              value: type,
              groupValue: _selectedType,
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            title: Text(type),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}