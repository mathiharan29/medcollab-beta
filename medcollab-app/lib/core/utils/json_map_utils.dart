/// Helpers for parsing loosely-typed JSON maps (REST + Socket.io).
Map<String, dynamic>? asJsonMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Recursively normalizes nested maps from Socket.io payloads.
Map<String, dynamic> deepJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((key, nested) => MapEntry(key, _deepJsonValue(nested)));
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value)
        .map((key, nested) => MapEntry(key.toString(), _deepJsonValue(nested)));
  }
  return {};
}

dynamic _deepJsonValue(dynamic value) {
  if (value is Map) return deepJsonMap(value);
  if (value is List) return value.map(_deepJsonValue).toList();
  return value;
}
