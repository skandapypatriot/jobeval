class ApiConfig {
  const ApiConfig._();

  /// Override at build time, for example:
  /// flutter run --dart-define=API_BASE_URL=/api/v1
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  static String get baseUrl {
    final value = configuredBaseUrl.trim();
    if (value.isEmpty) return 'http://127.0.0.1:8000/api/v1';
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static Uri endpoint(String path, [Map<String, dynamic>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    final values = <String, List<String>>{};
    for (final entry in query.entries) {
      if (entry.value == null) continue;
      values[entry.key] = [entry.value.toString()];
    }
    return uri.replace(queryParameters: values);
  }

  static String absoluteUrl(String path, [Map<String, dynamic>? query]) {
    final uri = endpoint(path, query);
    if (uri.hasScheme) return uri.toString();
    return Uri.base.resolve(uri.toString()).toString();
  }
}
