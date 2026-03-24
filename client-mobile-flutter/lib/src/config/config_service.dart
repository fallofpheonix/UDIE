import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'runtime_config.dart';

final class ConfigService {
  static const String _cacheKey = 'udie.runtime_config.cache.v1';
  static const String _cacheTimestampKey = 'udie.runtime_config.cache_ts.v1';
  static const String _baseUrlOverrideKey = 'udie.runtime_config.base_url.v1';

  static final http.Client _client = http.Client();

  static RuntimeConfig? _baseConfig;
  static RuntimeConfig? _effectiveConfig;

  static RuntimeConfig get config {
    final current = _effectiveConfig;
    if (current == null) {
      throw StateError('ConfigService.init() must complete before use.');
    }
    return current;
  }

  static Future<RuntimeConfig> init() async {
    if (_effectiveConfig != null) {
      return _effectiveConfig!;
    }
    return _load(forceRemote: true);
  }

  static Future<RuntimeConfig> refresh() async {
    return _load(forceRemote: true);
  }

  static Future<RuntimeConfig> setBaseUrlOverride(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_baseUrlOverrideKey);
    } else {
      await prefs.setString(_baseUrlOverrideKey, trimmed);
    }
    if (_baseConfig == null) {
      await init();
    }
    return _applyConfig(_baseConfig!, _readOverride(prefs));
  }

  static Future<RuntimeConfig> _load({required bool forceRemote}) async {
    final prefs = await SharedPreferences.getInstance();
    final override = _readOverride(prefs);

    if (forceRemote) {
      final remote = await _fetchRemoteConfig();
      if (remote != null) {
        await _storeCachedConfig(prefs, remote);
        return _applyConfig(remote, override);
      }
    }

    final cached = _loadCachedConfig(prefs);
    if (cached != null) {
      return _applyConfig(cached, override);
    }

    final fallback = RuntimeConfig(
      environment: AppConfig.environment,
      baseUrl: AppConfig.fallbackBaseUrl,
      features: const {},
      apiTimeoutMs: AppConfig.defaultApiTimeoutMs,
      source: 'default',
    );
    return _applyConfig(fallback, override);
  }

  static Future<RuntimeConfig?> _fetchRemoteConfig() async {
    final uri = AppConfig.remoteConfigUri;
    if (uri == null) {
      return null;
    }

    try {
      final response = await _client
          .get(uri)
          .timeout(AppConfig.configFetchTimeout);
      if (response.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return null;
      }
      return RuntimeConfig.fromJson(
        body,
        environment: AppConfig.environment,
        source: 'remote',
        fetchedAt: DateTime.now(),
      );
    } on Exception {
      return null;
    }
  }

  static RuntimeConfig? _loadCachedConfig(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final body = jsonDecode(raw);
      if (body is! Map<String, dynamic>) {
        return null;
      }
      final fetchedAtMillis = prefs.getInt(_cacheTimestampKey);
      final fetchedAt = fetchedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fetchedAtMillis);
      final cached = RuntimeConfig.fromJson(
        body,
        environment: AppConfig.environment,
        source: 'cache',
        fetchedAt: fetchedAt,
      );
      return cached;
    } on Exception {
      return null;
    }
  }

  static Future<void> _storeCachedConfig(
    SharedPreferences prefs,
    RuntimeConfig config,
  ) async {
    await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
    await prefs.setInt(
      _cacheTimestampKey,
      (config.fetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  static String? _readOverride(SharedPreferences prefs) {
    final override = prefs.getString(_baseUrlOverrideKey)?.trim();
    if (override == null || override.isEmpty) {
      return null;
    }
    return override;
  }

  static RuntimeConfig _applyConfig(
    RuntimeConfig baseConfig,
    String? overrideBaseUrl,
  ) {
    _baseConfig = baseConfig;
    _effectiveConfig = overrideBaseUrl == null
        ? baseConfig
        : baseConfig.copyWith(
            baseUrl: overrideBaseUrl,
            source: '${baseConfig.source}+override',
          );
    return _effectiveConfig!;
  }
}
