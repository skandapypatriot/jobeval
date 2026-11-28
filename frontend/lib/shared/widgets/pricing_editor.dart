import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/pricing_model.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class PricingEditor extends StatefulWidget {
  const PricingEditor({
    super.key,
    required this.initialPricing,
    required this.onSave,
    this.saveLabel = 'Save pricing',
    this.showQuantity = true,
  });

  final JsonMap initialPricing;
  final Future<void> Function(PricingDraft draft) onSave;
  final String saveLabel;
  final bool showQuantity;

  @override
  State<PricingEditor> createState() => _PricingEditorState();
}

class _PricingEditorState extends State<PricingEditor> {
  late PricingDraft _draft;
  late final TextEditingController _materialName;
  late final TextEditingController _density;
  late final TextEditingController _materialPrice;
  late final TextEditingController _stockForm;
  late final TextEditingController _finishedX;
  late final TextEditingController _finishedY;
  late final TextEditingController _finishedZ;
  late final TextEditingController _stockX;
  late final TextEditingController _stockY;
  late final TextEditingController _stockZ;
  late final TextEditingController _allowanceX;
  late final TextEditingController _allowanceY;
  late final TextEditingController _allowanceZ;
  late final Map<String, TextEditingController> _rateControllers;
  late final TextEditingController _quantity;
  late final TextEditingController _currency;
  late final TextEditingController _overhead;
  late final TextEditingController _margin;
  late final TextEditingController _contingency;
  late final TextEditingController _tax;
  final List<_OverrideControllers> _overrideControllers = [];
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialPricing.isEmpty
        ? PricingDraft.defaults()
        : PricingDraft.fromJson(widget.initialPricing);
    _materialName = TextEditingController(text: _draft.materialName);
    _density = TextEditingController(text: formatNumber(_draft.density));
    _materialPrice =
        TextEditingController(text: formatNumber(_draft.materialPrice));
    _stockForm = TextEditingController(text: _draft.stockForm);
    _finishedX = TextEditingController(text: formatNumber(_draft.finishedX));
    _finishedY = TextEditingController(text: formatNumber(_draft.finishedY));
    _finishedZ = TextEditingController(text: formatNumber(_draft.finishedZ));
    _stockX = TextEditingController(text: formatNumber(_draft.stockX));
    _stockY = TextEditingController(text: formatNumber(_draft.stockY));
    _stockZ = TextEditingController(text: formatNumber(_draft.stockZ));
    _allowanceX = TextEditingController(text: formatNumber(_draft.allowanceX));
    _allowanceY = TextEditingController(text: formatNumber(_draft.allowanceY));
    _allowanceZ = TextEditingController(text: formatNumber(_draft.allowanceZ));
    _rateControllers = {
      for (final entry in _draft.rates.entries)
        entry.key: TextEditingController(text: formatNumber(entry.value)),
    };
    _quantity = TextEditingController(text: '${_draft.quantity}');
    _currency = TextEditingController(text: _draft.currency);
    _overhead =
        TextEditingController(text: formatNumber(_draft.overheadPercent));
    _margin = TextEditingController(text: formatNumber(_draft.marginPercent));
    _contingency =
        TextEditingController(text: formatNumber(_draft.contingencyPercent));
    _tax = TextEditingController(text: formatNumber(_draft.taxPercent));
    for (final override in _draft.operationOverrides) {
      _overrideControllers.add(_OverrideControllers(override));
    }
  }

  @override
  void dispose() {
    _materialName.dispose();
    _density.dispose();
    _materialPrice.dispose();
    _stockForm.dispose();
    _finishedX.dispose();
    _finishedY.dispose();
    _finishedZ.dispose();
    _stockX.dispose();
    _stockY.dispose();
    _stockZ.dispose();
    _allowanceX.dispose();
    _allowanceY.dispose();
    _allowanceZ.dispose();
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    _quantity.dispose();
    _currency.dispose();
    _overhead.dispose();
    _margin.dispose();
    _contingency.dispose();
    _tax.dispose();
    for (final override in _overrideControllers) {
      override.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missingRates = _missingRates();
    final computedEnvelope = (
      _draft.finishedX + 2 * _draft.allowanceX,
      _draft.finishedY + 2 * _draft.allowanceY,
      _draft.finishedZ + 2 * _draft.allowanceZ,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editorSection(
          title: 'Material',
          subtitle:
              'Material price basis is retained explicitly in the saved payload.',
          icon: Icons.inventory_2_outlined,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _materialName,
                      decoration: const InputDecoration(labelText: 'Material'),
                      onChanged: (value) => _draft.materialName = value,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _density,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Density (kg/m³)',
                      ),
                      onChanged: (value) => _draft.density =
                          double.tryParse(value) ?? _draft.density,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _materialPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Material price'),
                      onChanged: (value) => _draft.materialPrice =
                          double.tryParse(value) ?? _draft.materialPrice,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      initialValue: const [
                        'per_kg',
                        'per_piece',
                        'per_volume',
                        'per_area',
                      ].contains(_draft.materialPriceBasis)
                          ? _draft.materialPriceBasis
                          : 'per_kg',
                      decoration:
                          const InputDecoration(labelText: 'Price basis'),
                      items: const [
                        DropdownMenuItem(
                          value: 'per_kg',
                          child: Text('Per kg'),
                        ),
                        DropdownMenuItem(
                          value: 'per_piece',
                          child: Text('Per piece'),
                        ),
                        DropdownMenuItem(
                          value: 'per_volume',
                          child: Text('Per volume'),
                        ),
                        DropdownMenuItem(
                          value: 'per_area',
                          child: Text('Per area'),
                        ),
                      ],
                      onChanged: (value) =>
                          _draft.materialPriceBasis = value ?? 'per_kg',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _editorSection(
          title: 'Finished part and stock envelope',
          subtitle:
              'Finished dimensions are separate from the stock envelope. Allowance can be zero or asymmetric.',
          icon: Icons.crop_free_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _stockForm,
                decoration: const InputDecoration(
                  labelText: 'Stock form',
                  helperText: 'For example: block, plate, sheet, round bar.',
                ),
                onChanged: (value) => _draft.stockForm = value,
              ),
              const SizedBox(height: 12),
              _dimensionGroup(
                title: 'Finished dimensions (mm)',
                xController: _finishedX,
                yController: _finishedY,
                zController: _finishedZ,
                onChanged: (axis, value) {
                  if (axis == 'x') {
                    _draft.finishedX = value;
                  } else if (axis == 'y') {
                    _draft.finishedY = value;
                  } else {
                    _draft.finishedZ = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              _dimensionGroup(
                title: 'Stock envelope (mm)',
                xController: _stockX,
                yController: _stockY,
                zController: _stockZ,
                onChanged: (axis, value) {
                  if (axis == 'x') {
                    _draft.stockX = value;
                  } else if (axis == 'y') {
                    _draft.stockY = value;
                  } else {
                    _draft.stockZ = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              _dimensionGroup(
                title: 'Machining allowance per side (mm)',
                xController: _allowanceX,
                yController: _allowanceY,
                zController: _allowanceZ,
                onChanged: (axis, value) {
                  if (axis == 'x') {
                    _draft.allowanceX = value;
                  } else if (axis == 'y') {
                    _draft.allowanceY = value;
                  } else {
                    _draft.allowanceZ = value;
                  }
                },
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Envelope implied by finished size + allowance: '
                  '${formatNumber(computedEnvelope.$1)} × ${formatNumber(computedEnvelope.$2)} × ${formatNumber(computedEnvelope.$3)} mm. '
                  'This is informational; the saved stock envelope remains independently editable.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _editorSection(
          title: 'Rates',
          subtitle:
              'Rates are currency per hour unless the backend pricing payload specifies another basis.',
          icon: Icons.speed_outlined,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in const [
                    ('machine', 'Machine rate'),
                    ('labour', 'Labour rate'),
                    ('setup', 'Setup rate'),
                    ('tool', 'Tool rate'),
                    ('program', 'Programming rate'),
                    ('inspection', 'Inspection rate'),
                    ('finish', 'Finish rate'),
                    ('deburr', 'Deburr rate'),
                  ])
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _rateControllers[entry.$1],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: entry.$2),
                        onChanged: (value) => _draft.rates[entry.$1] =
                            double.tryParse(value) ?? 0,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _editorSection(
          title: 'Operation overrides',
          subtitle:
              'Use a rate override or a fixed amount for a specific operation. The backend decides how these values map to estimate lines.',
          icon: Icons.tune_outlined,
          trailing: TextButton.icon(
            onPressed: _addOverride,
            icon: const Icon(Icons.add),
            label: const Text('Add override'),
          ),
          child: _overrideControllers.isEmpty
              ? const Text('No operation-specific overrides are configured.')
              : Column(
                  children: _overrideControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controllers = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 760;
                          final fields = [
                            SizedBox(
                              width: wide ? 220 : constraints.maxWidth,
                              child: TextField(
                                controller: controllers.operationId,
                                decoration: const InputDecoration(
                                  labelText: 'Operation ID',
                                ),
                                onChanged: (value) =>
                                    controllers.value.operationId = value,
                              ),
                            ),
                            SizedBox(
                              width: wide ? 150 : constraints.maxWidth,
                              child: TextField(
                                controller: controllers.rate,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Rate override',
                                ),
                                onChanged: (value) => controllers.value.rate =
                                    double.tryParse(value) ?? 0,
                              ),
                            ),
                            SizedBox(
                              width: wide ? 150 : constraints.maxWidth,
                              child: TextField(
                                controller: controllers.amount,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Fixed amount',
                                ),
                                onChanged: (value) => controllers.value.amount =
                                    double.tryParse(value) ?? 0,
                              ),
                            ),
                            SizedBox(
                              width: wide ? 120 : constraints.maxWidth,
                              child: TextField(
                                controller: controllers.unit,
                                decoration:
                                    const InputDecoration(labelText: 'Unit'),
                                onChanged: (value) =>
                                    controllers.value.unit = value,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove override',
                              onPressed: () => _removeOverride(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ];
                          return wide
                              ? Row(children: fields)
                              : Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: fields);
                        },
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _editorSection(
          title: 'Quantity and commercial adjustments',
          subtitle: 'Currency defaults to INR and remains editable.',
          icon: Icons.calculate_outlined,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850 ? 3 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (widget.showQuantity)
                    SizedBox(
                      width: width,
                      child: TextField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration:
                            const InputDecoration(labelText: 'Quantity'),
                        onChanged: (value) => _draft.quantity =
                            int.tryParse(value) ?? _draft.quantity,
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _currency,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'Currency code',
                        counterText: '',
                      ),
                      onChanged: (value) =>
                          _draft.currency = value.toUpperCase().trim(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _overhead,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Overhead %'),
                      onChanged: (value) =>
                          _draft.overheadPercent = double.tryParse(value) ?? 0,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _margin,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Margin %'),
                      onChanged: (value) =>
                          _draft.marginPercent = double.tryParse(value) ?? 0,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _contingency,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(labelText: 'Contingency %'),
                      onChanged: (value) => _draft.contingencyPercent =
                          double.tryParse(value) ?? 0,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: _tax,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Tax %'),
                      onChanged: (value) =>
                          _draft.taxPercent = double.tryParse(value) ?? 0,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (missingRates.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Missing rates: ${missingRates.join(', ')}. The estimate may be incomplete until these values are supplied.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : widget.saveLabel),
            ),
            if (_success != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _success!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ] else if (_error != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _editorSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      leading: Icon(icon),
      trailing: trailing,
      child: child,
    );
  }

  Widget _dimensionGroup({
    required String title,
    required TextEditingController xController,
    required TextEditingController yController,
    required TextEditingController zController,
    required void Function(String axis, double value) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _numberField(
                controller: xController,
                label: 'X / length',
                onChanged: (value) => onChanged('x', value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberField(
                controller: yController,
                label: 'Y / width',
                onChanged: (value) => onChanged('y', value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numberField(
                controller: zController,
                label: 'Z / height',
                onChanged: (value) => onChanged('z', value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (value) => onChanged(double.tryParse(value) ?? 0),
    );
  }

  List<String> _missingRates() {
    const labels = {
      'machine': 'machine',
      'labour': 'labour',
      'setup': 'setup',
      'tool': 'tool',
      'program': 'programming',
      'inspection': 'inspection',
      'finish': 'finish',
      'deburr': 'deburr',
    };
    return labels.entries
        .where((entry) => (_draft.rates[entry.key] ?? 0) <= 0)
        .map((entry) => entry.value)
        .toList();
  }

  void _addOverride() {
    setState(() {
      _overrideControllers.add(
        _OverrideControllers(
          OperationRateOverride(
            operationId: '',
            rate: 0,
            amount: 0,
            unit: 'hour',
          ),
        ),
      );
    });
  }

  void _removeOverride(int index) {
    setState(() {
      _overrideControllers.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    _draft.operationOverrides = _overrideControllers
        .map((controllers) => controllers.value)
        .where((override) => override.operationId.trim().isNotEmpty)
        .toList();
    try {
      await widget.onSave(_draft);
      if (mounted) setState(() => _success = 'Pricing saved successfully.');
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _OverrideControllers {
  _OverrideControllers(this.value)
      : operationId = TextEditingController(text: value.operationId),
        rate = TextEditingController(text: formatNumber(value.rate)),
        amount = TextEditingController(text: formatNumber(value.amount)),
        unit = TextEditingController(text: value.unit);

  OperationRateOverride value;
  final TextEditingController operationId;
  final TextEditingController rate;
  final TextEditingController amount;
  final TextEditingController unit;

  void dispose() {
    operationId.dispose();
    rate.dispose();
    amount.dispose();
    unit.dispose();
  }
}
