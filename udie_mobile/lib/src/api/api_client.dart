import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class ApiClient {
  ApiClient({required this.baseUrl}) : _client = http.Client();

  final http.Client _client;
  String baseUrl;
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
        final resp = await _client.get(uri).timeout(const Duration(seconds: 4));
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

  Future<List<AreaNewsItem>> fetchNews(
    GeoArea area, {
    Set<String> categories = const {},
  }) async {
    final query = area.toQuery();
    if (categories.isNotEmpty) {
      query['categories'] = categories.join(',');
    }
    final data = await _getList('$namespace/news', query);
    return data.map((e) => AreaNewsItem.fromJson(e)).toList();
  }

  Future<List<SourceStatus>> fetchSources(GeoArea area) async {
    final obj = await _getObject('$namespace/sources', area.toQuery());
    final raw = (obj['sources'] as List<dynamic>? ?? []);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SourceStatus.fromJson)
        .toList();
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
        .timeout(const Duration(seconds: 6));

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
    final resp = await _client.get(uri).timeout(const Duration(seconds: 6));
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
    final resp = await _client.get(uri).timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) {
      throw HttpException('GET $path failed: ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(resp.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Expected object response');
    }
    return body;
  }

  Uri _buildUri(String path, Map<String, dynamic> query) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$normalizedBase$path');
    final queryParams = query.map((k, v) => MapEntry(k, v.toString()));
    return uri.replace(queryParameters: queryParams);
  }
}

class LatLngCoordinate {
  const LatLngCoordinate(this.lat, this.lng);

  final double lat;
  final double lng;
}
