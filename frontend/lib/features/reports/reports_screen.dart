import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/empty_state.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ReportsScreen({super.key, required this.projectId});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedTemplate = 'manufacturing';
  String _selectedFormat = 'pdf';

  final List<String> _templates = ['technical', 'executive', 'manufacturing', 'full'];
  final List<String> _formats = ['pdf', 'html', 'json'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate Report',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create professional manufacturing reports in PDF, HTML, or JSON format.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Configuration
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Configuration',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedTemplate,
                      decoration: const InputDecoration(
                        labelText: 'Report Template',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: _templates.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.toUpperCase()),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedTemplate = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedFormat,
                      decoration: const InputDecoration(
                        labelText: 'Export Format',
                        prefixIcon: Icon(Icons.file_download),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: _formats.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.toUpperCase()),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedFormat = v!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _generateReport(),
                icon: const Icon(Icons.file_present),
                label: const Text('Generate Report'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Report types info
            _buildSectionHeader('Report Types', Icons.info, theme),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              'Technical Report',
              'Detailed engineering analysis with all dimensions, tolerances, and GD&T callouts.',
              Icons.architecture,
              theme,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              'Executive Summary',
              'High-level overview for management review with key metrics and recommendations.',
              Icons.assessment,
              theme,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              'Manufacturing Report',
              'Complete CNC machining plan with setups, operations, tooling, and time estimates.',
              Icons.factory,
              theme,
            ),
            const SizedBox(height: 12),
            _buildReportTypeCard(
              'Full Report',
              'Comprehensive report including all analysis, drawings, and cost estimates.',
              Icons.assessment,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildReportTypeCard(String title, String description, IconData icon, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  void _generateReport() {
    final api = ref.read(apiServiceProvider);
    api.generateReport(
      projectId: widget.projectId,
      template: _selectedTemplate,
      format: _selectedFormat,
    ).then((response) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generated: ${response.reportId}'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });
  }
}