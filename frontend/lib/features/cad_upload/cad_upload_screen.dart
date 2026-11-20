import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/models/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jobeval/shared/widgets/empty_state.dart';

class CadUploadScreen extends ConsumerStatefulWidget {
  const CadUploadScreen({super.key});

  @override
  ConsumerState<CadUploadScreen> createState() => _CadUploadScreenState();
}

class _CadUploadScreenState extends ConsumerState<CadUploadScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<PlatformFile> _files = [];
  bool _isCreating = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload CAD Files'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Create New Project',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your CAD files and engineering drawings to begin analysis.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Project Info
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
                      'Project Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Project Name',
                        hintText: 'e.g., Bracket v2',
                        prefixIcon: const Icon(Icons.folder),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Brief description of the part',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // File Upload
            Text(
              'Select Files',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: InkWell(
                onTap: _pickFiles,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 56,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Drag & drop files here or tap to browse',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'STEP, IGES, STL, BREP, DXF, DWG, PDF, SVG, PNG, JPG',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Files
            if (_files.isNotEmpty) ...[
              Text(
                'Selected Files (${_files.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._files.map((file) => _buildFileItem(file)).toList(),
            ],
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCreating ? null : () => context.go('/'),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canCreate ? _createProject : null,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isCreating ? 'Creating...' : 'Create Project'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canCreate =>
      _nameController.text.trim().isNotEmpty &&
      _files.isNotEmpty &&
      !_isCreating;

  Widget _buildFileItem(PlatformFile file) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(_getFileIcon(file.extension), color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatFileSize(file.size)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => setState(() => _files.remove(file)),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'step':
      case 'stp':
      case 'iges':
      case 'igs':
      case 'stl':
      case 'brep':
        return Icons.view_in_ar;
      case 'dxf':
      case 'dwg':
        return Icons.description;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'svg':
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      setState(() {
        _files.addAll(result.files);
      });
    }
  }

  Future<void> _createProject() async {
    setState(() => _isCreating = true);
    try {
      final api = ref.read(apiServiceProvider);
      final project = await api.createProject(CreateProjectRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ));

      // Process first 3D model file
      final modelFile = _files.firstWhere(
        (f) => ['step', 'stp', 'iges', 'igs', 'stl', 'brep'].contains(
          f.extension?.toLowerCase(),
        ),
        orElse: () => _files.first,
      );

      if (modelFile.path != null) {
        final file = File(modelFile.path!);
        await api.processCadFile(
          projectId: project.id,
          file: file,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      if (mounted) {
        context.go('/project/${project.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create project: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}