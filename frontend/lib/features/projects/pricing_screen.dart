import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/pricing_model.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';
import 'package:jobeval/shared/widgets/pricing_editor.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  JsonMap? _estimateOverride;

  @override
  Widget build(BuildContext context) {
    final pricing = ref.watch(projectPricingProvider(widget.projectId));
    final estimate = ref.watch(estimateProvider(widget.projectId));
    final currentEstimate = _estimateOverride ?? estimate.valueOrNull;

    final finishedBBox = currentEstimate != null
        ? JsonData.firstMap(currentEstimate, const [
            'finished_bbox',
            'finished_dimensions',
            'finished_dimensions_mm',
          ])
        : <String, dynamic>{};
    final finishedSize = finishedBBox['size'] as Map? ?? {};
    final finishedX = (finishedSize['x'] as num?) ?? 0.0;
    final finishedY = (finishedSize['y'] as num?) ?? 0.0;
    final finishedZ = (finishedSize['z'] as num?) ?? 0.0;

    final stockDims = currentEstimate != null
        ? JsonData.firstMap(currentEstimate, const [
            'stock',
            'stock_dimensions',
            'stock_envelope',
          ])
        : <String, dynamic>{};
    final stockSize = stockDims['size'] as Map? ?? {};
    final stockX = (stockSize['x'] as num?) ?? 0.0;
    final stockY = (stockSize['y'] as num?) ?? 0.0;
    final stockZ = (stockSize['z'] as num?) ?? 0.0;

    final allowances = currentEstimate != null
        ? JsonData.firstMap(currentEstimate, const [
            'allowances',
            'allowance_mm',
          ])
        : <String, dynamic>{};
    final allowanceX = (allowances['x'] as num?) ?? 2.0;
    final allowanceY = (allowances['y'] as num?) ?? 2.0;
    final allowanceZ = (allowances['z'] as num?) ?? 2.0;

    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Pricing & estimate',
            subtitle:
                'Save pricing assumptions, then recalculate the estimate from the saved values.',
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(projectPricingProvider(widget.projectId));
                  ref.invalidate(estimateProvider(widget.projectId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          pricing.when(
            loading: () => const SizedBox(
              height: 340,
              child: LoadingPanel(label: 'Loading saved pricing…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Pricing could not be loaded',
              message: apiErrorMessage(error),
              onRetry: () =>
                  ref.invalidate(projectPricingProvider(widget.projectId)),
            ),
            data: (data) => PricingEditor(
              initialPricing: data,
              saveLabel: 'Save pricing & recalculate estimate',
              onSave: _saveAndEstimate,
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Stock & Finished Dimensions',
            subtitle:
                'Finished dimensions are automatically read from CAD analysis. Stock envelope = finished + allowance per side.',
            leading: const Icon(Icons.inventory_2_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DimensionRow(
                  title: 'Finished dimensions (mm)',
                  x: finishedX,
                  y: finishedY,
                  z: finishedZ,
                  label: 'From CAD model',
                ),
                const SizedBox(height: 12),
                _DimensionRow(
                  title: 'Stock envelope (finished + allowance)',
                  x: stockX,
                  y: stockY,
                  z: stockZ,
                  label: 'Required stock',
                ),
                const SizedBox(height: 12),
                _DimensionRow(
                  title: 'Machining allowance per side (mm)',
                  x: allowanceX,
                  y: allowanceY,
                  z: allowanceZ,
                  label: 'Per side',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Estimate result',
            subtitle: currentEstimate == null
                ? 'No saved estimate has been returned for this project.'
                : 'Values returned by the backend after the latest calculation.',
            leading: const Icon(Icons.receipt_long_outlined),
            trailing: currentEstimate == null
                ? null
                : IconButton(
                    tooltip: 'Reload saved estimate',
                    onPressed: () {
                      setState(() => _estimateOverride = null);
                      ref.invalidate(estimateProvider(widget.projectId));
                    },
                    icon: const Icon(Icons.sync),
                  ),
            child: currentEstimate == null
                ? estimate.when(
                    loading: () => const SizedBox(
                      height: 130,
                      child: LoadingPanel(label: 'Loading saved estimate…'),
                    ),
                    error: (error, _) => ErrorPanel(
                      title: 'Saved estimate is unavailable',
                      message: apiErrorMessage(error),
                      onRetry: () =>
                          ref.invalidate(estimateProvider(widget.projectId)),
                    ),
                    data: (_) => const Text(
                      'No estimate is available. Save pricing and recalculate to create one.',
                    ),
                  )
                : EstimateBreakdown(estimate: currentEstimate),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndEstimate(PricingDraft draft) async {
    final payload = draft.toJson();
    final saved = await ref.read(apiClientProvider).putPricing(
          widget.projectId,
          payload,
        );
    ref.invalidate(projectPricingProvider(widget.projectId));
    final estimate = await ref.read(apiClientProvider).postEstimate(
          widget.projectId,
          payload,
        );
    ref.invalidate(estimateProvider(widget.projectId));
    if (mounted) {
      setState(() => _estimateOverride = estimate);
    }
    if (saved.isEmpty && estimate.isEmpty) {
      throw StateError(
          'The backend accepted the request but returned no saved data.');
    }
  }
}

class EstimateBreakdown extends StatelessWidget {
  const EstimateBreakdown({super.key, required this.estimate});

  final JsonMap estimate;

  @override
  Widget build(BuildContext context) {
    final lines = JsonData.firstMaps(estimate, const [
      'line_items',
      'items',
      'breakdown',
      'cost_lines',
      'operations',
    ]);
    final warnings = JsonData.strings(
      estimate['warnings'] ?? estimate['pricing_warnings'],
    );
    final perPiece = JsonData.firstMap(estimate, const ['per_piece']);
    final perPieceCost = perPiece['total_per_piece'] as num?;
    final machiningMinutes = perPiece['machining_minutes'] as num?;
    final machiningHours = perPiece['machining_hours'] as num?;
    final materialCost = perPiece['material_cost'] as num?;
    final machiningCost = perPiece['machining_cost'] as num?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isEmpty)
          Text(
            'The backend returned totals but no itemized estimate lines.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SectionCard(
                      title: 'Per-part cost breakdown',
                      subtitle:
                          'Cost per single part based on current pricing assumptions.',
                      leading: const Icon(Icons.calculate_outlined),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (materialCost != null)
                            _PerPieceLine(
                              label: 'Material cost',
                              value: materialCost,
                              icon: Icons.inventory_2_outlined,
                            ),
                          if (machiningCost != null)
                            _PerPieceLine(
                              label: 'Machining cost',
                              value: machiningCost,
                              icon: Icons.factory_outlined,
                            ),
                          if (machiningHours != null)
                            _PerPieceLine(
                              label: 'Machining time',
                              value: machiningHours,
                              icon: Icons.access_time,
                              suffix: ' hours',
                            ),
                          if (machiningMinutes != null)
                            _PerPieceLine(
                              label: 'Machining minutes',
                              value: machiningMinutes,
                              icon: Icons.access_time,
                              suffix: ' min',
                            ),
                          const SizedBox(height: 16),
                          _PerPieceLine(
                            label: 'Per-part total',
                            value: perPieceCost,
                            icon: Icons.receipt_long_outlined,
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SectionCard(
                      title: 'Line items',
                      subtitle: 'Each line item in the cost breakdown.',
                      leading: const Icon(Icons.list_outlined),
                      child: Column(
                        children: lines.map((line) {
                          return _LineItemRow(line: line);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Warnings',
            leading: const Icon(Icons.warning_amber_outlined,
                color: Colors.orange),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: warnings.map((w) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(w),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _DimensionRow extends StatelessWidget {
  final String title;
  final num x;
  final num y;
  final num z;
  final String label;

  const _DimensionRow({
    required this.title,
    required this.x,
    required this.y,
    required this.z,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _DimensionValue(label: 'X', value: x),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DimensionValue(label: 'Y', value: y),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DimensionValue(label: 'Z', value: z),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DimensionValue extends StatelessWidget {
  final String label;
  final num value;

  const _DimensionValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(2),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PerPieceLine extends StatelessWidget {
  final String label;
  final num? value;
  final IconData icon;
  final bool isTotal;
  final String? suffix;

  const _PerPieceLine({
    required this.label,
    required this.value,
    required this.icon,
    this.isTotal = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value == null
                ? '–'
                : '${value!.toStringAsFixed(2)}${suffix ?? ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
              color: isTotal ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final JsonMap line;

  const _LineItemRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final label = JsonData.text(line['label'], fallback: 'Unknown');
    final quantity = JsonData.number(line['quantity'], fallback: 0);
    final rate = JsonData.number(line['rate'], fallback: 0);
    final subtotal = JsonData.number(line['subtotal'], fallback: 0);
    final isOverride = line['is_override'] == true;
    final formula = JsonData.text(line['formula'], fallback: '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quantity == quantity.toInt()
                ? quantity.toInt().toString()
                : quantity.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          Text(
            rate == 0 ? '–' : rate.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          Text(
            subtotal.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isOverride) ...[
            const SizedBox(width: 8),
            const Icon(Icons.edit, size: 14, color: Colors.orange),
          ],
          const SizedBox(width: 8),
          if (formula.isNotEmpty)
            Text(
              formula,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}