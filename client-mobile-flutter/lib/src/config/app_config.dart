import 'dart:io';

import 'package:flutter/foundation.dart';

enum Environment { dev, staging, prod }

final class AppConfig {
  static const String _envRaw = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  static Environment get environment {
    switch (_envRaw) {
      case 'staging':
        return Environment.staging;
      case 'prod':
        return Environment.prod;
      default:
        return Environment.dev;
    }
  }

  static Uri? get remoteConfigUri {
    const configured = String.fromEnvironment(
      'UDIE_CONFIG_URL',
      defaultValue: '',
    );
    if (configured.isEmpty) {
      return null;
    }
    return Uri.parse(configured);
  }

  static String get fallbackBaseUrl {
    const explicit = String.fromEnvironment(
      'UDIE_BASE_URL',
      defaultValue: '',
    );
    if (explicit.isNotEmpty) {
      return explicit;
    }

    switch (environment) {
      case Environment.dev:
        return _devBaseUrl();
      case Environment.staging:
      case Environment.prod:
        throw UnsupportedError(
          'UDIE_BASE_URL or UDIE_CONFIG_URL is required for ${environment.name}.',
        );
    }
  }

  static String _devBaseUrl() {
    const useAndroidEmulator = bool.fromEnvironment(
      'UDIE_USE_ANDROID_EMULATOR',
      defaultValue: false,
    );

    if (kIsWeb) {
      return 'http://127.0.0.1:3000';
    }
    if (Platform.isAndroid && useAndroidEmulator) {
      return 'http://10.0.2.2:3000';
    }

    throw UnsupportedError(
      'UDIE_BASE_URL is required for physical devices in dev.',
    );
  }

  static const Duration configFetchTimeout = Duration(seconds: 3);
  static const Duration configCacheTtl = Duration(hours: 1);
  static const int defaultApiTimeoutMs = 6000;
  static const bool enableHttpTrace = bool.fromEnvironment(
    'UDIE_HTTP_TRACE',
    defaultValue: false,
  );
  static const String apiPrefix = '/api/v1';
}
