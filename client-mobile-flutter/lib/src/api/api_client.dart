import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/app_models.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    Duration? requestTimeout,
  }) : _client = http.Client(),
       requestTimeout = requestTimeout ?? const Duration(seconds: 6);

  final http.Client _client;
  String baseUrl;
  Duration requestTimeout;
  String namespace = '/api';

  Future<void> close() async {
    _client.close();
  }

  Future<void> detectNamespace() async {
    const probes = <String>[
      '/health/ready',
      '/health/live',
      '/api/v1/health/ready',
      '/api/v1/health/live',
      '/api/health',
      '/api/v1/health',
    ];

    for (final path in probes) {
      final uri = _buildUri(path, const {});
      try {
        final resp = await _sendGet(
          uri,
          timeout: const Duration(seconds: 4),
        );
        if (resp.statusCode == 200) {
          if (path.startsWith('/api/v1/')) {
            namespace = '/api/v1';
          } else if (path.startsWith('/api/')) {
            namespace = '/api';
          } else {
            namespace = '';
          }
          return;
        }
      } on Exception {
        // Try next candidate.
      }
    }
    throw const SocketException(
      'Failed health probe for /health/live,/health/ready,/api,/api/v1',
    );
  }

  Future<List<DisruptionEvent>> fetchEvents(GeoArea area) async {
    final data = await _getList('$namespace/events', area.toBoundingBoxQuery());
    return data.map((e) => DisruptionEvent.fromJson(e)).toList();
  }

  Future<OperationalSnapshot> fetchOperationalSnapshot(
    GeoArea area, {
    Set<String> categories = const {},
  }) async {
    final eventsFuture = fetchEvents(area);
    final dashboardFuture = _fetchCityDashboard(area);
    final healthFuture = _fetchHealthReady();
    final intelligenceFuture = _fetchIntelligence(limit: 24);

    final events = await eventsFuture;
    final dashboard = await dashboardFuture;
    final health = await healthFuture;
    final intelligence = await intelligenceFuture;

    return OperationalSnapshot(
      events: events,
      news: _buildNewsFeed(
        dashboard: dashboard,
        intelligence: intelligence,
        categories: categories,
      ),
      sources: _buildSourceDiagnostics(
        dashboard: dashboard,
        health: health,
      ),
    );
  }

  Future<List<AreaNewsItem>> fetchNewsSignals(
    GeoArea area, {
    Set<String> categories = const {},
  }) async {
    final dashboardFuture = _fetchCityDashboard(area);
    final intelligenceFuture = _fetchIntelligence(limit: 24);

    return _buildNewsFeed(
      dashboard: await dashboardFuture,
      intelligence: await intelligenceFuture,
      categories: categories,
    );
  }

  Future<List<SourceStatus>> fetchSourceDiagnostics(GeoArea area) async {
    final dashboardFuture = _fetchCityDashboard(area);
    final healthFuture = _fetchHealthReady();

    return _buildSourceDiagnostics(
      dashboard: await dashboardFuture,
      health: await healthFuture,
    );
  }

  Future<RiskResult> calculateRisk(List<LatLngCoordinate> coordinates) async {
    final uri = _buildUri('$namespace/risk', const {});
    final payload = {
      'coordinates': coordinates
          .map((p) => {'lat': p.lat, 'lng': p.lng})
          .toList(growable: false),
    };
    final resp = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(requestTimeout);
    _trace('POST', uri, statusCode: resp.statusCode);

    if (resp.statusCode != 200) {
      throw HttpException(
        'Risk endpoint failed with ${resp.statusCode}: ${resp.body}',
      );
    }

    final body = jsonDecode(resp.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Invalid risk response shape');
    }
    return RiskResult.fromJson(body);
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path,
    Map<String, dynamic> query,
  ) async {
    final uri = _buildUri(path, query);
    final resp = await _sendGet(uri);
    if (resp.statusCode != 200) {
      throw HttpException('GET $path failed: ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(resp.body);
    if (body is! List) {
      throw const FormatException('Expected list response');
    }
    return body.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> _getObject(
    String path,
    Map<String, dynamic> query,
  ) async {
    final uri = _buildUri(path, query);
    final resp = await _sendGet(uri);
    if (resp.statusCode != 200) {
      throw HttpException('GET $path failed: ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(resp.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> _fetchIntelligence({
    int limit = 24,
  }) async {
    return _getList('$namespace/intelligence', {'limit': limit});
  }

  Future<Map<String, dynamic>> _fetchCityDashboard(GeoArea area) async {
    return _getObject('$namespace/city-dashboard', area.toBoundingBoxQuery());
  }

  Future<Map<String, dynamic>> _fetchHealthReady() async {
    final uri = _buildUri('$namespace/health/ready', const {});
    final resp = await _sendGet(uri);
    if (resp.statusCode != 200 && resp.statusCode != 503) {
      throw HttpException(
        'GET $namespace/health/ready failed: ${resp.statusCode} ${resp.body}',
      );
    }
    final body = jsonDecode(resp.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }
    return body;
  }

  List<AreaNewsItem> _buildNewsFeed({
    required Map<String, dynamic> dashboard,
    required List<Map<String, dynamic>> intelligence,
    required Set<String> categories,
  }) {
    final items = <AreaNewsItem>[];
    final seen = <String>{};
    final normalizedFilter = categories
        .map((category) => category.trim().toLowerCase())
        .where((category) => category.isNotEmpty)
        .toSet();

    final recentIncidents =
        (dashboard['recentIncidents'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();
    for (final incident in recentIncidents) {
      final rawType = (incident['eventType'] ?? 'INCIDENT').toString();
      final category = rawType.toLowerCase();
      if (normalizedFilter.isNotEmpty && !normalizedFilter.contains(category)) {
        continue;
      }
      final publishedAt =
          DateTime.tryParse((incident['observedAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final id =
          'incident:${publishedAt.toUtc().toIso8601String()}:${incident['lat']}:${incident['lng']}:$rawType';
      if (!seen.add(id)) {
        continue;
      }
      final severity = (incident['severity'] as num?)?.toInt() ?? 0;
      final confidence = (incident['confidence'] as num?)?.toDouble() ?? 0.0;
      items.add(
        AreaNewsItem(
          id: id,
          source: 'city-dashboard',
          category: category,
          title: _humanizeToken(rawType),
          summary:
              'Severity $severity · confidence ${(confidence * 100).clamp(0, 100).toStringAsFixed(0)}% · active in viewport',
          url: '',
          publishedAt: publishedAt,
          lat: (incident['lat'] as num?)?.toDouble(),
          lng: (incident['lng'] as num?)?.toDouble(),
        ),
      );
    }

    for (final insight in intelligence) {
      final rawType = (insight['type'] ?? 'INTELLIGENCE').toString();
      const category = 'intelligence';
      if (normalizedFilter.isNotEmpty && !normalizedFilter.contains(category)) {
        continue;
      }
      final publishedAt =
          DateTime.tryParse((insight['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final cell = (insight['cell'] ?? '').toString();
      final id = 'intel:${publishedAt.toUtc().toIso8601String()}:$cell:$rawType';
      if (!seen.add(id)) {
        continue;
      }
      final severity = (insight['severity'] ?? 'UNKNOWN').toString();
      final description = (insight['description'] ?? '').toString().trim();
      items.add(
        AreaNewsItem(
          id: id,
          source: 'intelligence',
          category: category,
          title: _humanizeToken(rawType),
          summary: description.isNotEmpty
              ? description
              : '$severity intelligence event on H3 cell $cell',
          url: '',
          publishedAt: publishedAt,
        ),
      );
    }

    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items;
  }

  List<SourceStatus> _buildSourceDiagnostics({
    required Map<String, dynamic> dashboard,
    required Map<String, dynamic> health,
  }) {
    final sources = <SourceStatus>[];
    final checks = (health['checks'] as Map<String, dynamic>? ?? const {});
    final riskSurface =
        (checks['riskSurface'] as Map<String, dynamic>? ?? const {});
    final platform =
        (checks['platformReliability'] as Map<String, dynamic>? ?? const {});
    final workers = (checks['workers'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    final heatmap =
        (dashboard['heatmapSummary'] as Map<String, dynamic>? ?? const {});
    final recentIncidents = (dashboard['recentIncidents'] as List<dynamic>? ?? const []).length;
    final hotspots = (dashboard['topHotspots'] as List<dynamic>? ?? const []).length;
    final heatmapCells = (heatmap['cells'] as num?)?.toInt() ?? 0;
    final avgRisk = (heatmap['avgRisk'] as num?)?.toDouble() ?? 0.0;
    final maxRisk = (heatmap['maxRisk'] as num?)?.toDouble() ?? 0.0;
    final freshnessSeconds =
        (riskSurface['freshnessSeconds'] as num?)?.toDouble() ?? 0.0;

    final healthEndpoint = '$baseUrl$namespace/health/ready';
    final dashboardEndpoint = '$baseUrl$namespace/city-dashboard';

    sources.add(
      SourceStatus(
        name: 'Database Plane',
        category: 'system',
        endpoint: healthEndpoint,
        eventCount: 0,
        newsCount: 0,
        detail:
            'status ${(checks['database'] ?? 'unknown').toString()} · replica ${(checks['replicaLagSeconds'] ?? 0)} s · locks ${(checks['lockWaiters'] ?? 0)}',
        statusLabel: (health['status'] ?? 'unknown').toString().toUpperCase(),
        lastError: (checks['database'] ?? 'down') == 'up'
            ? null
            : 'Database health check failed',
      ),
    );

    final surfaceStale = riskSurface['stale'] == true;
    sources.add(
      SourceStatus(
        name: 'Risk Surface',
        category: 'infrastructure',
        endpoint: dashboardEndpoint,
        eventCount: heatmapCells,
        newsCount: hotspots,
        detail:
            '$heatmapCells cells · avg ${avgRisk.toStringAsFixed(2)} · max ${maxRisk.toStringAsFixed(2)} · freshness ${freshnessSeconds.toStringAsFixed(1)} s',
        statusLabel: surfaceStale ? 'STALE' : 'LIVE',
        lastError: surfaceStale ? 'Risk surface freshness threshold breached' : null,
      ),
    );

    for (final worker in workers) {
      final status = (worker['status'] ?? 'unknown').toString();
      final lagSeconds = (worker['lagSeconds'] as num?)?.toDouble() ?? 0.0;
      sources.add(
        SourceStatus(
          name: _humanizeToken((worker['name'] ?? 'worker').toString()),
          category: 'system',
          endpoint: healthEndpoint,
          eventCount: 0,
          newsCount: 0,
          detail: 'lag ${lagSeconds.toStringAsFixed(2)} s · heartbeat ${worker['heartbeat'] == true ? 'yes' : 'no'}',
          statusLabel: status.toUpperCase(),
          lastError: status == 'healthy' ? null : 'Worker lag above threshold',
        ),
      );
    }

    final reliabilityScore = (platform['score'] as num?)?.toDouble() ?? 0.0;
    final failureProbability =
        (platform['failureProbability'] as num?)?.toDouble() ?? 0.0;
    sources.add(
      SourceStatus(
        name: 'Platform Reliability',
        category: 'system',
        endpoint: healthEndpoint,
        eventCount: recentIncidents,
        newsCount: intelligenceCountHint(dashboard),
        detail:
            'score ${reliabilityScore.toStringAsFixed(2)} · failure ${failureProbability.toStringAsFixed(3)} · incidents $recentIncidents',
        statusLabel: (platform['status'] ?? 'unknown')
            .toString()
            .toUpperCase(),
        lastError: reliabilityScore >= 0.9 ? null : 'Reliability score below stable threshold',
      ),
    );

    return sources;
  }

  int intelligenceCountHint(Map<String, dynamic> dashboard) {
    return (dashboard['topHotspots'] as List<dynamic>? ?? const []).length;
  }

  String _humanizeToken(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (normalized.isEmpty) {
      return raw;
    }
    return normalized
        .split(RegExp(r'\s+'))
        .map((token) {
          final lower = token.toLowerCase();
          return lower.substring(0, 1).toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  Uri _buildUri(String path, Map<String, dynamic> query) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$normalizedBase$path');
    final queryParams = query.map((k, v) => MapEntry(k, v.toString()));
    return uri.replace(queryParameters: queryParams);
  }

  Future<http.Response> _sendGet(Uri uri, {Duration? timeout}) async {
    _trace('GET', uri);
    final resp = await _client.get(uri).timeout(timeout ?? requestTimeout);
    _trace('GET', uri, statusCode: resp.statusCode);
    return resp;
  }

  void _trace(String method, Uri uri, {int? statusCode}) {
    if (!AppConfig.enableHttpTrace) {
      return;
    }
    final prefix = statusCode == null
        ? 'HTTP $method'
        : 'HTTP $method $statusCode';
    debugPrint('$prefix $uri');
  }
}

class LatLngCoordinate {
  const LatLngCoordinate(this.lat, this.lng);

  final double lat;
  final double lng;
}

class OperationalSnapshot {
  const OperationalSnapshot({
    required this.events,
    required this.news,
    required this.sources,
  });

  final List<DisruptionEvent> events;
  final List<AreaNewsItem> news;
  final List<SourceStatus> sources;
}
