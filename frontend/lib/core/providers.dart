import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobeval/core/api/api_client.dart';
import 'package:jobeval/core/api/api_config.dart';
import 'package:jobeval/core/models/json_data.dart';

final apiConfigProvider = StateProvider<String>((ref) => ApiConfig.baseUrl);

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiConfigProvider);
  return ApiClient(baseUrl: baseUrl);
});

enum BackendState { checking, online, degraded, offline }

class HealthSnapshot {
  const HealthSnapshot({
    required this.state,
    required this.status,
    required this.version,
    required this.service,
    required this.details,
  });

  factory HealthSnapshot.fromJson(JsonMap json) {
    final status = JsonData.text(json['status'], fallback: 'unknown');
    final normalized = status.toLowerCase();
    final state = switch (normalized) {
      'healthy' || 'ok' || 'ready' || 'up' => BackendState.online,
      'degraded' || 'warning' => BackendState.degraded,
      _ => BackendState.offline,
    };
    return HealthSnapshot(
      state: state,
      status: status,
      version: JsonData.text(json['version'] ?? json['app_version']),
      service: JsonData.text(json['service'] ?? json['name']),
      details: json,
    );
  }

  final BackendState state;
  final String status;
  final String version;
  final String service;
  final JsonMap details;
}

final healthProvider = FutureProvider.autoDispose<HealthSnapshot>((ref) async {
  final response = await ref.watch(apiClientProvider).getHealth();
  return HealthSnapshot.fromJson(response);
});

final projectsProvider = FutureProvider.autoDispose<List<JsonMap>>((ref) async {
  return ref.watch(apiClientProvider).listProjects();
});

final recentJobsProvider =
    FutureProvider.autoDispose<List<JsonMap>>((ref) async {
  return ref.watch(apiClientProvider).listRecentJobs();
});

final projectProvider = FutureProvider.autoDispose.family<JsonMap, String>(
  (ref, projectId) async {
    return ref.watch(apiClientProvider).getProject(projectId);
  },
);

final filesProvider = FutureProvider.autoDispose.family<List<JsonMap>, String>(
  (ref, projectId) async {
    return ref.watch(apiClientProvider).listFiles(projectId);
  },
);

final analysisProvider = FutureProvider.autoDispose.family<JsonMap, String>(
  (ref, projectId) async {
    return ref.watch(apiClientProvider).getAnalysis(projectId);
  },
);

final featuresProvider =
    FutureProvider.autoDispose.family<List<JsonMap>, String>(
  (ref, projectId) async {
    return ref.watch(apiClientProvider).getFeatures(projectId);
  },
);

final drawingsProvider =
    FutureProvider.autoDispose.family<List<JsonMap>, String>(
  (ref, projectId) async {
    return ref.watch(apiClientProvider).getDrawings(projectId);
  },
);

final crossValidationProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).getCrossValidation(projectId);
});

final manufacturingPlanProvider =
    FutureProvider.autoDispose.family<JsonMap, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).getManufacturingPlan(projectId);
});

final projectPricingProvider =
    FutureProvider.autoDispose.family<JsonMap, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).getPricing(projectId);
});

final estimateProvider =
    FutureProvider.autoDispose.family<JsonMap, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).getEstimate(projectId);
});

final globalPricingProvider = FutureProvider.autoDispose<JsonMap>((ref) async {
  return ref.watch(apiClientProvider).getGlobalPricing();
});

// ---------------------------------------------------------------------------
// Chat providers
// ---------------------------------------------------------------------------

final chatHistoryProvider =
    FutureProvider.autoDispose.family<List<JsonMap>, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).getChatHistory(projectId);
});

// ---------------------------------------------------------------------------
// File view providers
// ---------------------------------------------------------------------------

final fileViewProvider =
    FutureProvider.autoDispose.family<JsonMap, String>((ref, fileId) async {
  return ref.watch(apiClientProvider).getFileViewUrl(fileId);
});
