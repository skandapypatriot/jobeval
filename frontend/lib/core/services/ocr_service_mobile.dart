/// Mobile OCR service using Google ML Kit (iOS/Android).
///
/// Runs text recognition on-device without sending images to a server.
import 'dart:io';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'ocr_service_interface.dart';

/// Mobile implementation of OCR using Google ML Kit.
class MobileOcrService implements OcrService {
  MobileOcrService() : _textRecognizer = GoogleMlKit.vision.textRecognizer();

  final TextRecognizer _textRecognizer;

  @override
  bool get isAvailable => true;

  @override
  String get statusMessage =>
      'OCR via Google ML Kit (on-device, iOS/Android)';

  @override
  Future<List<String>> extractText(String imagePath) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        lines.add(line.text);
      }
    }

    return lines;
  }

  /// Dispose the text recognizer when no longer needed.
  void dispose() {
    _textRecognizer.close();
  }
}
