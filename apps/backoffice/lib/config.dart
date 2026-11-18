const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

const useFakeData = bool.fromEnvironment('FAKE_DATA');

Uri apiBaseUrl() => Uri.parse(_configuredBaseUrl.isEmpty ? 'http://localhost:8080' : _configuredBaseUrl);
