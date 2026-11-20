import 'package:dio/dio.dart';
import 'package:jobeval/core/api/api_endpoints.dart';
import 'package:jobeval/core/models/models.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  // =============================================================================
  // Health
  // =============================================================================

  Future<HealthResponse> healthCheck() async {
    final response = await _dio.get(ApiEndpoints.health);
    return HealthResponse.fromJson(response.data);
  }

  Future<ReadinessResponse> readinessCheck() async {
    final response = await _dio.get(ApiEndpoints.healthReady);
    return ReadinessResponse.fromJson(response.data);
  }

  // =============================================================================
  // Projects
  // =============================================================================

  Future<PaginatedResponse<ProjectSummary>> listProjects({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final response = await _dio.get(ApiEndpoints.projects, queryParameters: {
      'page': page,
      'page_size': pageSize,
      if (status != null) 'status': status,
    });
    return PaginatedResponse.fromJson(response.data, ProjectSummary.fromJson);
  }

  Future<ProjectDetail> getProject(String projectId) async {
    final response = await _dio.get(ApiEndpoints.project(projectId));
    return ProjectDetail.fromJson(response.data);
  }

  Future<ProjectDetail> createProject(CreateProjectRequest request) async {
    final response = await _dio.post(ApiEndpoints.projects, data: request.toJson());
    return ProjectDetail.fromJson(response.data);
  }

  Future<void> deleteProject(String projectId) async {
    await _dio.delete(ApiEndpoints.project(projectId));
  }

  Future<JobStatus> getJobStatus(String projectId) async {
    final response = await _dio.get(ApiEndpoints.projectStatus(projectId));
    return JobStatus.fromJson(response.data);
  }

  // =============================================================================
  // File Upload
  // =============================================================================

  Future<UploadInitResponse> initUpload(UploadInitRequest request) async {
    final response = await _dio.post(ApiEndpoints.uploadInit, data: request.toJson());
    return UploadInitResponse.fromJson(response.data);
  }

  Future<void> uploadFile({
    required String uploadUrl,
    required String filePath,
    required String fileName,
    required int fileSize,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
  }) async {
    // For direct upload to MinIO/S3, use a separate Dio instance without base URL
    final uploadDio = Dio();
    await uploadDio.put(
      uploadUrl,
      data: await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
      options: Options(
        headers: {
          'Content-Type': mimeType,
          'Content-Length': fileSize.toString(),
        },
      ),
      onSendProgress: onProgress,
    );
  }

  Future<UploadCompleteResponse> completeUpload(String uploadId, List<String> partEtags) async {
    final response = await _dio.post(ApiEndpoints.uploadComplete, data: {
      'upload_id': uploadId,
      'part_etags': partEtags,
    });
    return UploadCompleteResponse.fromJson(response.data);
  }

  // =============================================================================
  // CAD Processing
  // =============================================================================

  Future<CadProcessResponse> processCad(CadProcessRequest request) async {
    final response = await _dio.post(ApiEndpoints.cadProcess, data: request.toJson());
    return CadProcessResponse.fromJson(response.data);
  }

  Future<CadSpecs> getCadSpecs(String projectId) async {
    final response = await _dio.get(ApiEndpoints.projectResults(projectId));
    return CadSpecs.fromJson(response.data);
  }

  Future<List<CadView>> getCadViews(String projectId) async {
    final response = await _dio.get(ApiEndpoints.cadViews, queryParameters: {
      'project_id': projectId,
    });
    return (response.data as List).map((e) => CadView.fromJson(e)).toList();
  }

  Future<CadExportResponse> exportCad(CadExportRequest request) async {
    final response = await _dio.post(ApiEndpoints.cadExport, data: request.toJson());
    return CadExportResponse.fromJson(response.data);
  }

  // =============================================================================
  // Feature Recognition
  // =============================================================================

  Future<FeatureRecognitionResult> getFeatures(String projectId) async {
    final response = await _dio.get('${ApiEndpoints.cadFeatures}/$projectId');
    return FeatureRecognitionResult.fromJson(response.data);
  }

  // =============================================================================
  // Drawing Analysis
  // =============================================================================

  Future<DrawingProcessResponse> processDrawing(DrawingProcessRequest request) async {
    final response = await _dio.post(ApiEndpoints.drawingsProcess, data: request.toJson());
    return DrawingProcessResponse.fromJson(response.data);
  }

  Future<DrawingAnnotations> getDrawingAnnotations(String projectId) async {
    final response = await _dio.get(ApiEndpoints.drawingsExtract, queryParameters: {
      'project_id': projectId,
    });
    return DrawingAnnotations.fromJson(response.data);
  }

  Future<CrossValidationReport> compareModelDrawing(String projectId) async {
    final response = await _dio.post(ApiEndpoints.drawingsCompare, data: {
      'project_id': projectId,
    });
    return CrossValidationReport.fromJson(response.data);
  }

  // =============================================================================
  // Manufacturing Analysis
  // =============================================================================

  Future<ManufacturingAnalysis> analyzeManufacturing(ManufacturingRequest request) async {
    final response = await _dio.post(ApiEndpoints.manufacturingAnalyze, data: request.toJson());
    return ManufacturingAnalysis.fromJson(response.data);
  }

  Future<List<Setup>> getSetups(String projectId) async {
    final response = await _dio.get(ApiEndpoints.manufacturingSetups, queryParameters: {
      'project_id': projectId,
    });
    return (response.data as List).map((e) => Setup.fromJson(e)).toList();
  }

  Future<List<Operation>> getOperations(String projectId) async {
    final response = await _dio.get(ApiEndpoints.manufacturingOperations, queryParameters: {
      'project_id': projectId,
    });
    return (response.data as List).map((e) => Operation.fromJson(e)).toList();
  }

  // =============================================================================
  // Materials
  // =============================================================================

  Future<List<MaterialInfo>> listMaterials({
    String? category,
    String? search,
  }) async {
    final response = await _dio.get(ApiEndpoints.materials, queryParameters: {
      if (category != null) 'category': category,
      if (search != null) 'search': search,
    });
    return (response.data as List).map((e) => MaterialInfo.fromJson(e)).toList();
  }

  Future<MaterialInfo> getMaterial(String materialId) async {
    final response = await _dio.get(ApiEndpoints.material(materialId));
    return MaterialInfo.fromJson(response.data);
  }

  Future<MaterialPricing> getMaterialPricing(MaterialPricingRequest request) async {
    final response = await _dio.post(ApiEndpoints.materialsPricing, data: request.toJson());
    return MaterialPricing.fromJson(response.data);
  }

  // =============================================================================
  // Cost Estimation
  // =============================================================================

  Future<CostEstimate> estimateCost(CostEstimateRequest request) async {
    final response = await _dio.post(ApiEndpoints.costEstimate, data: request.toJson());
    return CostEstimate.fromJson(response.data);
  }

  Future<CostBreakdown> getCostBreakdown(String projectId) async {
    final response = await _dio.get(ApiEndpoints.costBreakdown, queryParameters: {
      'project_id': projectId,
    });
    return CostBreakdown.fromJson(response.data);
  }

  // =============================================================================
  // Reports
  // =============================================================================

  Future<ReportGenerationResponse> generateReport(ReportGenerationRequest request) async {
    final response = await _dio.post(ApiEndpoints.reportsGenerate, data: request.toJson());
    return ReportGenerationResponse.fromJson(response.data);
  }

  Future<Report> getReport(String reportId) async {
    final response = await _dio.get(ApiEndpoints.report(reportId));
    return Report.fromJson(response.data);
  }

  Future<Response> downloadReport(String reportId, {String format = 'pdf'}) async {
    return _dio.get(
      ApiEndpoints.reportDownload(reportId),
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  // =============================================================================
  // LLM Integration
  // =============================================================================

  Future<LlmAnalysisResponse> analyzeWithLlm(LlmAnalysisRequest request) async {
    final response = await _dio.post(ApiEndpoints.llmAnalyze, data: request.toJson());
    return LlmAnalysisResponse.fromJson(response.data);
  }

  Future<LlmReportResponse> generateLlmReport(LlmReportRequest request) async {
    final response = await _dio.post(ApiEndpoints.llmReport, data: request.toJson());
    return LlmReportResponse.fromJson(response.data);
  }
}