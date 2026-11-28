import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/api/api_config.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';
import 'package:jobeval/shared/widgets/pricing_editor.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _openRouterKeyController = TextEditingController();
  final _nvidiaNimKeyController = TextEditingController();
  bool _isSaving = false;
  JsonMap? pricing;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = ApiConfig.baseUrl;
    _loadPricing();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _openRouterKeyController.dispose();
    _nvidiaNimKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadPricing() async {
    try {
      final p = await ref.read(apiClientProvider).getGlobalPricing();
      if (mounted) setState(() => pricing = p);
    } catch (e) {
      // Ignore load errors
    }
  }

  Future<void> _saveBaseUrl() async {
    final url = _baseUrlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      ref.read(apiConfigProvider.notifier).state = url;
      // Recreate the API client with the new base URL
      ref.read(apiClientProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API base URL set to $url'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(error)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      maxWidth: 1200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'JobEval Settings',
            subtitle:
                'Configure the API endpoint, global pricing defaults, and optional LLM explanation settings.',
            actions: [
              OutlinedButton.icon(
                onPressed: _loadPricing,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'API connection',
            subtitle:
                'Change the backend base URL at runtime. Changing it reconnects all API calls immediately.',
            leading: const Icon(Icons.api_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'API base URL',
                    hintText: 'http://127.0.0.1:8000/api/v1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  onSubmitted: (_) => _saveBaseUrl(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveBaseUrl,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save API URL'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              _baseUrlController.text = ApiConfig.baseUrl;
                              ref.read(apiConfigProvider.notifier).state =
                                  ApiConfig.baseUrl;
                            },
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset to default'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'LLM explanation provider (optional)',
            subtitle:
                'LLM explanations are opt-in. Raw CAD files are never sent — only a compact structured summary. '
                'Configure your API keys below to enable explanations.',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _openRouterKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'OpenRouter API Key',
                      hintText: 'sk-or-...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.radio_button_off, size: 20),
                  title: const Text('NVIDIA NIM'),
                  subtitle: const Text(
                    'Provider: integrate.api.nvidia.com · Model: nemotron-3.5',
                  ),
                  trailing: const Text('Server-configured'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _nvidiaNimKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'NVIDIA NIM API Key',
                      hintText: 'nvapi-...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          final openRouterKey =
                              _openRouterKeyController.text.trim();
                          final nvidiaNimKey =
                              _nvidiaNimKeyController.text.trim();
                          try {
                            final futures = <Future<void>>[];
                            if (openRouterKey.isNotEmpty) {
                              futures.add(
                                ref.read(apiClientProvider).saveApiKey(
                                  provider: 'openrouter',
                                  apiKey: openRouterKey,
                                ),
                              );
                            }
                            if (nvidiaNimKey.isNotEmpty) {
                              futures.add(
                                ref.read(apiClientProvider).saveApiKey(
                                  provider: 'nvidia_nim',
                                  apiKey: nvidiaNimKey,
                                ),
                              );
                            }
                            await Future.wait(futures);
                            if (mounted) {
                              setState(() => _isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'API key(s) saved successfully'),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .tertiary,
                                ),
                              );
                            }
                          } catch (error) {
                            if (mounted) {
                              setState(() => _isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(apiErrorMessage(error)),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .error,
                                ),
                              );
                            }
                          }
                        },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save API Keys'),
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
          PricingEditor(
            initialPricing: pricing ?? {},
            saveLabel: 'Save global defaults',
            showQuantity: false,
            onSave: (draft) async {
              await ref.read(apiClientProvider).putGlobalPricing(draft.toJson());
              if (mounted) {
                await _loadPricing();
              }
            },
          ),
        ],
      ),
    );
  }
}
