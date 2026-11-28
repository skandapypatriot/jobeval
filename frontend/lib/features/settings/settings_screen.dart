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
            title: 'JobEval Settings',
            subtitle:
                'Configure global pricing defaults and optional LLM explanation settings.',
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
          SectionCard(
            title: 'LLM explanation provider (optional)',
            subtitle:
                'LLM explanations are opt-in. Raw CAD files are never sent — only a compact structured summary. '
                'API keys are configured server-side in .env; this UI selects which provider to use per request.',
            leading: const Icon(Icons.api_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.radio_button_checked, size: 20),
                  title: const Text('OpenRouter'),
                  subtitle: const Text(
                    'Provider: openrouter.ai · Model: gpt-4o-mini',
                  ),
                  trailing: const Text('Server-configured'),
                ),
                ListTile(
                  leading: const Icon(Icons.radio_button_off, size: 20),
                  title: const Text('NVIDIA NIM'),
                  subtitle: const Text(
                    'Provider: integrate.api.nvidia.com · Model: nemotron-3.5',
                  ),
                  trailing: const Text('Server-configured'),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Data privacy'),
                  subtitle: const Text(
                    'LLM output is advisory only — it cannot change geometry, dimensions, '
                    'feature data, or calculated costs. Zero data retention can be enabled server-side.',
                  ),
                ),
              ],
            ),
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
