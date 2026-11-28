import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/project_models.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class ProjectOverviewScreen extends ConsumerWidget {
  const ProjectOverviewScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final files = ref.watch(filesProvider(projectId));
    return project.when(
      loading: () => const LoadingPanel(label: 'Loading project…'),
      error: (error, _) => ErrorPanel(
        title: 'Project could not be loaded',
        message: apiErrorMessage(error),
        onRetry: () => ref.invalidate(projectProvider(projectId)),
      ),
      data: (data) {
        final summary = ProjectSummary.fromJson(data);
        final fileItems = files.valueOrNull ?? const <JsonMap>[];
        return ResponsiveBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: summary.name,
                subtitle: summary.description.isEmpty
                    ? 'Project $projectId'
                    : summary.description,
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/projects/$projectId/upload'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload files'),
                  ),
                  FilledButton.icon(
                    onPressed: () =>
                        context.go('/projects/$projectId/geometry'),
                    icon: const Icon(Icons.view_in_ar_outlined),
                    label: const Text('Open geometry'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MetricCard(
                    label: 'Status',
                    value: summary.status,
                    icon: Icons.circle,
                  ),
                  MetricCard(
                    label: 'Files',
                    value: '${fileItems.length}',
                    icon: Icons.insert_drive_file_outlined,
                  ),
                  MetricCard(
                    label: 'Created',
                    value: formatDateTime(summary.createdAt),
                    icon: Icons.schedule,
                  ),
                  MetricCard(
                    label: 'Updated',
                    value: formatDateTime(summary.updatedAt),
                    icon: Icons.update,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 880;
                  final details = SectionCard(
                    title: 'Project record',
                    subtitle: 'Values returned by GET /projects/$projectId.',
                    leading: const Icon(Icons.badge_outlined),
                    child: _KeyValueTable(data: data),
                  );
                  final workflow = SectionCard(
                    title: 'Review workflow',
                    subtitle:
                        'Each stage uses the project data saved by the backend.',
                    leading: const Icon(Icons.route_outlined),
                    child: Column(
                      children: [
                        _WorkflowAction(
                          icon: Icons.folder_copy_outlined,
                          title: 'Files',
                          description: 'Review roles and processing status.',
                          onTap: () =>
                              context.go('/projects/$projectId/files'),
                        ),
                        _WorkflowAction(
                          icon: Icons.architecture_outlined,
                          title: 'Features',
                          description:
                              'Confirm geometry-derived feature records.',
                          onTap: () =>
                              context.go('/projects/$projectId/features'),
                        ),
                        _WorkflowAction(
                          icon: Icons.compare_arrows,
                          title: 'Cross-validation',
                          description:
                              'Compare drawing annotations with the model.',
                          onTap: () => context
                              .go('/projects/$projectId/cross-validation'),
                        ),
                        _WorkflowAction(
                          icon: Icons.price_check_outlined,
                          title: 'Pricing & estimate',
                          description:
                              'Edit assumptions and calculate a saved estimate.',
                          onTap: () =>
                              context.go('/projects/$projectId/pricing'),
                        ),
                        _WorkflowAction(
                          icon: Icons.chat_bubble_outlined,
                          title: 'Chat',
                          description: 'Ask questions about your project.',
                          onTap: () => context.go('/projects/$projectId/chat'),
                        ),
                      ],
                    ),
                  );
                  if (!wide) {
                    return Column(
                      children: [details, const SizedBox(height: 16), workflow],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: details),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: workflow),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkflowAction extends StatelessWidget {
  const _WorkflowAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _KeyValueTable extends StatelessWidget {
  const _KeyValueTable({required this.data});

  final JsonMap data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries
        .where((entry) => !_isComplex(entry.value))
        .toList(growable: false);
    if (entries.isEmpty) {
      return const Text('The project response contains no scalar fields.');
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(0.38),
        1: FlexColumnWidth(0.62),
      },
      children: entries.map((entry) {
        return TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                humanizeKey(entry.key),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(entry.value.toString()),
            ),
          ],
        );
      }).toList(),
    );
  }

  bool _isComplex(dynamic value) => value is Map || value is List;
}
