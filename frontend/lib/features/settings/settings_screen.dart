import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';
import 'package:jobeval/shared/widgets/pricing_editor.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricing = ref.watch(globalPricingProvider);
    return ResponsiveBody(
      maxWidth: 1200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Global pricing defaults',
            subtitle:
                'Defaults are loaded from GET /settings/pricing and saved with PUT /settings/pricing.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(globalPricingProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'API connection',
            subtitle:
                'The base URL is fixed at build time for reproducible deployments.',
            leading: const Icon(Icons.api_outlined),
            child: SelectableText(ref.watch(apiClientProvider).baseUrl),
          ),
          const SizedBox(height: 16),
          pricing.when(
            loading: () => const SizedBox(
              height: 340,
              child: LoadingPanel(label: 'Loading global pricing defaults…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Global pricing defaults could not be loaded',
              message: apiErrorMessage(error),
              onRetry: () => ref.invalidate(globalPricingProvider),
            ),
            data: (data) => PricingEditor(
              initialPricing: data,
              saveLabel: 'Save global defaults',
              showQuantity: false,
              onSave: (draft) async {
                await ref
                    .read(apiClientProvider)
                    .putGlobalPricing(draft.toJson());
                ref.invalidate(globalPricingProvider);
              },
            ),
          ),
        ],
      ),
    );
  }
}
