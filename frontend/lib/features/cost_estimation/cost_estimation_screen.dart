import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';

class CostEstimationScreen extends ConsumerStatefulWidget {
  final String projectId;

  const CostEstimationScreen({super.key, required this.projectId});

  @override
  ConsumerState<CostEstimationScreen> createState() => _CostEstimationScreenState();
}

class _CostEstimationScreenState extends ConsumerState<CostEstimationScreen> {
  String _selectedRegion = 'domestic';
  int _quantity = 1;
  String _selectedMaterial = 'aluminum_6061';

  final List<String> _regions = ['domestic', 'usa', 'canada', 'mexico', 'europe', 'china', 'india', 'asia'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Estimation'),
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
        builder: (context, mfgSnapshot) {
          if (mfgSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (mfgSnapshot.hasError) {
            return Center(child: Text('Error: ${mfgSnapshot.error}'));
          }

          final mfg = mfgSnapshot.data!;

          return FutureBuilder<CostEstimate>(
            future: _getCostEstimate(mfg),
            builder: (context, costSnapshot) {
              if (costSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (costSnapshot.hasError) {
                return Center(child: Text('Error: ${costSnapshot.error}'));
              }

              final cost = costSnapshot.data!;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Configuration
                    _buildConfigurationCard(theme, colorScheme),
                    const SizedBox(height: 24),

                    // Cost breakdown
                    _buildSectionHeader('Cost Breakdown', Icons.attach_money, theme),
                    const SizedBox(height: 12),
                    _buildCostRow('Material', cost.materialCost, colorScheme.primary, theme),
                    _buildCostRow('Machining', cost.machiningCost, colorScheme.tertiary, theme),
                    _buildCostRow('Setup', cost.setupCost, colorScheme.secondary, theme),
                    _buildCostRow('Tooling', cost.toolingCost, colorScheme.onSurfaceVariant, theme),
                    _buildCostRow('Inspection', cost.inspectionCost, colorScheme.primary, theme),
                    _buildCostRow('Overhead', cost.overheadCost, colorScheme.onSurfaceVariant, theme),
                    const Divider(),
                    _buildCostRow('TOTAL', cost.totalCost, colorScheme.error, theme, isTotal: true),
                    const SizedBox(height: 24),

                    // Stock info
                    _buildSectionHeader('Stock Information', Icons.inventory, theme),
                    const SizedBox(height: 12),
                    _buildInfoRow('Stock Volume', '${mfg.stockVolumeCm3.toStringAsFixed(1)} cm³', theme),
                    _buildInfoRow('Stock Weight', '${mfg.stockWeightKg.toStringAsFixed(2)} kg', theme),
                    _buildInfoRow('Material Removal', '${mfg.materialRemovalVolumeCm3.toStringAsFixed(1)} cm³', theme),
                    const SizedBox(height: 24),

                    // Time breakdown
                    _buildSectionHeader('Time Breakdown', Icons.access_time, theme),
                    const SizedBox(height: 12),
                    _buildTimeRow('Cutting', mfg.totalCuttingTimeMin, theme),
                    _buildTimeRow('Setup', mfg.totalSetupTimeMin, theme),
                    _buildTimeRow('Tool Change', mfg.totalToolChangeTimeMin, theme),
                    _buildTimeRow('Inspection', mfg.totalInspectionTimeMin, theme),
                    const Divider(),
                    _buildTimeRow('TOTAL', mfg.totalEstimatedTimeMin, theme, isTotal: true),
                    const SizedBox(height: 24),

                    // Assumptions
                    if (cost.assumptions.isNotEmpty) ...[
                      _buildSectionHeader('Assumptions', Icons.info, theme),
                      const SizedBox(height: 12),
                      ...cost.assumptions.map((a) => _buildAssumptionRow(a, theme)).toList(),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<CostEstimate> _getCostEstimate(ManufacturingAnalysis mfg) async {
    final api = ref.read(apiServiceProvider);
    return api.estimateCost(
      projectId: widget.projectId,
      materialId: _selectedMaterial,
      region: _selectedRegion,
      quantity: _quantity,
    );
  }

  Widget _buildConfigurationCard(ThemeData theme, ColorScheme c) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      prefixIcon: Icon(Icons.flag),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    items: _regions.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.toUpperCase()),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedRegion = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _quantity,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    items: [1, 5, 10, 50, 100].map((q) => DropdownMenuItem(
                      value: q,
                      child: Text('$q'),
                    )).toList(),
                    onChanged: (v) => setState(() => _quantity = v!),
                  ),
                ),
              ],
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

  Widget _buildCostRow(String label, double value, Color color, ThemeData theme, {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isTotal
          ? BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? color : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isTotal ? color : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, double minutes, ThemeData theme, {bool isTotal = false}) {
    final hours = (minutes / 60).toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isTotal
          ? BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${minutes.toInt()} min ($hours hrs)',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssumptionRow(String a, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              a,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}