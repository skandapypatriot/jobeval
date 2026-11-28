import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  JsonMap? _jsonReport;
  bool _loadingJson = false;
  String? _reportError;

  @override
  Widget build(BuildContext context) {
    final estimate = ref.watch(estimateProvider(widget.projectId));
    final links = {
      'JSON': _reportUrl('json'),
      'HTML': _reportUrl('html'),
      'CSV': _reportUrl('csv'),
    };
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Project report',
            subtitle:
                'The summary is derived from the saved estimate; format links point to the backend report endpoint.',
            actions: [
              OutlinedButton.icon(
                onPressed: _loadingJson ? null : _loadJsonReport,
                icon: _loadingJson
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Load JSON report'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          estimate.when(
            loading: () => const SizedBox(
              height: 190,
              child: LoadingPanel(label: 'Loading saved estimate summary…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Report summary could not be created',
              message: apiErrorMessage(error),
              onRetry: () => ref.invalidate(estimateProvider(widget.projectId)),
            ),
            data: (data) => _ReportSummary(estimate: data),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Report formats',
            subtitle:
                'Each button opens a live backend URL. The browser or desktop handler performs the request.',
            leading: const Icon(Icons.download_outlined),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: links.entries.map((entry) {
                return OutlinedButton.icon(
                  onPressed: () => _openReport(entry.value),
                  icon: const Icon(Icons.open_in_new),
                  label: Text('Open ${entry.key}'),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'JSON report response',
            subtitle: _jsonReport == null
                ? 'Load the JSON report to inspect optional backend content.'
                : 'Response returned by GET /projects/${widget.projectId}/reports?format=json.',
            leading: const Icon(Icons.data_object),
            child: _reportError != null
                ? ErrorPanel(
                    title: 'JSON report could not be loaded',
                    message: _reportError!,
                    onRetry: _loadJsonReport,
                  )
                : _jsonReport == null
                    ? const Text(
                        'No JSON report has been loaded in this session.')
                    : _JsonReportContent(report: _jsonReport!),
          ),
        ],
      ),
    );
  }

  String _reportUrl(String format) {
    final base =
        ref.read(apiClientProvider).baseUrl.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse(
      '$base/projects/${widget.projectId}/reports',
    ).replace(queryParameters: {'format': format});
    if (uri.hasScheme) return uri.toString();
    return Uri.base.resolve(uri.toString()).toString();
  }

  Future<void> _openReport(String url) async {
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('The operating system did not open the report URL.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open report: $url')),
        );
      }
    }
  }

  Future<void> _loadJsonReport() async {
    setState(() {
      _loadingJson = true;
      _reportError = null;
    });
    try {
      final report = await ref
          .read(apiClientProvider)
          .getReport(widget.projectId, format: 'json');
      if (mounted) setState(() => _jsonReport = report);
    } catch (error) {
      if (mounted) setState(() => _reportError = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loadingJson = false);
    }
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.estimate});

  final JsonMap estimate;

  @override
  Widget build(BuildContext context) {
    final currency = JsonData.text(estimate['currency'], fallback: 'INR');
    final formatter = NumberFormat.simpleCurrency(name: currency);
    final total = _firstNumber(
      estimate,
      const ['total', 'grand_total', 'total_cost', 'final_total'],
    );
    final lines = JsonData.firstMaps(estimate, const [
      'line_items',
      'items',
      'breakdown',
      'cost_lines',
      'operations',
    ]);
    final quantity = JsonData.integer(
      estimate['quantity'] ?? estimate['qty'],
      fallback: 1,
    );
    return SectionCard(
      title: 'Deterministic estimate summary',
      subtitle: 'Built only from the saved estimate response.',
      leading: const Icon(Icons.summarize_outlined),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          MetricCard(
            label: 'Total',
            value: formatter.format(total),
            icon: Icons.payments_outlined,
          ),
          MetricCard(
            label: 'Currency',
            value: currency,
            icon: Icons.currency_exchange,
          ),
          MetricCard(
            label: 'Quantity',
            value: '$quantity',
            icon: Icons.numbers,
          ),
          MetricCard(
            label: 'Estimate lines',
            value: '${lines.length}',
            icon: Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }

  double _firstNumber(JsonMap map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}

class _JsonReportContent extends StatelessWidget {
  const _JsonReportContent({required this.report});

  final JsonMap report;

  @override
  Widget build(BuildContext context) {
    final explanation = JsonData.text(
      report['explanation'] ?? report['optional_explanation'],
    );
    final summary = JsonData.nested(report, 'summary');
    final summaryExplanation =
        summary == null ? '' : JsonData.text(summary['explanation']);
    final backendExplanation =
        explanation.isNotEmpty ? explanation : summaryExplanation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (backendExplanation.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend-provided explanation',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  backendExplanation,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (report.isEmpty)
          const Text('The backend returned an empty JSON report.')
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: SelectableText(_prettyJson(report)),
            ),
          ),
      ],
    );
  }

  String _prettyJson(JsonMap map) {
    return const JsonEncoderWithIndent().convert(map);
  }
}

class JsonEncoderWithIndent {
  const JsonEncoderWithIndent();

  String convert(Object? value) {
    return _convert(value, 0);
  }

  String _convert(Object? value, int depth) {
    final indent = '  ' * depth;
    final childIndent = '  ' * (depth + 1);
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final entries = value.entries.map((entry) {
        return '$childIndent${entry.key}: ${_convert(entry.value, depth + 1)}';
      }).join(',\n');
      return '{\n$entries\n$indent}';
    }
    if (value is List) {
      if (value.isEmpty) return '[]';
      final entries = value
          .map((item) => '$childIndent${_convert(item, depth + 1)}')
          .join(',\n');
      return '[\n$entries\n$indent]';
    }
    if (value == null) return 'null';
    if (value is String)
      return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
    return value.toString();
  }
}
