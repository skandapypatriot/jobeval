/// Build-time default (overridable via --dart-define=API_BASE_URL).
const String _kDefaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api/v1',
);

/// Runtime API configuration.
///
/// The base URL can be changed at runtime from the frontend (e.g. the Settings
/// screen) so deployments do not require a rebuild just to point at a different
/// backend. The value defaults to the build-time constant but is mutable.
class ApiConfig {
  const ApiConfig._();

  static String _runtimeBaseUrl = _kDefaultBaseUrl;

  /// The active base URL — runtime override if set, otherwise the build-time default.
  static String get baseUrl {
    final value = _runtimeBaseUrl.trim();
    if (value.isEmpty) return _kDefaultBaseUrl;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  /// Override the base URL at runtime. Call this from the frontend when the
  /// user changes the API endpoint in settings.
  static void setBaseUrl(String url) {
    final value = url.trim();
    if (value.isEmpty) {
      _runtimeBaseUrl = _kDefaultBaseUrl;
    } else {
      _runtimeBaseUrl = value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    }
  }

  /// Reset to the build-time default.
  static void resetToDefault() {
    _runtimeBaseUrl = _kDefaultBaseUrl;
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
