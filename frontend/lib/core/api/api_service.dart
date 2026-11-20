import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jobeval/core/api/api_endpoints.dart';
import 'package:jobeval/core/models/models.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/storage/local_storage.dart';

class ApiService {
  static ApiService? _instance;
  Dio? _dio;

  ApiService._internal();

  factory ApiService() {
    _instance ??= ApiService._internal();
    return _instance!;
  }

  Future<void> init(LocalStorage storage) async {
    final baseUrl = storage.getString(kApiBaseUrlKey) ?? kDefaultApiBaseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio!.interceptors.add(AuthInterceptor(storage));

    if (!kReleaseMode) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ));
    }
  }

  Dio get dio => _dio!;

  Future<HealthResponse> healthCheck() async {
    final res = await _dio!.get(ApiEndpoints.health);
    return HealthResponse.fromJson(res.data);
  }

  Future<ReadinessResponse> readinessCheck() async {
    final res = await _dio!.get(ApiEndpoints.healthReady);
    return ReadinessResponse.fromJson(res.data);
  }

  Future<List<ProjectSummary>> listProjects({String? status}) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    final res = await _dio!.get(ApiEndpoints.projects, queryParameters: queryParams);
    return (res.data['items'] ?? res.data['data'] ?? [] as List)
        .map((e) => ProjectSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectDetail> createProject(CreateProjectRequest request) async {
    final res = await _dio!.post(ApiEndpoints.projects, data: request.toJson());
    return ProjectDetail.fromJson(res.data);
  }

  Future<ProjectDetail> getProject(String projectId) async {
    final res = await _dio!.get(ApiEndpoints.project(projectId));
    return ProjectDetail.fromJson(res.data);
  }

  Future<void> deleteProject(String projectId) async {
    await _dio!.delete(ApiEndpoints.project(projectId));
  }

  Future<JobStatus> getJobStatus(String projectId) async {
    final res = await _dio!.get(ApiEndpoints.projectStatus(projectId));
    return JobStatus.fromJson(res.data);
  }

  Future<Map<String, dynamic>> processCadFile({
    required String projectId,
    required File file,
    Function(double)? onProgress,
  }) async {
    final fileName = file.path.split('/').last;
    final fileSize = await file.length();

    final initRes = await _dio!.post(ApiEndpoints.uploadInit, data: {
      'project_id': projectId,
      'filename': fileName,
      'file_size': fileSize,
      'mime_type': 'application/octet-stream',
      'role': 'model_3d',
    });

    final uploadId = initRes.data['upload_id'] as String;
    final uploadUrl = initRes.data['upload_url'] as String;

    await _dio!.put(
      uploadUrl,
      data: await MultipartFile.fromFile(file.path, filename: fileName),
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileSize.toString(),
        },
      ),
      onSendProgress: (sent, total) {
        if (onProgress != null) onProgress(sent / total);
      },
    );

    await _dio!.post(ApiEndpoints.uploadComplete, data: {
      'upload_id': uploadId,
      'part_etags': [],
    });

    final fileId = initRes.data['file_id'] as String;

    final processRes = await _dio!.post(ApiEndpoints.cadProcess, data: {
      'project_id': projectId,
      'file_id': fileId,
    });

    return {
      'job_id': processRes.data['job_id'],
      'status': processRes.data['status'],
      'file_id': fileId,
    };
  }

  Future<CadSpecs> getCadSpecs(String projectId) async {
    final res = await _dio!.get(ApiEndpoints.projectResults(projectId));
    return CadSpecs.fromJson(res.data);
  }

  Future<Map<String, dynamic>> processDrawingFile({
    required String projectId,
    required File file,
  }) async {
    final fileName = file.path.split('/').last;
    final fileSize = await file.length();

    final initRes = await _dio!.post(ApiEndpoints.uploadInit, data: {
      'project_id': projectId,
      'filename': fileName,
      'file_size': fileSize,
      'mime_type': 'application/pdf',
      'role': 'drawing_2d',
    });

    final uploadId = initRes.data['upload_id'] as String;
    final uploadUrl = initRes.data['upload_url'] as String;

    await _dio!.put(
      uploadUrl,
      data: await MultipartFile.fromFile(file.path, filename: fileName),
      options: Options(headers: {'Content-Type': 'application/pdf'}),
    );

    await _dio!.post(ApiEndpoints.uploadComplete, data: {
      'upload_id': uploadId,
      'part_etags': [],
    });

    final fileId = initRes.data['file_id'] as String;

    final processRes = await _dio!.post(ApiEndpoints.drawingsProcess, data: {
      'project_id': projectId,
      'file_id': fileId,
    });

    return processRes.data;
  }

  Future<DrawingAnnotations> getDrawingAnnotations(String projectId) async {
    final res = await _dio!.get(ApiEndpoints.drawingsExtract,
        queryParameters: {'project_id': projectId});
    return DrawingAnnotations.fromJson(res.data);
  }

  Future<CrossValidationReport> compareModelDrawing(String projectId) async {
    final res = await _dio!.post(ApiEndpoints.drawingsCompare,
        data: {'project_id': projectId});
    return CrossValidationReport.fromJson(res.data);
  }

  Future<ManufacturingAnalysis> analyzeManufacturing({
    required String projectId,
    String machineId = 'generic_3axis',
    String materialId = 'aluminum_6061',
  }) async {
    final res = await _dio!.post(ApiEndpoints.manufacturingAnalyze, data: {
      'project_id': projectId,
      'machine_id': machineId,
      'material_id': materialId,
    });
    return ManufacturingAnalysis.fromJson(res.data);
  }

  Future<List<Setup>> getSetups(String projectId) async {
    final res = await _dio!.get(ApiEndpoints.manufacturingSetups,
        queryParameters: {'project_id': projectId});
    return (res.data as List).map((e) => Setup.fromJson(e)).toList();
  }

  Future<List<Operation>> getOperations(String projectId) async {
    final res = await _dio!.get(ApiEndpoints.manufacturingOperations,
        queryParameters: {'project_id': projectId});
    return (res.data as List).map((e) => Operation.fromJson(e)).toList();
  }

  Future<List<MaterialInfo>> listMaterials({String? category}) async {
    final queryParams = <String, dynamic>{};
    if (category != null) queryParams['category'] = category;
    final res = await _dio!.get(ApiEndpoints.materials, queryParameters: queryParams);
    return (res.data as List).map((e) => MaterialInfo.fromJson(e)).toList();
  }

  Future<MaterialInfo> getMaterial(String materialId) async {
    final res = await _dio!.get(ApiEndpoints.material(materialId));
    return MaterialInfo.fromJson(res.data);
  }

  Future<MaterialPricing> getMaterialPricing({
    required String materialId,
    required String region,
    required double stockWeightKg,
  }) async {
    final res = await _dio!.post(ApiEndpoints.materialsPricing, data: {
      'material_id': materialId,
      'region': region,
      'stock_weight_kg': stockWeightKg,
    });
    return MaterialPricing.fromJson(res.data);
  }

  Future<CostEstimate> estimateCost({
    required String projectId,
    required String materialId,
    required String region,
    required int quantity,
  }) async {
    final res = await _dio!.post(ApiEndpoints.costEstimate, data: {
      'project_id': projectId,
      'material_id': materialId,
      'region': region,
      'quantity': quantity,
    });
    return CostEstimate.fromJson(res.data);
  }

  Future<ReportGenerationResponse> generateReport({
    required String projectId,
    String template = 'manufacturing',
    String format = 'pdf',
  }) async {
    final res = await _dio!.post(ApiEndpoints.reportsGenerate, data: {
      'project_id': projectId,
      'template': template,
      'format': format,
    });
    return ReportGenerationResponse.fromJson(res.data);
  }

  Future<Map<String, dynamic>> chatWithLlm({
    required String projectId,
    required String message,
    String promptType = 'feature_explanation',
  }) async {
    final res = await _dio!.post(ApiEndpoints.llmAnalyze, data: {
      'project_id': projectId,
      'prompt_type': promptType,
      'context': {'message': message},
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getLlmPrivacyInfo() async {
    final res = await _dio!.get(ApiEndpoints.llmAnalyze.replaceAll('/analyze', '/privacy'));
    return res.data;
  }
}

class AuthInterceptor extends Interceptor {
  final LocalStorage _storage;

  AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _storage.getString(kAuthTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}