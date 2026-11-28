import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/features/dashboard/dashboard_screen.dart';
import 'package:jobeval/features/projects/cross_validation_screen.dart';
import 'package:jobeval/features/projects/chat_screen.dart';
import 'package:jobeval/features/projects/ocr_screen.dart';
import 'package:jobeval/features/projects/drawings_screen.dart';
import 'package:jobeval/features/projects/features_screen.dart';
import 'package:jobeval/features/projects/files_screen.dart';
import 'package:jobeval/features/projects/geometry_screen.dart';
import 'package:jobeval/features/projects/manufacturing_screen.dart';
import 'package:jobeval/features/projects/pricing_screen.dart';
import 'package:jobeval/features/projects/project_overview_screen.dart';
import 'package:jobeval/features/projects/report_screen.dart';
import 'package:jobeval/features/projects/upload_screen.dart';
import 'package:jobeval/features/settings/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          name: 'dashboard-alias',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) {
        final projectId = state.pathParameters['projectId']!;
        return ProjectShell(projectId: projectId, child: child);
      },
      routes: [
        GoRoute(
          path: '/projects/:projectId',
          name: 'project',
          redirect: (context, state) {
            return state.uri.pathSegments.length == 2
                ? '/projects/${state.pathParameters['projectId']}/overview'
                : null;
          },
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'overview',
              name: 'project-overview',
              builder: (context, state) => ProjectOverviewScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'files',
              name: 'project-files',
              builder: (context, state) => ProjectFilesScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'upload',
              name: 'project-upload',
              builder: (context, state) => ProjectUploadScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'geometry',
              name: 'project-geometry',
              builder: (context, state) => GeometryScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'features',
              name: 'project-features',
              builder: (context, state) => FeaturesScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'drawings',
              name: 'project-drawings',
              builder: (context, state) => DrawingsScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'cross-validation',
              name: 'project-cross-validation',
              builder: (context, state) => CrossValidationScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'manufacturing',
              name: 'project-manufacturing',
              builder: (context, state) => ManufacturingScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'pricing',
              name: 'project-pricing',
              builder: (context, state) => PricingScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'report',
              name: 'project-report',
              builder: (context, state) => ReportScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'chat',
              name: 'project-chat',
              builder: (context, state) => ChatScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
            GoRoute(
              path: 'ocr',
              name: 'project-ocr',
              builder: (context, state) => OcrScreen(
                projectId: state.pathParameters['projectId']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.route_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 14),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'The requested JobEval route is not available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Go to dashboard'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = location.startsWith('/settings') ? 1 : 0;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (index) {
                context.go(index == 0 ? '/' : '/settings');
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                child: Semantics(
                  label: 'JobEval home',
                  button: true,
                  child: InkWell(
                    onTap: () => context.go('/'),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.precision_manufacturing_outlined),
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) {
          context.go(index == 0 ? '/' : '/settings');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class ProjectShell extends StatefulWidget {
  const ProjectShell({
    super.key,
    required this.projectId,
    required this.child,
  });

  final String projectId;
  final Widget child;

  @override
  State<ProjectShell> createState() => _ProjectShellState();
}

class _ProjectShellState extends State<ProjectShell> {
  final _drawerKey = GlobalKey<ScaffoldState>();

  static const _destinations = [
    _ProjectDestination('overview', Icons.dashboard_outlined, 'Overview'),
    _ProjectDestination('files', Icons.folder_open_outlined, 'Files'),
    _ProjectDestination('upload', Icons.upload_file_outlined, 'Upload'),
    _ProjectDestination('geometry', Icons.view_in_ar_outlined, 'Geometry'),
    _ProjectDestination('features', Icons.architecture_outlined, 'Features'),
    _ProjectDestination('drawings', Icons.description_outlined, 'Drawings'),
    _ProjectDestination(
      'cross-validation',
      Icons.compare_arrows_outlined,
      'Cross-check',
    ),
    _ProjectDestination('manufacturing', Icons.factory_outlined, 'Plan'),
    _ProjectDestination('pricing', Icons.price_check_outlined, 'Pricing'),
    _ProjectDestination('report', Icons.assessment_outlined, 'Report'),
  ];

  int _selectedIndex() {
    final location = GoRouterState.of(context).uri.path;
    final segment = location.split('/').where((part) => part.isNotEmpty).last;
    final index = _destinations.indexWhere((item) => item.route == segment);
    return index < 0 ? 0 : index;
  }

  void _select(int index) {
    context.go('/projects/${widget.projectId}/${_destinations[index].route}');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final selected = _selectedIndex();
    final title = _destinations[selected].label;
    final appBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(
            'Project ${widget.projectId}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      leading: wide
          ? IconButton(
              tooltip: 'Back to dashboard',
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_back),
            )
          : IconButton(
              tooltip: 'Open project navigation',
              onPressed: () => _drawerKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
            ),
      actions: [
        IconButton(
          tooltip: 'Back to dashboard',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
        ),
        const SizedBox(width: 6),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              extended: true,
              minExtendedWidth: 210,
              destinations: _destinations.map((destination) {
                return NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.icon),
                  label: Text(destination.label),
                );
              }).toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      key: _drawerKey,
      appBar: appBar,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              ListTile(
                leading: const Icon(Icons.precision_manufacturing_outlined),
                title: const Text(
                  'JobEval project',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(widget.projectId),
              ),
              const Divider(),
              for (var index = 0; index < _destinations.length; index++)
                ListTile(
                  selected: selected == index,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  leading: Icon(_destinations[index].icon),
                  title: Text(_destinations[index].label),
                  onTap: () {
                    Navigator.pop(context);
                    _select(index);
                  },
                ),
            ],
          ),
        ),
      ),
      body: widget.child,
    );
  }
}

class _ProjectDestination {
  const _ProjectDestination(this.route, this.icon, this.label);

  final String route;
  final IconData icon;
  final String label;
}
