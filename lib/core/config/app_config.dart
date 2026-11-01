class AppConfig {
  AppConfig._();

  /// Set at build time, for example:
  /// flutter run --dart-define=API_BASE_URL=https://example.org/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static bool get hasApiBaseUrl => apiBaseUrl.trim().isNotEmpty;
}
