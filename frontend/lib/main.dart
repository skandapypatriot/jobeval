import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jobeval/app/app.dart';
import 'package:jobeval/core/providers.dart';
import 'package:jobeval/core/api/api_service.dart';
import 'package:jobeval/core/storage/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorage(prefs);
  final apiService = ApiService();
  await apiService.init(localStorage);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        localStorageProvider.overrideWith((ref) => localStorage),
        apiServiceProvider.overrideWith((ref) => apiService),
      ],
      child: const JobEvalApp(),
    ),
  );
}