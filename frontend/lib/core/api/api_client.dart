import 'package:dio/dio.dart';
import 'package:jobeval/core/api/api_config.dart';
import 'package:jobeval/core/api/api_exception.dart';
import 'package:jobeval/core/models/json_data.dart';

class ApiClient {
  ApiClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 90),
                sendTimeout: const Duration(seconds: 90),
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  Future<JsonMap> getHealth() {
    return _requestMap(
      () => _dio.get<dynamic>('/health'),
      action: 'Check backend health',
    );
  }

  Future<List<JsonMap>> listProjects() {
    return _requestList(
      () => _dio.get<dynamic>('/projects'),
      action: 'Load recent projects',
    );
  }

  Future<JsonMap> getProject(String projectId) {
    return _requestMap(
      () => _dio.get<dynamic>('/projects/$projectId'),
      action: 'Load project',
      projectId: projectId,
    );
  }

  Future<JsonMap> createProject({
    required String name,
    String? description,
  }) {
    return _requestMap(
      () => _dio.post<dynamic>(
        '/projects',
        data: {
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
        },
      ),
      action: 'Create project',
    );
  }

  Future<JsonMap> createDemoProject({required String label}) {
    return _requestMap(
      () => _dio.post<dynamic>('/projects/demo', data: {'label': label}),
      action: 'Create labelled demo project',
    );
  }

  Future<JsonMap> updateProject(
    String projectId, {
    required JsonMap changes,
  }) {
    return _requestMap(
      () => _dio.patch<dynamic>('/projects/$projectId', data: changes),
      action: 'Update project',
      projectId: projectId,
    );
  }

  Future<void> deleteProject(String projectId) async {
    await _requestMap(
      () => _dio.delete<dynamic>('/projects/$projectId'),
      action: 'Delete project',
      projectId: projectId,
    );
  }

  Future<List<JsonMap>> listRecentJobs() async {
    try {
      return await _requestList(
        () => _dio.get<dynamic>('/jobs'),
        action: 'Load recent jobs',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<JsonMap> getJob(String jobId) {
    return _requestMap(
      () => _dio.get<dynamic>('/jobs/$jobId'),
      action: 'Load job status',
    );
  }

  Future<List<JsonMap>> listFiles(String projectId) {
    return _requestList(
      () => _dio.get<dynamic>('/projects/$projectId/files'),
      action: 'Load project files',
      projectId: projectId,
    );
  }

  Future<JsonMap> uploadFile({
    required String projectId,
    required String fileName,
    required String role,
    String? path,
    List<int>? bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (path == null && bytes == null) {
      throw const ApiException(
        message: 'This platform did not provide readable file data for upload.',
        action: 'Upload file',
      );
    }
    final MultipartFile multipart;
    if (path != null) {
      multipart = await MultipartFile.fromFile(path, filename: fileName);
    } else {
      multipart = MultipartFile.fromBytes(
        bytes!,
        filename: fileName,
      );
    }
    final form = FormData.fromMap({
      'file': multipart,
      'role': role,
    });
    return _requestMap(
      () => _dio.post<dynamic>(
        '/projects/$projectId/files',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent, total);
        },
      ),
      action: 'Upload file',
      projectId: projectId,
      fileName: fileName,
    );
  }

  Future<void> deleteFile(String fileId, {String? fileName}) async {
    await _requestMap(
      () => _dio.delete<dynamic>('/files/$fileId'),
      action: 'Delete file',
      fileName: fileName,
    );
  }

  Future<JsonMap> startAnalysis(String projectId) {
    return _requestMap(
      () => _dio.post<dynamic>('/projects/$projectId/analysis'),
      action: 'Start geometry analysis',
      projectId: projectId,
    );
  }

  Future<JsonMap> getAnalysis(String projectId) {
    return _requestMap(
      () => _dio.get<dynamic>('/projects/$projectId/analysis'),
      action: 'Load geometry analysis',
      projectId: projectId,
    );
  }

  Future<List<JsonMap>> getFeatures(String projectId) {
    return _requestList(
      () => _dio.get<dynamic>('/projects/$projectId/features'),
      action: 'Load reviewed features',
      projectId: projectId,
    );
  }

  Future<JsonMap> updateFeature(
    String projectId,
    String featureId,
    JsonMap changes,
  ) {
    return _requestMap(
      () => _dio.patch<dynamic>(
        '/projects/$projectId/features/$featureId',
        data: changes,
      ),
      action: 'Update feature review',
      projectId: projectId,
    );
  }

  Future<JsonMap> parseDrawings(String projectId) {
    return _requestMap(
      () => _dio.post<dynamic>('/projects/$projectId/drawings/parse'),
      action: 'Parse drawing',
      projectId: projectId,
    );
  }

  Future<List<JsonMap>> getDrawings(String projectId) {
    return _requestList(
      () => _dio.get<dynamic>('/projects/$projectId/drawings'),
      action: 'Load drawing annotations',
      projectId: projectId,
    );
  }

  Future<JsonMap> runCrossValidation(
    String projectId, {
    JsonMap? request,
  }) {
    return _requestMap(
      () => _dio.post<dynamic>(
        '/projects/$projectId/cross-validation',
        data: request,
      ),
      action: 'Run cross-validation',
      projectId: projectId,
    );
  }

  Future<List<JsonMap>> getCrossValidation(String projectId) {
    return _requestList(
      () => _dio.get<dynamic>('/projects/$projectId/cross-validation'),
      action: 'Load cross-validation results',
      projectId: projectId,
    );
  }

  Future<JsonMap> getManufacturingPlan(String projectId) {
    return _requestMap(
      () => _dio.get<dynamic>('/projects/$projectId/manufacturing-plan'),
      action: 'Load manufacturing plan',
      projectId: projectId,
    );
  }

  Future<JsonMap> putManufacturingPlan(
    String projectId,
    JsonMap plan,
  ) {
    return _requestMap(
      () => _dio.put<dynamic>(
        '/projects/$projectId/manufacturing-plan',
        data: plan,
      ),
      action: 'Save manufacturing plan',
      projectId: projectId,
    );
  }

  Future<JsonMap> getPricing(String projectId) {
    return _requestMap(
      () => _dio.get<dynamic>('/projects/$projectId/pricing'),
      action: 'Load project pricing',
      projectId: projectId,
    );
  }

  Future<JsonMap> putPricing(String projectId, JsonMap pricing) {
    return _requestMap(
      () => _dio.put<dynamic>(
        '/projects/$projectId/pricing',
        data: pricing,
      ),
      action: 'Save project pricing',
      projectId: projectId,
    );
  }

  Future<JsonMap> postEstimate(String projectId, JsonMap pricing) {
    return _requestMap(
      () => _dio.post<dynamic>(
        '/projects/$projectId/estimate',
        data: pricing,
      ),
      action: 'Calculate estimate',
      projectId: projectId,
    );
  }

  Future<JsonMap> getEstimate(String projectId) {
    return _requestMap(
      () => _dio.get<dynamic>('/projects/$projectId/estimate'),
      action: 'Load saved estimate',
      projectId: projectId,
    );
  }

  Future<JsonMap> getReport(String projectId, {required String format}) {
    return _requestMap(
      () => _dio.get<dynamic>(
        '/projects/$projectId/reports',
        queryParameters: {'format': format},
      ),
      action: 'Load $format report',
      projectId: projectId,
    );
  }

  Future<JsonMap> getGlobalPricing() {
    return _requestMap(
      () => _dio.get<dynamic>('/settings/pricing'),
      action: 'Load global pricing defaults',
    );
  }

  Future<JsonMap> putGlobalPricing(JsonMap pricing) {
    return _requestMap(
      () => _dio.put<dynamic>('/settings/pricing', data: pricing),
      action: 'Save global pricing defaults',
    );
  }

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  Future<JsonMap> sendChatMessage({
    required String projectId,
    required String message,
    String? provider,
  }) {
    return _requestMap(
      () => _dio.post<dynamic>(
        '/projects/$projectId/chat',
        data: {
          'message': message,
          if (provider != null) 'provider': provider,
        },
      ),
      action: 'Send chat message',
      projectId: projectId,
    );
  }

  Future<List<JsonMap>> getChatHistory(String projectId) {
    return _requestList(
      () => _dio.get<dynamic>('/projects/$projectId/chat'),
      action: 'Load chat history',
      projectId: projectId,
    );
  }

  // ---------------------------------------------------------------------------
  // File viewing
  // ---------------------------------------------------------------------------

  Future<JsonMap> getFileViewUrl(String fileId) {
    return _requestMap(
      () => _dio.get<dynamic>('/files/$fileId/view'),
      action: 'View file',
      fileName: fileId,
    );
  }

  Future<JsonMap> ocrExtractText({
    required String imagePath,
  }) {
    return _requestMap(
      () => _dio.post<dynamic>(
        '/ocr/extract',
        data: {
          'image_path': imagePath,
        },
      ),
      action: 'OCR extract text',
    );
  }

  Future<JsonMap> _requestMap(
    Future<Response<dynamic>> Function() request, {
    required String action,
    String? projectId,
    String? fileName,
  }) async {
    try {
      final response = await request();
      return _unwrapMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        action: action,
        projectId: projectId,
        fileName: fileName,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        message: 'The request could not be completed.',
        action: action,
        projectId: projectId,
        fileName: fileName,
      );
    }
  }

  Future<List<JsonMap>> _requestList(
    Future<Response<dynamic>> Function() request, {
    required String action,
    String? projectId,
    String? fileName,
  }) async {
    try {
      final response = await request();
      return _unwrapMaps(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        action: action,
        projectId: projectId,
        fileName: fileName,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        message: 'The request could not be completed.',
        action: action,
        projectId: projectId,
        fileName: fileName,
      );
    }
  }

  JsonMap _unwrapMap(dynamic data) {
    if (data is Map) {
      final map = JsonData.map(data);
      final wrapped = map['data'];
      if (wrapped is Map && !map.containsKey('id')) {
        return JsonData.map(wrapped);
      }
      return map;
    }
    return <String, dynamic>{};
  }

  List<JsonMap> _unwrapMaps(dynamic data) {
    if (data is List) return JsonData.maps(data);
    if (data is Map) {
      final map = JsonData.map(data);
      for (final key in const [
        'items',
        'data',
        'results',
        'files',
        'features',
        'operations',
        'setups',
        'jobs',
        'reports',
        'checks',
        'pages',
        'annotations',
      ]) {
        final value = map[key];
        if (value is List) return JsonData.maps(value);
        if (value is Map) {
          for (final nestedKey in const ['items', 'data', 'results']) {
            final nested = value[nestedKey];
            if (nested is List) return JsonData.maps(nested);
          }
        }
      }
    }
    return const [];
  }
}
