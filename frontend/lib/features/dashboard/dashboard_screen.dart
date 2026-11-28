import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/project_models.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    final projects = ref.watch(projectsProvider);
    final jobs = ref.watch(recentJobsProvider);

    return Scaffold(
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'JobEval',
              subtitle:
                  'Review CAD geometry, drawings, manufacturing assumptions, and cost estimates from one workspace.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _createDemo(context, ref),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Create demo'),
                ),
                FilledButton.icon(
                  onPressed: () => _createProject(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('New project'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HealthPanel(health: health),
            const SizedBox(height: 20),
            _ProjectsSection(projects: projects),
            const SizedBox(height: 20),
            _RecentJobsSection(jobs: jobs),
          ],
        ),
      ),
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_ProjectInput>(
      context: context,
      builder: (context) => const _CreateProjectDialog(),
    );
    if (input == null || !context.mounted) return;
    final loading = ScaffoldMessenger.of(context);
    loading.showSnackBar(
      const SnackBar(content: Text('Creating project…')),
    );
    try {
      final response = await ref.read(apiClientProvider).createProject(
            name: input.name,
            description: input.description,
          );
      final id = JsonData.text(response['id'] ?? response['project_id']);
      if (id.isEmpty) {
        throw StateError(
            'The project was created but no project ID was returned.');
      }
      ref.invalidate(projectsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.go('/projects/$id/overview');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showApiError(context, error);
      }
    }
  }

  Future<void> _createDemo(BuildContext context, WidgetRef ref) async {
    final label = await showDialog<String>(
      context: context,
      builder: (context) => const _DemoProjectDialog(),
    );
    if (label == null || !context.mounted) return;
    try {
      final response =
          await ref.read(apiClientProvider).createDemoProject(label: label);
      final id = JsonData.text(response['id'] ?? response['project_id']);
      if (id.isEmpty) {
        throw StateError(
            'The demo was created but no project ID was returned.');
      }
      ref.invalidate(projectsProvider);
      if (context.mounted) context.go('/projects/$id/overview');
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }
}

class _HealthPanel extends ConsumerWidget {
  const _HealthPanel({required this.health});

  final AsyncValue<HealthSnapshot> health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return health.when(
      loading: () => SectionCard(
        title: 'Backend connection',
        subtitle: 'Checking the live API…',
        leading: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        child: const Text('Waiting for GET /health.'),
      ),
      error: (error, _) => SectionCard(
        title: 'Backend offline',
        subtitle: 'The API did not complete the health check.',
        leading: Icon(Icons.cloud_off_outlined, color: scheme.error),
        trailing: FilledButton.tonalIcon(
          onPressed: () => ref.invalidate(healthProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        child: Text(
          apiErrorMessage(error),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      data: (snapshot) {
        final color = switch (snapshot.state) {
          BackendState.online => scheme.tertiary,
          BackendState.degraded => scheme.secondary,
          BackendState.offline => scheme.error,
          BackendState.checking => scheme.primary,
        };
        final label = switch (snapshot.state) {
          BackendState.online => 'Online',
          BackendState.degraded => 'Degraded',
          BackendState.offline => 'Offline response',
          BackendState.checking => 'Checking',
        };
        return SectionCard(
          title: 'Backend connection',
          subtitle: 'Live status from GET /health.',
          leading: Icon(Icons.cloud_done_outlined, color: color),
          trailing: Wrap(
            spacing: 8,
            children: [
              StatusPill(label: label, tone: color),
              IconButton(
                tooltip: 'Retry health check',
                onPressed: () => ref.invalidate(healthProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _HealthDatum(label: 'API status', value: snapshot.status),
              _HealthDatum(
                label: 'Version',
                value: snapshot.version.isEmpty
                    ? 'Not reported'
                    : snapshot.version,
              ),
              _HealthDatum(
                label: 'Service',
                value: snapshot.service.isEmpty
                    ? 'Not reported'
                    : snapshot.service,
              ),
              _HealthDatum(
                  label: 'Base URL',
                  value: ref.watch(apiClientProvider).baseUrl),
            ],
          ),
        );
      },
    );
  }
}

class _HealthDatum extends StatelessWidget {
  const _HealthDatum({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProjectsSection extends ConsumerWidget {
  const _ProjectsSection({required this.projects});

  final AsyncValue<List<JsonMap>> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Recent projects',
      subtitle: 'Projects returned by GET /projects.',
      leading: const Icon(Icons.folder_open_outlined),
      trailing: IconButton(
        tooltip: 'Refresh projects',
        onPressed: () => ref.invalidate(projectsProvider),
        icon: const Icon(Icons.refresh),
      ),
      child: projects.when(
        loading: () => const SizedBox(
          height: 120,
          child: LoadingPanel(label: 'Loading projects…'),
        ),
        error: (error, _) => ErrorPanel(
          title: 'Projects could not be loaded',
          message: apiErrorMessage(error),
          onRetry: () => ref.invalidate(projectsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyPanel(
              title: 'No recent projects',
              message: 'Create a project or a labelled demo to begin a review.',
              icon: Icons.folder_open_outlined,
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 166,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final project = ProjectSummary.fromJson(items[index]);
                  return _ProjectCard(
                    project: project,
                    onOpen: () =>
                        context.go('/projects/${project.id}/overview'),
                    onDelete: () => _deleteProject(context, ref, project),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    ProjectSummary project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          '“${project.name}” and its uploaded files will be deleted from the backend.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).deleteProject(project.id);
      ref.invalidate(projectsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${project.name}.')),
        );
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onDelete,
  });

  final ProjectSummary project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Project actions',
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete project'),
                      ),
                    ],
                  ),
                ],
              ),
              if (project.description.isNotEmpty)
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusPill(label: project.status),
                  StatusPill(label: '${project.fileCount} files'),
                  if (project.hasResults)
                    const StatusPill(
                      label: 'Analysis ready',
                      tone: Color(0xFF167D6A),
                      icon: Icons.check,
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                'Created ${formatDateTime(project.createdAt)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentJobsSection extends ConsumerWidget {
  const _RecentJobsSection({required this.jobs});

  final AsyncValue<List<JsonMap>> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Recent jobs',
      subtitle:
          'Optional job history; hidden when the backend does not expose GET /jobs.',
      leading: const Icon(Icons.hourglass_top_outlined),
      trailing: IconButton(
        tooltip: 'Refresh jobs',
        onPressed: () => ref.invalidate(recentJobsProvider),
        icon: const Icon(Icons.refresh),
      ),
      child: jobs.when(
        loading: () => const SizedBox(
          height: 90,
          child: LoadingPanel(label: 'Checking job history…'),
        ),
        error: (error, _) => Text(
          apiErrorMessage(error),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        data: (items) {
          if (items.isEmpty) {
            return Text(
              'No recent job history is available.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            );
          }
          return Column(
            children: items.take(8).map((job) {
              final id = JsonData.text(job['id'] ?? job['job_id']);
              final status = JsonData.status(job);
              final projectId = JsonData.text(job['project_id']);
              final progress = JsonData.number(job['progress']);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bolt_outlined),
                title: Text('Job ${id.isEmpty ? '—' : id}'),
                subtitle: Text(
                  projectId.isEmpty ? status : 'Project $projectId · $status',
                ),
                trailing: progress > 0
                    ? Text('${(progress * 100).round()}%')
                    : const Icon(Icons.chevron_right),
                onTap: projectId.isEmpty
                    ? null
                    : () => context.go('/projects/$projectId/overview'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create project'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Project name',
                hintText: 'Bracket revision B',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _ProjectInput(name: name, description: _description.text.trim()),
            );
          },
          child: const Text('Create project'),
        ),
      ],
    );
  }
}

class _DemoProjectDialog extends StatefulWidget {
  const _DemoProjectDialog();

  @override
  State<_DemoProjectDialog> createState() => _DemoProjectDialogState();
}

class _DemoProjectDialogState extends State<_DemoProjectDialog> {
  final _label = TextEditingController(text: 'Demo review');

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create labelled demo'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _label,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Demo label',
            helperText: 'The label is sent to POST /projects/demo.',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_label.text.trim().isNotEmpty) {
              Navigator.pop(context, _label.text.trim());
            }
          },
          child: const Text('Create demo'),
        ),
      ],
    );
  }
}

class _ProjectInput {
  const _ProjectInput({required this.name, required this.description});

  final String name;
  final String description;
}
