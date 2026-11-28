import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobeval/core/api/api_client.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/features/projects/pricing_screen.dart';

import 'support/mock_api.dart';

void main() {
  testWidgets('editing pricing PUTs pricing then POSTs a fresh estimate',
      (tester) async {
    final adapter = MockApiAdapter((options) {
      if (options.method == 'GET' && options.path == '/projects/p1/pricing') {
        return const MockResponse(200, {
          'currency': 'INR',
          'quantity': 2,
          'material': 'Aluminum 6061',
          'density_kg_m3': 2700,
          'price': 420,
          'price_basis': 'kg',
          'finished_bbox': {
            'size': {'x': 100, 'y': 50, 'z': 10},
            'bbox': {'min': {'x': 0, 'y': 0, 'z': 0}, 'max': {'x': 100, 'y': 50, 'z': 10}},
          },
          'stock_dimensions': {'x': 104, 'y': 54, 'z': 14},
          'allowances': {'x': 2, 'y': 2, 'z': 2},
          'rates': {
            'machine': 100,
            'labor': 80,
            'setup': 60,
            'tool_change': 30,
            'programming': 50,
            'inspection': 40,
            'finishing': 20,
            'deburr': 10,
          },
          'operation_rates': <Object>[],
          'fixed_overrides': <Object>[],
          'overhead_percent': 10,
          'margin_percent': 5,
          'contingency_percent': 2,
          'tax_percent': 18,
        });
      }
      if (options.method == 'GET' && options.path == '/projects/p1/estimate') {
        return const MockResponse(200, {
          'currency': 'INR',
          'total': 1000,
          'line_items': <Object>[],
        });
      }
      if (options.method == 'PUT' && options.path == '/projects/p1/pricing') {
        return const MockResponse(200, {'status': 'saved'});
      }
      if (options.method == 'POST' && options.path == '/projects/p1/estimate') {
        return const MockResponse(200, {
          'currency': 'INR',
          'quantity': 2,
          'total': 1500,
          'line_items': [
            {
              'name': 'Machine time',
              'quantity': 2,
              'unit': 'hour',
              'rate': 150,
              'basis': 'per_hour',
              'formula': '2 × 150',
              'subtotal': 300,
              'calculation_method': 'calculated',
            },
          ],
        });
      }
      return const MockResponse(404, {'detail': 'not found'});
    });
    final api = ApiClient(dio: mockDio(adapter));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PricingScreen(projectId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    final machineRate = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Machine rate',
    );
    expect(machineRate, findsOneWidget);
    await tester.enterText(machineRate, '150');

    final saveButton = find.widgetWithText(
      FilledButton,
      'Save pricing & recalculate estimate',
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final putIndex = adapter.requests.indexWhere(
      (request) =>
          request.method == 'PUT' && request.path == '/projects/p1/pricing',
    );
    final postIndex = adapter.requests.indexWhere(
      (request) =>
          request.method == 'POST' && request.path == '/projects/p1/estimate',
    );
    expect(putIndex, isNonNegative);
    expect(postIndex, greaterThan(putIndex));

    final savedPricing =
        adapter.requests[putIndex].data as Map<String, dynamic>;
    final rates = savedPricing['rates'] as Map<String, dynamic>;
    expect(rates['machine'], 150);

    expect(find.text('Pricing saved successfully.'), findsOneWidget);
    expect(find.textContaining('1,500'), findsOneWidget);
    expect(find.text('Calculated'), findsOneWidget);
  });

  testWidgets('pricing shows an actionable load error and retry',
      (tester) async {
    final adapter = MockApiAdapter((options) {
      if (options.path == '/projects/p1/pricing') {
        return const MockResponse(500, {'detail': 'pricing store unavailable'});
      }
      return const MockResponse(404, {'detail': 'not found'});
    });
    final api = ApiClient(dio: mockDio(adapter));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(home: PricingScreen(projectId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pricing could not be loaded'), findsOneWidget);
    expect(find.textContaining('pricing store unavailable'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsWidgets);
  });
}
