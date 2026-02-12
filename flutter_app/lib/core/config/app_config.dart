/// Centralized application configuration.
///
/// All environment-specific values live here. Switch between
/// [development] and [production] by changing the active instance
/// in `main.dart`.
class AppConfig {
  final String apiBaseUrl;
  final String discoveryUrl;
  final bool enableLogging;

  const AppConfig({
    required this.apiBaseUrl,
    required this.discoveryUrl,
    this.enableLogging = false,
  });

  /// Development configuration (local backend).
  static const development = AppConfig(
    apiBaseUrl: 'http://127.0.0.1:8000/api/v1/',
    discoveryUrl: 'http://127.0.0.1:8000/api/discover/',
    enableLogging: true,
  );

  /// Production configuration.
  static const production = AppConfig(
    apiBaseUrl: 'https://api.kitchen.funadventure.ae/api/v1/',
    discoveryUrl: 'https://api.kitchen.funadventure.ae/api/discover/',
    enableLogging: false,
  );

  /// The active configuration. Change this to switch environments.
  static AppConfig current = development;
}
