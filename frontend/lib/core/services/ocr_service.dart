/// OCR service factory.
///
/// Returns the platform-appropriate implementation:
/// - Mobile (iOS/Android): Google ML Kit on-device
/// - Web: Backend Tesseract OCR

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'ocr_service_interface.dart';
import 'ocr_service_mobile.dart';
import 'ocr_service_web.dart';

/// Create the appropriate OCR service for the current platform.
OcrService createOcrService() {
  if (kIsWeb) {
    return WebOcrService();
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileOcrService();
  }
  return WebOcrService(); // Fallback to web backend
}
