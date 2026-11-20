import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_service.dart';
import 'api/api_endpoints.dart';
import 'storage/local_storage.dart';
import 'models/models.dart';

const String kDefaultApiBaseUrl = 'http://localhost:8000/api/v1';
const String kApiBaseUrlKey = 'api_base_url';
const String kAuthTokenKey = 'auth_token';
const String kRefreshTokenKey = 'refresh_token';
const String kPrivacyModeKey = 'privacy_mode';
const String kAllowedProvidersKey = 'allowed_providers';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final apiServiceInitializer = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  await ref.read(apiServiceProvider).init(storage);
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

final localStorageProvider = Provider<LocalStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) throw StateError('SharedPreferences not ready');
  return LocalStorage(prefs);
});

enum PrivacyMode { local, approvedCloud }

final privacyModeProvider = StateNotifierProvider<PrivacyModeNotifier, PrivacyMode>((ref) {
  return PrivacyModeNotifier(ref.watch(localStorageProvider));
});

class PrivacyModeNotifier extends StateNotifier<PrivacyMode> {
  final LocalStorage _storage;

  PrivacyModeNotifier(this._storage) : super(PrivacyMode.local) {
    _load();
  }

  void _load() {
    final mode = _storage.getString(kPrivacyModeKey);
    state = (mode == 'approved_cloud') ? PrivacyMode.approvedCloud : PrivacyMode.local;
  }

  Future<void> setMode(PrivacyMode mode) async {
    state = mode;
    await _storage.setString(kPrivacyModeKey, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(localStorageProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorage _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _load();
  }

  void _load() {
    final mode = _storage.getString('theme_mode');
    switch (mode) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.setString('theme_mode', mode.name);
  }
}

final projectsProvider = AsyncNotifierProvider<ProjectsNotifier, List<ProjectSummary>>(ProjectsNotifier.new);

class ProjectsNotifier extends AsyncNotifier<List<ProjectSummary>> {
  @override
  Future<List<ProjectSummary>> build() async {
    return _load();
  }

  Future<List<ProjectSummary>> _load() async {
    final api = ref.read(apiServiceProvider);
    return api.listProjects();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<ProjectDetail> createProject(String name, {String? description}) async {
    final api = ref.read(apiServiceProvider);
    return api.createProject(CreateProjectRequest(name: name, description: description));
  }
}

final projectDetailProvider = FutureProvider.family<ProjectDetail, String>((ref, projectId) async {
  final api = ref.read(apiServiceProvider);
  return api.getProject(projectId);
});

final cadSpecsProvider = FutureProvider.family<CadSpecs, String>((ref, projectId) async {
  final api = ref.read(apiServiceProvider);
  return api.getCadSpecs(projectId);
});

final manufacturingAnalysisProvider = FutureProvider.family<ManufacturingAnalysis, String>((ref, projectId) async {
  final api = ref.read(apiServiceProvider);
  return api.analyzeManufacturing(projectId: projectId);
});

final drawingAnnotationsProvider = FutureProvider.family<DrawingAnnotations, String>((ref, projectId) async {
  final api = ref.read(apiServiceProvider);
  return api.getDrawingAnnotations(projectId);
});

final crossValidationProvider = FutureProvider.family<CrossValidationReport, String>((ref, projectId) async {
  final api = ref.read(apiServiceProvider);
  return api.compareModelDrawing(projectId);
});

final materialsProvider = FutureProvider<List<MaterialInfo>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.listMaterials();
});

final chatMessagesProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.read(apiServiceProvider));
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final ApiService _api;
  String? _currentProjectId;

  ChatNotifier(this._api) : super([]);

  void setProject(String projectId) {
    _currentProjectId = projectId;
    state = [];
  }

  Future<void> sendMessage(String message, {String promptType = 'feature_explanation'}) async {
    if (_currentProjectId == null) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];

    try {
      final res = await _api.chatWithLlm(
        projectId: _currentProjectId!,
        message: message,
        promptType: promptType,
      );

      final aiMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: res['analysis'] ?? res['report'] ?? 'No response from LLM',
        isUser: false,
        timestamp: DateTime.now(),
        sources: List<String>.from(res['sources'] ?? []),
        confidence: (res['confidence'] as num?)?.toDouble(),
      );
      state = [...state, aiMsg];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
          id: 'error',
          text: 'Error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];
    }
  }

  void clear() {
    state = [];
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> sources;
  final double? confidence;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sources = const [],
    this.confidence,
  });
}