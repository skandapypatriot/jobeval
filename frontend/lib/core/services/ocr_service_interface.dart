/// Abstract interface for OCR services.
///
/// Implementations:
/// - [MobileOcrService]: Uses Google ML Kit on-device (iOS/Android)
/// - [WebOcrService]: Sends images to backend for Tesseract OCR
abstract class OcrService {
  /// Whether OCR is available on the current platform.
  bool get isAvailable;

  /// Human-readable status message.
  String get statusMessage;

  /// Extract text from an image file.
  Future<List<String>> extractText(String imagePath);
}
