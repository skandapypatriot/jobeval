class ApiEndpoints {
  // Auth
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authMe = '/auth/me';

  // Projects / Jobs
  static const String projects = '/projects';
  static String project(String id) => '$projects/$id';
  static String projectStatus(String id) => '$projects/$id/status';
  static String projectFiles(String id) => '$projects/$id/files';
  static String projectResults(String id) => '$projects/$id/results';

  // CAD Processing
  static const String cadProcess = '/cad/process';
  static const String cadFeatures = '/cad/features';
  static const String cadViews = '/cad/views';
  static const String cadExport = '/cad/export';

  // Drawing Analysis
  static const String drawingsProcess = '/drawings/process';
  static const String drawingsExtract = '/drawings/extract';
  static const String drawingsCompare = '/drawings/compare';

  // Manufacturing
  static const String manufacturingAnalyze = '/manufacturing/analyze';
  static const String manufacturingSetups = '/manufacturing/setups';
  static const String manufacturingOperations = '/manufacturing/operations';
  static const String manufacturingEstimate = '/manufacturing/estimate';

  // Materials
  static const String materials = '/materials';
  static String material(String id) => '$materials/$id';
  static const String materialsPricing = '/materials/pricing';

  // Cost Estimation
  static const String costEstimate = '/cost/estimate';
  static const String costBreakdown = '/cost/breakdown';

  // Reports
  static const String reportsGenerate = '/reports/generate';
  static String report(String id) => '/reports/$id';
  static String reportDownload(String id) => '/reports/$id/download';

  // LLM
  static const String llmAnalyze = '/llm/analyze';
  static const String llmReport = '/llm/report';

  // Health
  static const String health = '/health';
  static const String healthReady = '/health/ready';

  // File Upload
  static const String uploadInit = '/upload/init';
  static const String uploadComplete = '/upload/complete';
  static String uploadStatus(String id) => '/upload/$id/status';
}