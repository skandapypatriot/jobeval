import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/core/api/api_client.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/features/dashboard/dashboard_screen.dart';
import 'package:jobeval/features/projects/project_overview_screen.dart';

import 'support/mock_api.dart';

void main() {
  testWidgets('dashboard reports an online backend and version',
      (tester) async {
    final adapter = MockApiAdapter((options) {
      if (options.path == '/health') {
        return const MockResponse(200, {
          'status': 'healthy',
          'version': '2.4.1',
          'service': 'jobeval',
        });
      }
      if (options.path == '/projects') {
        return const MockResponse(200, {'items': <Object>[]});
      }
      return const MockResponse(404, {'detail': 'not found'});
    });
    final api = ApiClient(dio: mockDio(adapter));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('2.4.1'), findsOneWidget);
    expect(find.text('healthy'), findsOneWidget);
  });

  testWidgets('dashboard shows offline state and retries health',
      (tester) async {
    final adapter = MockApiAdapter((options) {
      if (options.path == '/health') {
        return const MockResponse(503, {'detail': 'service unavailable'});
      }
      return const MockResponse(404, {'detail': 'not found'});
    });
    final api = ApiClient(dio: mockDio(adapter));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend offline'), findsOneWidget);
    expect(find.textContaining('service unavailable'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry').first);
    await tester.pumpAndSettle();

    expect(
      adapter.paths.where((path) => path == '/health').length,
      2,
    );
  });

  testWidgets('dashboard exposes a loading state while health is pending',
      (tester) async {
    final healthResponse = Completer<MockResponse>();
    final adapter = MockApiAdapter((options) {
      if (options.path == '/health') return healthResponse.future;
      return const MockResponse(404, {'detail': 'not found'});
    });
    final api = ApiClient(dio: mockDio(adapter));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Checking the live API…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    healthResponse.complete(const MockResponse(200, {'status': 'healthy'}));
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('create project sends a real POST and opens the project',
      (tester) async {
    final adapter = MockApiAdapter((options) {
      if (options.method == 'POST' && options.path == '/projects') {
        return const MockResponse(201, {
          'id': 'project-1',
          'name': 'Test bracket',
          'status': 'pending',
          'created_at': '2026-01-01T10:00:00Z',
        });
      }
      if (options.path == '/health') {
        return const MockResponse(200, {'status': 'healthy'});
      }
      if (options.path == '/projects' && options.method == 'GET') {
        return const MockResponse(200, {'items': <Object>[]});
      }
      if (options.path == '/projects/project-1' && options.method == 'GET') {
        return const MockResponse(200, {
          'id': 'project-1',
          'name': 'Test bracket',
          'status': 'pending',
          'created_at': '2026-01-01T10:00:00Z',
        });
      }
      if (options.path == '/projects/project-1/files') {
        return const MockResponse(200, {'items': <Object>[]});
      }
      return const MockResponse(404, {'detail': 'not found'});
    });
    final api = ApiClient(dio: mockDio(adapter));
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        GoRoute(
          path: '/projects/:projectId/overview',
          builder: (_, state) => ProjectOverviewScreen(
            projectId: state.pathParameters['projectId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New project'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Project name'),
      'Test bracket',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create project'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.any(
        (request) => request.method == 'POST' && request.path == '/projects',
      ),
      isTrue,
    );
    expect(find.text('Test bracket'), findsWidgets);
    expect(find.text('Project record'), findsOneWidget);
  });
}
