import 'package:flutter/foundation.dart';

/// Centralized application configuration loader.
///
/// Reads configuration from `--dart-define` values (compile-time environment)
/// and applies sensible defaults for supported platforms.
class AppConfig {
  AppConfig._({
    required this.environment,
    required this.crepeBaseUrl,
    required this.spiceBaseUrl,
  });

  /// Canonical environment name (development, test, production).
  final String environment;

  /// Base URL for the CREPE engine API.
  final String? crepeBaseUrl;

  /// Base URL for the SPICE engine API.
  final String? spiceBaseUrl;

  /// Loads configuration from environment variables and platform defaults.
  factory AppConfig.load() {
    final environment = _normalizeEnvironment(
      _readEnv('APP_ENV') ?? 'development',
    );

    final suffix = _envSuffix(environment);

    // Prefer environment specific overrides, then global fallbacks.
    final crepeUrl = _readEnv('CREPE_URL_$suffix') ?? _readEnv('CREPE_BASE_URL');
    final spiceUrl = _readEnv('SPICE_URL_$suffix') ?? _readEnv('SPICE_BASE_URL');

    return AppConfig._(
      environment: environment,
      crepeBaseUrl: _normalizeUrl(crepeUrl),
      spiceBaseUrl: _normalizeUrl(spiceUrl),
    );
  }

  /// Returns the suffix (DEV / TEST / PROD) for the current environment.
  String get environmentSuffix => _envSuffix(environment);

  /// Returns a list of missing configuration keys required for dual engine.
  List<String> get missingDualEngineKeys {
    final keys = <String>[];
    if (crepeBaseUrl == null || crepeBaseUrl!.isEmpty) {
      keys.add('CREPE_URL_${environmentSuffix} or CREPE_BASE_URL');
    }
    if (spiceBaseUrl == null || spiceBaseUrl!.isEmpty) {
      keys.add('SPICE_URL_${environmentSuffix} or SPICE_BASE_URL');
    }
    return keys;
  }

  /// Reads the compile-time environment variable (set via --dart-define).
  static String? _readEnv(String key) {
    switch (key) {
      case 'APP_ENV':
        const value = String.fromEnvironment('APP_ENV', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'CREPE_BASE_URL':
        const value = String.fromEnvironment('CREPE_BASE_URL', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'SPICE_BASE_URL':
        const value = String.fromEnvironment('SPICE_BASE_URL', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'CREPE_URL_DEV':
        const value = String.fromEnvironment('CREPE_URL_DEV', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'SPICE_URL_DEV':
        const value = String.fromEnvironment('SPICE_URL_DEV', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'CREPE_URL_TEST':
        const value = String.fromEnvironment('CREPE_URL_TEST', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'SPICE_URL_TEST':
        const value = String.fromEnvironment('SPICE_URL_TEST', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'CREPE_URL_PROD':
        const value = String.fromEnvironment('CREPE_URL_PROD', defaultValue: '');
        return value.isEmpty ? null : value;
      case 'SPICE_URL_PROD':
        const value = String.fromEnvironment('SPICE_URL_PROD', defaultValue: '');
        return value.isEmpty ? null : value;
      default:
        if (kDebugMode) {
          debugPrint('⚠️ [AppConfig] Attempted to read unsupported key: $key');
        }
        return null;
    }
  }

  static String _normalizeEnvironment(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'prod':
      case 'production':
        return 'production';
      case 'test':
      case 'testing':
        return 'test';
      default:
        return 'development';
    }
  }

  static String _envSuffix(String environment) {
    switch (environment) {
      case 'production':
        return 'PROD';
      case 'test':
        return 'TEST';
      default:
        return 'DEV';
    }
  }

  static String? _normalizeUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}
