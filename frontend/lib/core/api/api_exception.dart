import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.action,
    this.projectId,
    this.fileName,
  });

  final String message;
  final int? statusCode;
  final String? action;
  final String? projectId;
  final String? fileName;

  String get userMessage {
    final buffer = StringBuffer(message);
    if (projectId != null && projectId!.isNotEmpty) {
      buffer.write(' Project: $projectId.');
    }
    if (fileName != null && fileName!.isNotEmpty) {
      buffer.write(' File: $fileName.');
    }
    if (action != null && action!.isNotEmpty) {
      buffer.write(' Failed action: $action.');
    }
    return buffer.toString();
  }

  factory ApiException.fromDio(
    DioException error, {
    required String action,
    String? projectId,
    String? fileName,
  }) {
    final status = error.response?.statusCode;
    final detail = _extractDetail(error.response?.data);
    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The backend did not respond in time.',
      DioExceptionType.connectionError =>
        'Could not connect to the backend. Check that it is running and reachable.',
      DioExceptionType.badCertificate =>
        'The backend certificate was rejected.',
      DioExceptionType.cancel => 'The request was cancelled.',
      DioExceptionType.badResponse => detail ??
          'The backend rejected the request${status == null ? '' : ' ($status)'}.',
      DioExceptionType.unknown =>
        detail ?? 'The request could not be completed.',
      _ => detail ?? 'The request could not be completed.',
    };
    return ApiException(
      message: message,
      statusCode: status,
      action: action,
      projectId: projectId,
      fileName: fileName,
    );
  }

  static String? _extractDetail(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      final value = data.trim();
      return value.isEmpty ? null : value;
    }
    if (data is Map) {
      final detail = data['detail'] ?? data['message'] ?? data['error'];
      if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      if (detail is Map)
        return detail.values.map((value) => value.toString()).join(' ');
    }
    return null;
  }

  @override
  String toString() => userMessage;
}
