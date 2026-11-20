import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';
import 'package:jobeval/shared/widgets/empty_state.dart';

class MaterialDatabaseScreen extends ConsumerStatefulWidget {
  final String projectId;

  const MaterialDatabaseScreen({super.key, required this.projectId});

  @override
  ConsumerState<MaterialDatabaseScreen> createState() => _MaterialDatabaseScreenState();
}

class _MaterialDatabaseScreenState extends ConsumerState<MaterialDatabaseScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Aluminum',
    'Steel',
    'Stainless',
    'Brass',
    'Copper',
    'Plastic',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showCategoryFilter,
            tooltip: 'Filter by Category',
          ),
        ],
      ),
      body: FutureBuilder<List<MaterialInfo>>(
        future: ref.watch(materialsProvider.future),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final materials = snapshot.data!;
          final filtered = _selectedCategory == 'All'
              ? materials
              : materials.where((m) => m.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_outlined,
              title: 'No Materials Found',
              message: 'No materials match the selected filter.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final material = filtered[index];
              return _buildMaterialCard(material, theme, colorScheme);
            },
          );
        },
      ),
    );
  }

  Widget _buildMaterialCard(MaterialInfo m, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showMaterialDetail(m, theme, colorScheme),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${m.name} ${m.grade ?? ''}'.trim(),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            m.category.toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.standard ?? 'No standard',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDetailChip('Density', '${m.densityKgM3.toStringAsFixed(0)} kg/m³', theme),
                        const SizedBox(width: 8),
                        if (m.properties['yield_strength_mpa'] != null)
                          _buildDetailChip('Yield', '${m.properties['yield_strength_mpa']} MPa', theme),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
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

  void _showCategoryFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories.map((cat) => ListTile(
            leading: Radio<String>(
              value: cat,
              groupValue: _selectedCategory,
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            title: Text(cat),
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

  void _showMaterialDetail(MaterialInfo m, ThemeData theme, ColorScheme c) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${m.name} ${m.grade ?? ''}'.trim()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Standard', m.standard ?? 'N/A', theme),
              _buildDetailRow('Category', m.category, theme),
              _buildDetailRow('Density', '${m.densityKgM3.toStringAsFixed(2)} kg/m³', theme),
              if (m.properties.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Properties',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...m.properties.entries.map((e) => _buildDetailRow(
                  e.key.replaceAll('_', ' ').toUpperCase(),
                  e.value.toString(),
                  theme,
                )).toList(),
              ],
            ],
          ),
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

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}