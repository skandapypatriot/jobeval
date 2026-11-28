import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class ManufacturingScreen extends ConsumerStatefulWidget {
  const ManufacturingScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ManufacturingScreen> createState() =>
      _ManufacturingScreenState();
}

class _ManufacturingScreenState extends ConsumerState<ManufacturingScreen> {
  JsonMap? _workingPlan;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final planProvider = manufacturingPlanProvider(widget.projectId);
    final plan = ref.watch(planProvider);
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Manufacturing plan',
            subtitle:
                'Setups and operation estimates are planning assumptions only — not generated CAM toolpaths.',
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _workingPlan = null);
                  ref.invalidate(planProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save plan'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          plan.when(
            loading: () => const SizedBox(
              height: 340,
              child: LoadingPanel(label: 'Loading manufacturing plan…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Manufacturing plan could not be loaded',
              message: apiErrorMessage(error),
              onRetry: () => ref.invalidate(planProvider),
            ),
            data: (data) {
              final root = _planRoot(data);
              final working = _workingPlan ?? root;
              final setups = JsonData.firstMaps(working, const ['setups']);
              final operations =
                  JsonData.firstMaps(working, const ['operations']);
              final warnings = JsonData.strings(
                working['warnings'] ?? working['accessibility_warnings'],
              );
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Operation times, tools, and rates are estimates for review. They do not represent cutter compensation, feeds and speeds, g-code, or executable CAM toolpaths.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Setups (${setups.length})',
                    subtitle: 'Workholding and orientation assumptions.',
                    leading: const Icon(Icons.factory_outlined),
                    child: setups.isEmpty
                        ? const Text('No setups were returned by the backend.')
                        : Column(
                            children: setups.asMap().entries.map((entry) {
                              final setup = entry.value;
                              final status = JsonData.text(
                                setup['status'] ?? setup['review_status'],
                                fallback: 'suggested',
                              );
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 15,
                                  child: Text('${entry.key + 1}'),
                                ),
                                title: Text(
                                  JsonData.displayName(
                                    setup,
                                    fallback: 'Setup ${entry.key + 1}',
                                  ),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  'Features: ${JsonData.strings(setup['features']).join(', ')}\n${JsonData.text(setup['description'])}',
                                ),
                                trailing: StatusPill(label: status),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Operations (${operations.length})',
                    subtitle:
                        'Edit estimates, review state, accessibility, and collision warnings; then save the whole plan.',
                    leading: const Icon(Icons.build_outlined),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => _addOperation(working),
                      icon: const Icon(Icons.add),
                      label: const Text('Add operation'),
                    ),
                    child: operations.isEmpty
                        ? EmptyPanel(
                            title: 'No operations in the plan',
                            message:
                                'Add a planning operation or run a backend analysis to generate suggestions.',
                            icon: Icons.build_outlined,
                            action: FilledButton.icon(
                              onPressed: () => _addOperation(working),
                              icon: const Icon(Icons.add),
                              label: const Text('Add operation'),
                            ),
                          )
                        : _OperationTable(
                            operations: operations,
                            onEdit: (index) => _editOperation(working, index),
                            onDelete: (index) =>
                                _removeOperation(working, index),
                            onMove: (index, direction) =>
                                _moveOperation(working, index, direction),
                          ),
                  ),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionCard(
                      title: 'Plan warnings',
                      subtitle:
                          'Accessibility and collision warnings returned with the plan.',
                      leading: Icon(
                        Icons.warning_amber_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      child: Column(
                        children: warnings.map((warning) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_outlined),
                            title: Text(warning),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  JsonMap _planRoot(JsonMap data) {
    final nested = data['plan'];
    if (nested is Map) return JsonData.map(nested);
    return data;
  }

  Future<void> _save() async {
    final plan = _workingPlan;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no local plan edits to save.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await ref.read(apiClientProvider).putManufacturingPlan(
            widget.projectId,
            plan,
          );
      setState(() => _workingPlan = _planRoot(response));
      ref.invalidate(manufacturingPlanProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manufacturing plan saved.')),
        );
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addOperation(JsonMap source) async {
    final operation = await showDialog<JsonMap>(
      context: context,
      builder: (context) => _OperationDialog(
        operation: const {},
        setupIds: JsonData.firstMaps(source, const ['setups'])
            .map((setup) => JsonData.text(setup['setup_id'] ?? setup['id']))
            .where((id) => id.isNotEmpty)
            .toList(),
      ),
    );
    if (operation == null || !mounted) return;
    final root = JsonData.map(source);
    final operations = List<JsonMap>.from(
      JsonData.firstMaps(root, const ['operations']),
    );
    operations.add(operation);
    _replaceOperations(root, operations);
    setState(() => _workingPlan = root);
  }

  Future<void> _editOperation(JsonMap source, int index) async {
    final operations = JsonData.firstMaps(source, const ['operations']);
    if (index < 0 || index >= operations.length) return;
    final operation = await showDialog<JsonMap>(
      context: context,
      builder: (context) => _OperationDialog(
        operation: operations[index],
        setupIds: JsonData.firstMaps(source, const ['setups'])
            .map((setup) => JsonData.text(setup['setup_id'] ?? setup['id']))
            .where((id) => id.isNotEmpty)
            .toList(),
      ),
    );
    if (operation == null || !mounted) return;
    final root = JsonData.map(source);
    final updated = List<JsonMap>.from(
      JsonData.firstMaps(root, const ['operations']),
    );
    updated[index] = operation;
    _replaceOperations(root, updated);
    setState(() => _workingPlan = root);
  }

  void _removeOperation(JsonMap source, int index) {
    final root = JsonData.map(source);
    final operations = List<JsonMap>.from(
      JsonData.firstMaps(root, const ['operations']),
    );
    if (index < 0 || index >= operations.length) return;
    operations.removeAt(index);
    _replaceOperations(root, operations);
    setState(() => _workingPlan = root);
  }

  void _moveOperation(JsonMap source, int index, int direction) {
    final root = JsonData.map(source);
    final operations = List<JsonMap>.from(
      JsonData.firstMaps(root, const ['operations']),
    );
    final destination = index + direction;
    if (index < 0 || index >= operations.length) return;
    if (destination < 0 || destination >= operations.length) return;
    final operation = operations.removeAt(index);
    operations.insert(destination, operation);
    _replaceOperations(root, operations);
    setState(() => _workingPlan = root);
  }

  void _replaceOperations(JsonMap root, List<JsonMap> operations) {
    for (var index = 0; index < operations.length; index++) {
      operations[index]['order'] = index;
    }
    root['operations'] = operations;
  }
}

class _OperationTable extends StatelessWidget {
  const _OperationTable({
    required this.operations,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
  });

  final List<JsonMap> operations;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final void Function(int index, int direction) onMove;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 88,
          columns: const [
            DataColumn(label: Text('Order')),
            DataColumn(label: Text('Operation')),
            DataColumn(label: Text('Setup / features')),
            DataColumn(label: Text('Estimate')),
            DataColumn(label: Text('Review state')),
            DataColumn(label: Text('Warnings')),
            DataColumn(label: Text('Actions')),
          ],
          rows: operations.asMap().entries.map((entry) {
            final index = entry.key;
            final operation = entry.value;
            final status = JsonData.text(
              operation['status'] ?? operation['review_status'],
              fallback: 'suggested',
            );
            final accessibility = JsonData.text(
              operation['accessibility_warning'] ??
                  operation['accessibility'] ??
                  operation['accessibility_note'],
            );
            final collision = JsonData.text(
              operation['collision_warning'] ?? operation['collision_risk'],
            );
            return DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(
                  SizedBox(
                    width: 165,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          JsonData.displayName(
                            operation,
                            fallback: 'Operation ${index + 1}',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          JsonData.text(
                            operation['operation_type'] ?? operation['type'],
                            fallback: 'operation',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 155,
                    child: Text(
                      'Setup: ${JsonData.text(operation['setup_id'], fallback: '—')}\n'
                      'Features: ${JsonData.strings(operation['feature_ids']).join(', ')}',
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 105,
                    child: Text(
                      '${formatNumber(JsonData.number(operation['estimated_time_min'] ?? operation['estimated_time']))} min',
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 125,
                    child: StatusPill(
                      label: status,
                      tone: status.toLowerCase() == 'confirmed'
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Text(
                      [
                        if (accessibility.isNotEmpty)
                          'Accessibility: $accessibility',
                        if (collision.isNotEmpty) 'Collision: $collision',
                        if (accessibility.isEmpty && collision.isEmpty)
                          'No accessibility or collision warning supplied',
                      ].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 145,
                    child: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          onPressed:
                              index == 0 ? null : () => onMove(index, -1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed: index == operations.length - 1
                              ? null
                              : () => onMove(index, 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Edit operation',
                          onPressed: () => onEdit(index),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remove operation',
                          onPressed: () => onDelete(index),
                          icon: const Icon(Icons.delete_outline),
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
}

class _OperationDialog extends StatefulWidget {
  const _OperationDialog({required this.operation, required this.setupIds});

  final JsonMap operation;
  final List<String> setupIds;

  @override
  State<_OperationDialog> createState() => _OperationDialogState();
}

class _OperationDialogState extends State<_OperationDialog> {
  late final TextEditingController _name;
  late final TextEditingController _type;
  late final TextEditingController _setup;
  late final TextEditingController _time;
  late final TextEditingController _accessibility;
  late final TextEditingController _collision;
  late final TextEditingController _notes;
  late String _status;

  @override
  void initState() {
    super.initState();
    final operation = widget.operation;
    _name = TextEditingController(
      text: JsonData.text(operation['name'] ?? operation['operation_type']),
    );
    _type = TextEditingController(
      text: JsonData.text(operation['operation_type'] ?? operation['type']),
    );
    _setup = TextEditingController(text: JsonData.text(operation['setup_id']));
    _time = TextEditingController(
      text: formatNumber(
        JsonData.number(
          operation['estimated_time_min'] ?? operation['estimated_time'],
        ),
      ),
    );
    _accessibility = TextEditingController(
      text: JsonData.text(
        operation['accessibility_warning'] ??
            operation['accessibility'] ??
            operation['accessibility_note'],
      ),
    );
    _collision = TextEditingController(
      text: JsonData.text(
        operation['collision_warning'] ?? operation['collision_risk'],
      ),
    );
    _notes = TextEditingController(text: JsonData.text(operation['notes']));
    _status = JsonData.text(
      operation['status'] ?? operation['review_status'],
      fallback: 'suggested',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _setup.dispose();
    _time.dispose();
    _accessibility.dispose();
    _collision.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.operation.isEmpty ? 'Add operation' : 'Edit operation',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Operation name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _type,
                decoration: const InputDecoration(labelText: 'Operation type'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: widget.setupIds.contains(_setup.text)
                    ? _setup.text
                    : (widget.setupIds.isEmpty ? null : widget.setupIds.first),
                decoration: const InputDecoration(labelText: 'Setup'),
                items: widget.setupIds
                    .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) _setup.text = value;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _time,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Estimated duration (minutes)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue:
                    _status == 'confirmed' ? 'confirmed' : 'suggested',
                decoration: const InputDecoration(labelText: 'Review state'),
                items: const [
                  DropdownMenuItem(
                      value: 'suggested', child: Text('Suggested')),
                  DropdownMenuItem(
                      value: 'confirmed', child: Text('Confirmed')),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? 'suggested'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accessibility,
                decoration: const InputDecoration(
                  labelText: 'Accessibility warning / rating',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _collision,
                decoration: const InputDecoration(
                  labelText: 'Collision warning',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Planning notes'),
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
          child: const Text('Apply to plan'),
        ),
      ],
    );
  }

  void _save() {
    final operation = JsonData.map(widget.operation);
    operation['name'] = _name.text.trim();
    operation['operation_type'] = _type.text.trim();
    operation['setup_id'] = _setup.text.trim();
    operation['estimated_time_min'] = double.tryParse(_time.text.trim()) ?? 0;
    operation['status'] = _status;
    operation['accessibility_warning'] = _accessibility.text.trim();
    operation['collision_warning'] = _collision.text.trim();
    operation['notes'] = _notes.text.trim();
    if (!operation.containsKey('operation_id') &&
        !operation.containsKey('id')) {
      operation['operation_id'] =
          'manual-${DateTime.now().millisecondsSinceEpoch}';
    }
    Navigator.pop(context, operation);
  }
}
