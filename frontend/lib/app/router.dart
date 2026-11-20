import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/features/dashboard/dashboard_screen.dart';
import 'package:jobeval/features/cad_upload/cad_upload_screen.dart';
import 'package:jobeval/features/cad_viewer/cad_viewer_screen.dart';
import 'package:jobeval/features/feature_recognition/feature_recognition_screen.dart';
import 'package:jobeval/features/drawing_analysis/drawing_analysis_screen.dart';
import 'package:jobeval/features/cnc_analysis/cnc_analysis_screen.dart';
import 'package:jobeval/features/material_database/material_database_screen.dart';
import 'package:jobeval/features/cost_estimation/cost_estimation_screen.dart';
import 'package:jobeval/features/reports/reports_screen.dart';
import 'package:jobeval/features/settings/settings_screen.dart';
import 'package:jobeval/features/chat/chat_screen.dart';
import 'package:jobeval/features/dashboard/widgets/project_card.dart';
import 'package:jobeval/core/models/models.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/upload',
          name: 'upload',
          builder: (context, state) => const CadUploadScreen(),
        ),
        GoRoute(
          path: '/project/:projectId',
          name: 'project',
          builder: (context, state) {
            final projectId = state.pathParameters['projectId']!;
            return ProjectShell(projectId: projectId, child: const SizedBox.shrink());
          },
          routes: [
            GoRoute(
              path: 'viewer',
              name: 'viewer',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return CadViewerScreen(projectId: projectId);
              },
            ),
            GoRoute(
              path: 'features',
              name: 'features',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return FeatureRecognitionScreen(projectId: projectId);
              },
            ),
            GoRoute(
              path: 'drawing',
              name: 'drawing',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return DrawingAnalysisScreen(projectId: projectId);
              },
            ),
            GoRoute(
              path: 'manufacturing',
              name: 'manufacturing',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return CncAnalysisScreen(projectId: projectId);
              },
            ),
            GoRoute(
              path: 'materials',
              name: 'materials',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return MaterialDatabaseScreen(projectId: projectId);
              },
            ),
            GoRoute(
              path: 'cost',
              name: 'cost',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return CostEstimationScreen(projectId: projectId);
              },
            ),
            GoRoute(
              path: 'reports',
              name: 'reports',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return ReportsScreen(projectId: projectId);
              },
            ),
            GoRoute(
              path: 'chat',
              name: 'chat',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return ChatScreen(projectId: projectId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'Page Not Found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.error?.toString() ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => context.go('/'),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    ),
  ),
);

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.upload_file_outlined),
      selectedIcon: Icon(Icons.upload_file),
      label: 'Upload',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/upload');
        break;
      case 2:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).colorScheme.surface,
              destinations: _destinations.map((d) => NavigationRailDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: Text(d.label),
              )).toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: _destinations,
      ),
    );
  }
}

class ProjectShell extends StatefulWidget {
  final String projectId;
  final Widget child;

  const ProjectShell({
    super.key,
    required this.projectId,
    required this.child,
  });

  @override
  State<ProjectShell> createState() => _ProjectShellState();
}

class _ProjectShellState extends State<ProjectShell> {
  int _selectedIndex = 0;

  static const List<_ProjectTab> _tabs = [
    _ProjectTab('viewer', 0, Icons.visibility, 'Viewer'),
    _ProjectTab('features', 1, Icons.architecture, 'Features'),
    _ProjectTab('drawing', 2, Icons.description, 'Drawing'),
    _ProjectTab('manufacturing', 3, Icons.factory, 'CNC'),
    _ProjectTab('materials', 4, Icons.inventory, 'Materials'),
    _ProjectTab('cost', 5, Icons.attach_money, 'Cost'),
    _ProjectTab('reports', 6, Icons.assessment, 'Reports'),
    _ProjectTab('chat', 7, Icons.chat, 'AI Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Project ${widget.projectId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {},
            ),
          ],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
                context.go('/project/${widget.projectId}/${_tabs[index].route}');
              },
              labelType: NavigationRailLabelType.all,
              extended: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.primary,
              ),
              unselectedIconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              destinations: _tabs.map((t) => NavigationRailDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.icon, color: Theme.of(context).colorScheme.primary),
                label: Text(t.label),
              )).toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Project ${widget.projectId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          context.go('/project/${widget.projectId}/${_tabs[index].route}');
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          selectedIcon: Icon(t.icon, color: Theme.of(context).colorScheme.primary),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class _ProjectTab {
  final String route;
  final int index;
  final IconData icon;
  final String label;

  _ProjectTab(this.route, this.index, this.icon, this.label);
}