import 'app_config.dart';

final class RuntimeConfig {
  RuntimeConfig({
    required this.environment,
    required this.baseUrl,
    required Map<String, dynamic> features,
    required this.apiTimeoutMs,
    required this.source,
    this.fetchedAt,
  }) : features = Map.unmodifiable(features);

  final Environment environment;
  final String baseUrl;
  final Map<String, dynamic> features;
  final int apiTimeoutMs;
  final String source;
  final DateTime? fetchedAt;

  Duration get apiTimeout => Duration(milliseconds: apiTimeoutMs);

  bool isFeatureEnabled(String key) => features[key] == true;

  RuntimeConfig copyWith({
    Environment? environment,
    String? baseUrl,
    Map<String, dynamic>? features,
    int? apiTimeoutMs,
    String? source,
    DateTime? fetchedAt,
  }) {
    return RuntimeConfig(
      environment: environment ?? this.environment,
      baseUrl: baseUrl ?? this.baseUrl,
      features: features ?? this.features,
      apiTimeoutMs: apiTimeoutMs ?? this.apiTimeoutMs,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  factory RuntimeConfig.fromJson(
    Map<String, dynamic> json, {
    required Environment environment,
    required String source,
    DateTime? fetchedAt,
  }) {
    final baseUrl = (json['baseUrl'] as String? ?? '').trim();
    if (baseUrl.isEmpty) {
      throw const FormatException('Runtime config missing baseUrl');
    }

    final features = (json['features'] as Map<String, dynamic>?) ?? const {};
    final nestedTimeout = json['timeouts'] is Map<String, dynamic>
        ? (json['timeouts'] as Map<String, dynamic>)['api']
        : null;
    final apiTimeoutRaw = json['apiTimeoutMs'] ?? nestedTimeout;
    final apiTimeoutMs = switch (apiTimeoutRaw) {
      int value => value,
      String value => int.tryParse(value) ?? AppConfig.defaultApiTimeoutMs,
      _ => AppConfig.defaultApiTimeoutMs,
    };

    return RuntimeConfig(
      environment: environment,
      baseUrl: baseUrl,
      features: features,
      apiTimeoutMs: apiTimeoutMs,
      source: source,
      fetchedAt: fetchedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'features': features,
      'apiTimeoutMs': apiTimeoutMs,
      'source': source,
      'fetchedAt': fetchedAt?.toIso8601String(),
      'environment': environment.name,
    };
  }
}
