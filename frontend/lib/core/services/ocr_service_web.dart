/// Web OCR service that sends images to the backend for processing.
///
/// On web, images are uploaded to the backend which runs Tesseract OCR.
import 'package:jobeval/core/api/api_client.dart';
import 'ocr_service_interface.dart';

/// Web implementation of OCR that sends images to the backend.
class WebOcrService implements OcrService {
  WebOcrService() : _api = ApiClient();

  final ApiClient _api;

  @override
  bool get isAvailable => true;

  @override
  String get statusMessage =>
      'OCR via backend (Tesseract)';

  @override
  Future<List<String>> extractText(String imagePath) async {
    try {
      final response = await _api.ocrExtractText(
        imagePath: imagePath,
      );
      final texts = response['text'] as List<dynamic>?;
      if (texts != null) {
        return texts.cast<String>();
      }
      return [];
    } catch (e) {
      throw Exception('Backend OCR failed: $e');
    }
  }
}
