import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final privacyMode = ref.watch(privacyModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance
          _buildSectionHeader('Appearance', Icons.palette, theme),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                _buildThemeTile(ThemeMode.light, Icons.light_mode, 'Light', 'Light theme', ref, theme),
                _buildThemeTile(ThemeMode.dark, Icons.dark_mode, 'Dark', 'Dark theme', ref, theme),
                _buildThemeTile(ThemeMode.system, Icons.settings_brightness, 'System', 'Follow system theme', ref, theme),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Privacy
          _buildSectionHeader('Privacy & Data', Icons.privacy_tip, theme),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                _buildPrivacyTile(PrivacyMode.local, Icons.computer, 'Local/Private Mode',
                    'All CAD processing stays on your machine or private server', ref, theme),
                _buildPrivacyTile(PrivacyMode.approvedCloud, Icons.cloud, 'Approved Cloud Mode',
                    'Send data to explicitly enabled cloud providers only', ref, theme),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // API Configuration
          _buildSectionHeader('API Configuration', Icons.api, theme),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Backend URL'),
                  subtitle: Text(ref.read(localStorageProvider).getString('api_base_url') ?? 'http://localhost:8000/api/v1'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editApiUrl(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('LLM Provider'),
                  subtitle: Text(ref.read(apiServiceProvider).toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editLLMProvider(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About
          _buildSectionHeader('About', Icons.info, theme),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: const Text('JobEval 0.1.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Documentation'),
                  subtitle: const Text('View API documentation'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/docs'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Report Issue'),
                  subtitle: const Text('Report a bug or request a feature'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(ThemeMode mode, IconData icon, String title, String subtitle, WidgetRef ref, ThemeData theme) {
    final isSelected = ref.watch(themeModeProvider) == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : null),
      title: Text(title),
      trailing: Radio<ThemeMode>(
        value: mode,
        groupValue: ref.watch(themeModeProvider),
        onChanged: (v) => ref.read(themeModeProvider.notifier).setMode(v!),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildPrivacyTile(PrivacyMode mode, IconData icon, String title, String subtitle, WidgetRef ref, ThemeData theme) {
    final isSelected = ref.watch(privacyModeProvider) == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : null),
      title: Text(title),
      trailing: Radio<PrivacyMode>(
        value: mode,
        groupValue: ref.watch(privacyModeProvider),
        onChanged: (v) => ref.read(privacyModeProvider.notifier).setMode(v!),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }

  Color themeColorFromMode(PrivacyMode mode) {
    switch (mode) {
      case PrivacyMode.local:
        return Colors.green;
      case PrivacyMode.approvedCloud:
        return Colors.blue;
    }
  }

  void _editApiUrl(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: ref.read(localStorageProvider).getString('api_base_url') ?? 'http://localhost:8000/api/v1',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Base URL',
            hintText: 'http://localhost:8000/api/v1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(localStorageProvider).setString('api_base_url', controller.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backend URL updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editLLMProvider(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LLM Provider Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-or-v1-... or nvapi-...',
              ),
              obscureText: true,
              onChanged: (v) => ref.read(localStorageProvider).setString('llm_api_key', v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: ref.read(localStorageProvider).getString('llm_provider') ?? 'nvidia_nim',
              decoration: const InputDecoration(
                labelText: 'Provider',
              ),
              items: ['openrouter', 'deepinfra', 'nvidia_nim'].map((p) => DropdownMenuItem(
                value: p,
                child: Text(p),
              )).toList(),
              onChanged: (v) => ref.read(localStorageProvider).setString('llm_provider', v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}