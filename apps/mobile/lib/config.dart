import 'package:flutter/foundation.dart';

const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

const useFakeData = bool.fromEnvironment('FAKE_DATA');

Uri apiBaseUrl() {
  if (_configuredBaseUrl.isNotEmpty) return Uri.parse(_configuredBaseUrl);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return Uri.parse('http://10.0.2.2:8080');
  return Uri.parse('http://localhost:8080');
}
