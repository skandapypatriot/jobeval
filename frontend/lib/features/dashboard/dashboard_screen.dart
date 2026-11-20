import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';
import 'package:jobeval/features/dashboard/widgets/project_card.dart';
import 'package:jobeval/shared/widgets/empty_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JobEval'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.go('/upload'),
            tooltip: 'New Project',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(projectsProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return EmptyState(
              icon: Icons.architecture_outlined,
              title: 'No Projects Yet',
              message: 'Upload your first CAD file or engineering drawing to get started.',
              actionLabel: 'Upload Files',
              onAction: null,
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                return ProjectCard(
                  project: project,
                  onTap: () => context.go('/project/${project.id}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          icon: Icons.error_outline,
          title: 'Failed to Load Projects',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.read(projectsProvider.notifier).refresh(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/upload'),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
        elevation: 4,
      ),
    );
  }
}