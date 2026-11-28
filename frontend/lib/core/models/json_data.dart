typedef JsonMap = Map<String, dynamic>;

class JsonData {
  const JsonData._();

  static JsonMap map(dynamic value) {
    if (value is JsonMap) return value;
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }

  static List<JsonMap> maps(dynamic value) {
    if (value is List) {
      return value.whereType<Map>().map(map).toList(growable: false);
    }
    if (value is Map) {
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
        final nested = value[key];
        if (nested is List) return maps(nested);
      }
    }
    return const [];
  }

  static List<dynamic> list(dynamic value) {
    if (value is List) return value;
    if (value is Map) {
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
        final nested = value[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  static JsonMap? nested(dynamic value, String key) {
    if (value is Map && value[key] is Map) return map(value[key]);
    return null;
  }

  static String text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value.trim().isEmpty ? fallback : value.trim();
    return value.toString();
  }

  static double number(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int integer(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'no' || normalized == '0') {
        return false;
      }
    }
    return fallback;
  }

  static DateTime? date(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String id(JsonMap value, {String fallback = ''}) {
    return text(value['id'] ?? value['project_id'] ?? value['feature_id'],
        fallback: fallback);
  }

  static String displayName(JsonMap value, {String fallback = 'Untitled'}) {
    return text(
      value['name'] ?? value['label'] ?? value['title'] ?? value['filename'],
      fallback: fallback,
    );
  }

  static String status(JsonMap value, {String fallback = 'unknown'}) {
    return text(value['status'] ?? value['state'], fallback: fallback);
  }

  static JsonMap firstMap(JsonMap value, List<String> keys) {
    for (final key in keys) {
      final nestedValue = value[key];
      if (nestedValue is Map) return map(nestedValue);
    }
    return <String, dynamic>{};
  }

  static List<JsonMap> firstMaps(JsonMap value, List<String> keys) {
    for (final key in keys) {
      final nestedValue = value[key];
      if (nestedValue is List) return maps(nestedValue);
    }
    return const [];
  }

  static List<String> strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map) {
            final map = mapOf(item);
            return text(
              map['id'] ??
                  map['face_id'] ??
                  map['vertex_id'] ??
                  map['name'] ??
                  map['text'],
            );
          }
          return item.toString();
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static JsonMap mapOf(Map<dynamic, dynamic> value) {
    return value.map<String, dynamic>(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
}

String humanizeKey(String value) {
  return value
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'([a-z0-9])([A-Z])'), r'$1 $2')
      .trim();
}

String formatNumber(double value, {int decimals = 2}) {
  if (!value.isFinite) return '—';
  final fixed = value.toStringAsFixed(decimals);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String formatDateTime(dynamic value) {
  final date = JsonData.date(value);
  if (date == null) return 'Not available';
  final local = date.toLocal();
  final two = (int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
