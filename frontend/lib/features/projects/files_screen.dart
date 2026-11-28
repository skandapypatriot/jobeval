import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/models/project_models.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class ProjectFilesScreen extends ConsumerWidget {
  const ProjectFilesScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(filesProvider(projectId));
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Project files',
            subtitle: 'Original upload status and backend processing state.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(filesProvider(projectId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/projects/$projectId/upload'),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload files'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          files.when(
            loading: () => const SizedBox(
              height: 260,
              child: LoadingPanel(label: 'Loading project files…'),
            ),
            error: (error, _) => ErrorPanel(
              title: 'Files could not be loaded',
              message: apiErrorMessage(error),
              onRetry: () => ref.invalidate(filesProvider(projectId)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyPanel(
                  title: 'No files uploaded',
                  message:
                      'Upload a 3D model or engineering drawing before starting analysis.',
                  icon: Icons.note_add_outlined,
                  action: FilledButton.icon(
                    onPressed: () => context.go('/projects/$projectId/upload'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload files'),
                  ),
                );
              }
              final records = items.map(ProjectFile.fromJson).toList();
              return SectionCard(
                title:
                    '${records.length} file${records.length == 1 ? '' : 's'}',
                subtitle: 'Source names and statuses returned by the backend.',
                leading: const Icon(Icons.folder_open_outlined),
                child: Column(
                  children: records.map((file) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FileRow(
                        file: file,
                        onDelete: () => _deleteFile(context, ref, file),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(
    BuildContext context,
    WidgetRef ref,
    ProjectFile file,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
          '“${file.originalName}” will be removed from this project.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete file'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).deleteFile(
            file.id,
            fileName: file.originalName,
          );
      ref.invalidate(filesProvider(projectId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${file.originalName}.')),
        );
      }
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onDelete});

  final ProjectFile file;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              _iconFor(file.originalName),
              color: theme.colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${file.role} · ${_fileSize(file.sizeBytes)} · uploaded ${formatDateTime(file.uploadedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            label: file.status,
            tone: _statusTone(context, file.status),
          ),
          IconButton(
            tooltip: 'Delete ${file.originalName}',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    final extension =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (const ['step', 'stp', 'iges', 'igs', 'stl', 'brep']
        .contains(extension)) {
      return Icons.view_in_ar_outlined;
    }
    if (const ['pdf', 'dxf', 'dwg', 'svg'].contains(extension)) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _statusTone(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = status.toLowerCase();
    if (normalized == 'processed' || normalized == 'completed') {
      return scheme.tertiary;
    }
    if (normalized == 'failed' || normalized == 'error') return scheme.error;
    if (normalized == 'processing') return scheme.primary;
    return scheme.onSurfaceVariant;
  }

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
