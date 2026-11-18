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
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$')
      .firstMatch(value);
  if (match == null) throw FormatException('Expected an ISO instant: $key.');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final calendar = DateTime.utc(year, month, day, hour, minute, second);
  if (calendar.year != year ||
      calendar.month != month ||
      calendar.day != day ||
      calendar.hour != hour ||
      calendar.minute != minute ||
      calendar.second != second) {
    throw FormatException('Invalid calendar date or time: $key.');
  }
  final offset = match.group(7)!;
  if (offset != 'Z' && (int.parse(offset.substring(1, 3)) > 23 || int.parse(offset.substring(4, 6)) > 59)) {
    throw FormatException('Invalid time zone offset: $key.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) throw FormatException('Expected an instant with a time zone: $key.');
  return parsed;
}

void jsonFields(Map<String, Object?> json, Set<String> allowed) {
  if (json.keys.any((key) => !allowed.contains(key))) throw const FormatException('Unexpected field.');
}

String instantJson(DateTime value) => value.toUtc().toIso8601String();
