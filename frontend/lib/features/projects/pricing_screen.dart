import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final currency = JsonData.text(estimate['currency'], fallback: 'INR');
    final formatter = NumberFormat.simpleCurrency(name: currency);
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
    final total = _firstNumber(
      estimate,
      const ['total', 'grand_total', 'total_cost', 'final_total'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isEmpty)
          Text(
            'The backend returned totals but no itemized estimate lines.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 54,
                dataRowMaxHeight: 88,
                columns: const [
                  DataColumn(label: Text('Line')),
                  DataColumn(label: Text('Quantity')),
                  DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Rate')),
                  DataColumn(label: Text('Basis / formula')),
                  DataColumn(label: Text('Subtotal')),
                  DataColumn(label: Text('Method')),
                ],
                rows: lines.map((line) {
                  final quantity =
                      _firstNumber(line, const ['quantity', 'qty']);
                  final rate = _firstNumber(
                    line,
                    const ['rate', 'unit_rate', 'unit_cost', 'price'],
                  );
                  final subtotal = _firstNumber(
                    line,
                    const ['subtotal', 'amount', 'total', 'line_total'],
                  );
                  final basis = JsonData.text(line['basis']);
                  final formula = JsonData.text(line['formula']);
                  final override = JsonData.boolean(
                        line['override'] ?? line['is_override'],
                      ) ||
                      line['override_amount'] != null ||
                      line['rate_override'] != null ||
                      JsonData.text(line['calculation_method']).toLowerCase() ==
                          'override';
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                JsonData.displayName(line,
                                    fallback: 'Cost line'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              Text(
                                JsonData.text(line['category'] ?? line['type']),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(formatNumber(quantity))),
                      DataCell(
                          Text(JsonData.text(line['unit'], fallback: '—'))),
                      DataCell(Text(formatter.format(rate))),
                      DataCell(
                        SizedBox(
                          width: 235,
                          child: Text(
                            [
                              if (basis.isNotEmpty) 'Basis: $basis',
                              if (formula.isNotEmpty) 'Formula: $formula',
                              if (basis.isEmpty && formula.isEmpty)
                                'Not supplied',
                            ].join('\n'),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          formatter.format(subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(
                        StatusPill(
                          label: override ? 'Override' : 'Calculated',
                          tone: override
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Estimate warnings',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          ...warnings.map(
            (warning) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.warning_amber_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(warning),
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 8),
        _TotalRow(
          label: 'Subtotal',
          value: formatter.format(
            _firstNumber(estimate, const ['subtotal', 'subtotal_cost']),
          ),
        ),
        _TotalRow(
          label: 'Overhead',
          value: formatter.format(
            _firstNumber(estimate, const ['overhead', 'overhead_cost']),
          ),
        ),
        _TotalRow(
          label: 'Margin',
          value: formatter.format(
            _firstNumber(estimate, const ['margin', 'margin_cost']),
          ),
        ),
        _TotalRow(
          label: 'Contingency',
          value: formatter.format(
            _firstNumber(estimate, const ['contingency', 'contingency_cost']),
          ),
        ),
        _TotalRow(
          label: 'Tax',
          value: formatter.format(
            _firstNumber(estimate, const ['tax', 'tax_cost']),
          ),
        ),
        const SizedBox(height: 5),
        _TotalRow(
          label: 'TOTAL',
          value: formatter.format(total),
          emphasized: true,
        ),
      ],
    );
  }

  double _firstNumber(JsonMap map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
          fontSize: emphasized ? 17 : null,
          color: emphasized ? Theme.of(context).colorScheme.primary : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
