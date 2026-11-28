import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class CrossValidationScreen extends ConsumerStatefulWidget {
  const CrossValidationScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<CrossValidationScreen> createState() =>
      _CrossValidationScreenState();
}

class _CrossValidationScreenState extends ConsumerState<CrossValidationScreen> {
  String _filter = 'all';
  bool _running = false;
  String? _savingCheck;

  @override
  Widget build(BuildContext context) {
    final validation = ref.watch(crossValidationProvider(widget.projectId));
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Cross-validation',
            subtitle:
                'Compare drawing and model properties, then record a review decision for each check.',
            actions: [
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(crossValidationProvider(widget.projectId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: _running ? null : _runValidation,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.compare_arrows),
                label: Text(_running ? 'Comparing…' : 'Run comparison'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          validation.when(
            loading: () => const SizedBox(
              height: 340,
              child: LoadingPanel(label: 'Loading cross-validation checks…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Cross-validation could not be loaded',
              message: apiErrorMessage(error),
              onRetry: () =>
                  ref.invalidate(crossValidationProvider(widget.projectId)),
            ),
            data: (items) {
              final checks = items.map(_CrossCheck.fromJson).toList();
              final filtered = _filter == 'all'
                  ? checks
                  : checks.where((check) => check.status == _filter).toList();
              return Column(
                children: [
                  SectionCard(
                    title: 'Comparison status',
                    subtitle:
                        '${filtered.length} of ${checks.length} checks shown.',
                    leading: const Icon(Icons.rule_folder_outlined),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == 'all',
                          onSelected: () => setState(() => _filter = 'all'),
                        ),
                        for (final status in const [
                          'match',
                          'mismatch',
                          'drawing_only',
                          'model_only',
                          'needs_review',
                        ])
                          _FilterChip(
                            label: status.replaceAll('_', ' '),
                            selected: _filter == status,
                            count: checks
                                .where((check) => check.status == status)
                                .length,
                            onSelected: () => setState(() => _filter = status),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Validation checks',
                    subtitle:
                        'Review actions are sent to POST /projects/${widget.projectId}/cross-validation.',
                    leading: const Icon(Icons.fact_check_outlined),
                    child: filtered.isEmpty
                        ? EmptyPanel(
                            title: checks.isEmpty
                                ? 'No comparison results'
                                : 'No checks in this status',
                            message: checks.isEmpty
                                ? 'Run a comparison after both model and drawing data are available.'
                                : 'Choose another status to inspect the remaining checks.',
                            icon: Icons.compare_arrows,
                          )
                        : _CheckTable(
                            checks: filtered,
                            savingCheck: _savingCheck,
                            onReview: _review,
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runValidation() async {
    setState(() => _running = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .runCrossValidation(widget.projectId);
      ref.invalidate(crossValidationProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Comparison ${JsonData.status(response, fallback: 'completed')}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _review(_CrossCheck check, String reviewStatus) async {
    setState(() => _savingCheck = check.id);
    try {
      final response = await ref.read(apiClientProvider).runCrossValidation(
        widget.projectId,
        request: {
          'check_id': check.id,
          'review_status': reviewStatus,
        },
      );
      ref.invalidate(crossValidationProvider(widget.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${check.property} review saved: ${JsonData.status(response, fallback: reviewStatus)}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _savingCheck = null);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Text(count == null ? label : '$label ($count)'),
    );
  }
}

class _CheckTable extends StatelessWidget {
  const _CheckTable({
    required this.checks,
    required this.savingCheck,
    required this.onReview,
  });

  final List<_CrossCheck> checks;
  final String? savingCheck;
  final void Function(_CrossCheck check, String reviewStatus) onReview;

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
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Drawing')),
            DataColumn(label: Text('Model')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Tolerance / details')),
            DataColumn(label: Text('Review')),
            DataColumn(label: Text('Actions')),
          ],
          rows: checks.map((check) {
            final saving = savingCheck == check.id;
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 165,
                    child: Text(
                      check.property,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                DataCell(SizedBox(width: 115, child: Text(check.drawing))),
                DataCell(SizedBox(width: 115, child: Text(check.model))),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: StatusPill(
                      label: check.status.replaceAll('_', ' '),
                      tone: _statusTone(context, check.status),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          check.tolerance.isEmpty
                              ? 'Tolerance not supplied'
                              : 'Tolerance: ${check.tolerance}',
                        ),
                        if (check.details.isNotEmpty)
                          Text(
                            check.details,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 125,
                    child: StatusPill(label: check.reviewStatus),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 210,
                    child: saving
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Wrap(
                            spacing: 6,
                            children: [
                              OutlinedButton(
                                onPressed: () => onReview(check, 'accepted'),
                                child: const Text('Accept'),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    onReview(check, 'needs_review'),
                                child: const Text('Review'),
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

  Color _statusTone(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'match' => scheme.tertiary,
      'mismatch' => scheme.error,
      'needs_review' => scheme.secondary,
      'drawing_only' || 'model_only' => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
  }
}

class _CrossCheck {
  const _CrossCheck({
    required this.id,
    required this.property,
    required this.drawing,
    required this.model,
    required this.status,
    required this.tolerance,
    required this.details,
    required this.reviewStatus,
  });

  factory _CrossCheck.fromJson(JsonMap json) {
    final rawStatus = JsonData.text(
      json['status'] ?? json['validation_status'],
      fallback: 'needs_review',
    ).toLowerCase();
    final status = rawStatus == 'within_tolerance' ? 'match' : rawStatus;
    return _CrossCheck(
      id: JsonData.text(
        json['id'] ?? json['check_id'] ?? json['property'],
      ),
      property:
          JsonData.text(json['property'] ?? json['name'], fallback: 'Property'),
      drawing: JsonData.text(
        json['drawing'] ?? json['drawing_value'],
        fallback: 'Not supplied',
      ),
      model: JsonData.text(
        json['model'] ?? json['model_value'],
        fallback: 'Not supplied',
      ),
      status: status,
      tolerance: JsonData.text(json['tolerance']),
      details: JsonData.text(json['details'] ?? json['message']),
      reviewStatus: JsonData.text(
        json['review_status'] ?? json['review'],
        fallback: 'not reviewed',
      ),
    );
  }

  final String id;
  final String property;
  final String drawing;
  final String model;
  final String status;
  final String tolerance;
  final String details;
  final String reviewStatus;
}
