Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map<String, Object?>) throw const FormatException('Expected an object.');
  return value;
}

String jsonString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Expected a string: $key.');
  return value;
}

String? jsonOptionalString(Map<String, Object?> json, String key) => json[key] == null ? null : jsonString(json, key);

int jsonInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Expected an integer: $key.');
  return value;
}

DateTime jsonInstant(Map<String, Object?> json, String key) {
  final value = jsonString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) throw FormatException('Expected an instant with a time zone: $key.');
  return parsed;
}

void jsonFields(Map<String, Object?> json, Set<String> allowed) {
  if (json.keys.any((key) => !allowed.contains(key))) throw const FormatException('Unexpected field.');
}

String instantJson(DateTime value) => value.toUtc().toIso8601String();
