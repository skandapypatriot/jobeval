import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/shared/widgets/common_widgets.dart';
import 'package:file_picker/file_picker.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  bool _isProcessing = false;
  List<String> _extractedText = [];
  List<Map<String, dynamic>> _extractedDimensions = [];
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _ocrError;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFilePath = result.files.first.path;
        _selectedFileName = result.files.first.name;
        _extractedText = [];
        _extractedDimensions = [];
        _ocrError = null;
      });
    }
  }

  Future<void> _runOcr() async {
    if (_selectedFilePath == null) return;

    setState(() => _isProcessing = true);
    _ocrError = null;

    try {
      final response = await ref.read(apiClientProvider).ocrExtractImage(
            filePath: _selectedFilePath!,
            fileName: _selectedFileName,
          );

      setState(() {
        _extractedText = List<String>.from(response['text'] ?? []);
        _extractedDimensions = List<Map<String, dynamic>>.from(
          response['dimensions'] ?? [],
        );
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _ocrError = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Drawing OCR',
            subtitle:
                'Upload a drawing image to extract dimensions and text using OCR.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => context.go('/projects/${widget.projectId}'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to project'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Upload drawing image',
            subtitle:
                'Upload a photo or scan of your engineering drawing to extract dimensions and text using OCR.',
            leading: const Icon(Icons.cloud_upload_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickImage,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _selectedFileName != null
                        ? _selectedFileName!
                        : 'Select drawing image',
                  ),
                ),
                if (_selectedFileName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected: $_selectedFileName',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isProcessing ? null : _runOcr,
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Run OCR'),
                  ),
                ],
                if (_ocrError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _ocrError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_extractedText.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Extracted text:',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._extractedText.map(
                    (t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        t,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ).toList(),
                ],
              ],
            ),
          ),
          if (_extractedDimensions.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Extracted dimensions',
              subtitle: 'Dimensions automatically detected from OCR text.',
              leading: const Icon(Icons.straighten),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _extractedDimensions.map((dim) {
                  return ListTile(
                    title: Text('${dim['type']} ${dim['value']}'),
                    subtitle: Text(
                      '${dim['text']} (page ${dim['page']})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}