import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/core/models/json_data.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';

class ProjectUploadScreen extends ConsumerStatefulWidget {
  const ProjectUploadScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectUploadScreen> createState() =>
      _ProjectUploadScreenState();
}

class _ProjectUploadScreenState extends ConsumerState<ProjectUploadScreen> {
  final List<PlatformFile> _files = [];
  String _role = 'model_3d';
  bool _picking = false;
  bool _uploading = false;
  bool _analyzing = false;
  double? _progress;
  String _uploadStatus = '';
  String? _analysisStatus;
  double? _analysisProgress;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Upload project files',
            subtitle:
                'Files are sent as multipart data to POST /projects/${widget.projectId}/files.',
            actions: [
              OutlinedButton.icon(
                onPressed: _picking || _uploading
                    ? null
                    : () => context.go('/projects/${widget.projectId}/files'),
                icon: const Icon(Icons.folder_open),
                label: const Text('View files'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final picker = SectionCard(
                title: 'Select source files',
                subtitle:
                    'STEP, IGES, STL, BREP, PDF, DXF, DWG, SVG and images.',
                leading: const Icon(Icons.cloud_upload_outlined),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'File role',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'model_3d',
                          child: Text('3D model'),
                        ),
                        DropdownMenuItem(
                          value: 'drawing_2d',
                          child: Text('2D drawing'),
                        ),
                        DropdownMenuItem(
                          value: 'reference',
                          child: Text('Reference'),
                        ),
                      ],
                      onChanged: _uploading
                          ? null
                          : (value) => setState(() => _role = value ?? _role),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _picking || _uploading ? null : _pickFiles,
                      icon: _picking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_open_outlined),
                      label: Text(
                          _picking ? 'Opening file picker…' : 'Choose files'),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Browser uploads require the file picker to provide in-memory bytes. If a browser or file does not expose readable bytes, upload is disabled rather than showing simulated progress.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              );

              final selected = SectionCard(
                title: 'Selected files (${_files.length})',
                subtitle: _files.isEmpty
                    ? 'No local selection.'
                    : 'Each file is uploaded separately with its own multipart request.',
                leading: const Icon(Icons.checklist),
                trailing: _files.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed:
                            _uploading ? null : () => setState(_files.clear),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                      ),
                child: _files.isEmpty
                    ? const Text('Choose one or more files to continue.')
                    : Column(
                        children: _files.map((file) {
                          final unreadable = file.path == null &&
                              (file.bytes == null || file.bytes!.isEmpty);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              unreadable
                                  ? Icons.warning_amber_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              unreadable
                                  ? 'Readable bytes are unavailable on this platform.'
                                  : '${file.size} bytes · ${file.extension ?? 'unknown'}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove ${file.name}',
                              onPressed: _uploading
                                  ? null
                                  : () => setState(() => _files.remove(file)),
                              icon: const Icon(Icons.close),
                            ),
                          );
                        }).toList(),
                      ),
              );

              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    picker,
                    const SizedBox(height: 16),
                    selected,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: picker),
                  const SizedBox(width: 16),
                  Expanded(child: selected),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Upload and analysis',
            subtitle:
                'Upload completion does not imply geometry analysis completed.',
            leading: const Icon(Icons.play_circle_outline),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_uploading) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                  Text(
                    _uploadStatus.isEmpty ? 'Uploading…' : _uploadStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_analysisStatus != null) ...[
                  Row(
                    children: [
                      Expanded(child: Text(_analysisStatus!)),
                      if (_analysisProgress != null)
                        Text('${(_analysisProgress! * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _analysisProgress),
                  const SizedBox(height: 14),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          _uploading || _files.isEmpty ? null : _uploadFiles,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                          _uploading ? 'Uploading…' : 'Upload selected files'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _analyzing || _uploading ? null : _runAnalysis,
                      icon: const Icon(Icons.architecture_outlined),
                      label: Text(_analyzing
                          ? 'Analysis running…'
                          : 'Run geometry analysis'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const [
          'step',
          'stp',
          'iges',
          'igs',
          'stl',
          'brep',
          'pdf',
          'dxf',
          'dwg',
          'svg',
          'png',
          'jpg',
          'jpeg',
        ],
      );
      if (!mounted || result == null) return;
      setState(() {
        final existing = _files.map((file) => file.name).toSet();
        _files.addAll(
          result.files.where((file) => !existing.contains(file.name)),
        );
      });
    } catch (error) {
      if (mounted) {
        showApiError(
          context,
          StateError(
            'The file picker could not open. Browser or platform permissions may be required.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _uploadFiles() async {
    setState(() {
      _uploading = true;
      _progress = null;
      _uploadStatus = 'Preparing multipart upload…';
    });
    try {
      for (var index = 0; index < _files.length; index++) {
        final file = _files[index];
        setState(() {
          _progress = null;
          _uploadStatus =
              'Uploading ${file.name} (${index + 1}/${_files.length})…';
        });
        await ref.read(apiClientProvider).uploadFile(
              projectId: widget.projectId,
              fileName: file.name,
              role: _role,
              path: file.path,
              bytes: file.bytes,
              onProgress: (sent, total) {
                if (!mounted) return;
                setState(() {
                  _progress = total > 0 ? sent / total : null;
                  _uploadStatus =
                      'Uploading ${file.name} — ${(sent / 1024 / 1024).toStringAsFixed(1)} MB';
                });
              },
            );
      }
      ref.invalidate(filesProvider(widget.projectId));
      if (mounted) {
        setState(() {
          _progress = 1;
          _uploadStatus = 'All selected files were uploaded.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _progress = null;
          _uploadStatus = apiErrorMessage(error);
        });
        showApiError(context, error);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _analyzing = true;
      _analysisStatus = 'Starting analysis…';
      _analysisProgress = null;
    });
    try {
      final response =
          await ref.read(apiClientProvider).startAnalysis(widget.projectId);
      final jobId = JsonData.text(response['job_id'] ?? response['id']);
      if (jobId.isEmpty) {
        ref.invalidate(analysisProvider(widget.projectId));
        if (mounted) {
          setState(() {
            _analysisStatus = 'Analysis request completed.';
            _analysisProgress = 1;
          });
        }
        return;
      }
      await _pollJob(jobId);
      ref.invalidate(analysisProvider(widget.projectId));
      if (mounted) {
        setState(() {
          _analysisStatus = 'Analysis job finished. Opening geometry results…';
          _analysisProgress = 1;
        });
        context.go('/projects/${widget.projectId}/geometry');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _analysisStatus = apiErrorMessage(error));
        showApiError(context, error);
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _pollJob(String jobId) async {
    for (var attempt = 0; attempt < 120; attempt++) {
      if (!mounted) return;
      final job = await ref.read(apiClientProvider).getJob(jobId);
      final status = JsonData.status(job).toLowerCase();
      final progressValue = job['progress'];
      setState(() {
        _analysisStatus = 'Job $jobId: ${JsonData.status(job)}';
        if (progressValue is num) {
          _analysisProgress = progressValue.toDouble().clamp(0, 1);
        }
      });
      if (status == 'completed' ||
          status == 'succeeded' ||
          status == 'success') {
        return;
      }
      if (status == 'failed' || status == 'error' || status == 'cancelled') {
        final reason = JsonData.text(job['error'] ?? job['message']);
        throw StateError(
          reason.isEmpty ? 'Analysis job $jobId failed.' : reason,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError(
      'Analysis job $jobId is still running. Check job status before retrying.',
    );
  }
}
