import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

enum SyncState { connecting, syncing, synced, error }

const String kOperationalCityName = 'Bhopal';
const double kBhopalLatitude = 23.2599;
const double kBhopalLongitude = 77.4126;

/// Canonical map from display city name → [latitude, longitude].
/// The frontend is pinned to the backend's Bhopal-only runtime.
const Map<String, List<double>> kCityCoordinates = {
  kOperationalCityName: [kBhopalLatitude, kBhopalLongitude],
};

class GeoArea {
  GeoArea({required this.city, required this.center, required this.radiusKm});

  String city;
  LatLng center;
  double radiusKm;

  Map<String, dynamic> toQuery() {
    return {
      'city': city,
      'lat': center.latitude.toStringAsFixed(6),
      'lng': center.longitude.toStringAsFixed(6),
      'radiusKm': radiusKm.toStringAsFixed(1),
    };
  }

  Map<String, dynamic> toBoundingBoxQuery() {
    final latDelta = radiusKm / 111.32;
    final lngScale = math.cos(center.latitude * math.pi / 180).abs();
    final normalizedLngScale = lngScale < 0.01 ? 0.01 : lngScale;
    final lngDelta = radiusKm / (111.32 * normalizedLngScale);

    return {
      'minLat': (center.latitude - latDelta).toStringAsFixed(6),
      'maxLat': (center.latitude + latDelta).toStringAsFixed(6),
      'minLng': (center.longitude - lngDelta).toStringAsFixed(6),
      'maxLng': (center.longitude + lngDelta).toStringAsFixed(6),
    };
  }
}

class DisruptionEvent {
  DisruptionEvent({
    required this.id,
    required this.source,
    required this.category,
    required this.title,
    required this.lat,
    required this.lng,
    required this.severity,
    required this.updatedAt,
  });

  final String id;
  final String source;
  final String category;
  final String title;
  final double lat;
  final double lng;
  final double severity;
  final DateTime updatedAt;

  factory DisruptionEvent.fromJson(Map<String, dynamic> json) {
    final rawType =
        (json['event_type'] ?? json['category'] ?? json['type'] ?? 'event')
            .toString();
    final rawSeverity = (json['severity'] as num?)?.toDouble() ?? 0.0;
    final normalizedSeverity = rawSeverity > 1.0
        ? (rawSeverity / 5.0).clamp(0.0, 1.0)
        : rawSeverity.clamp(0.0, 1.0);

    return DisruptionEvent(
      id: (json['id'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      category: rawType.toLowerCase(),
      title: (json['title'] ?? rawType).toString(),
      lat: ((json['latitude'] ?? json['lat']) as num?)?.toDouble() ?? 0.0,
      lng: ((json['longitude'] ?? json['lng']) as num?)?.toDouble() ?? 0.0,
      severity: normalizedSeverity,
      updatedAt:
          DateTime.tryParse(
            (json['observed_at'] ?? json['updated_at'] ?? '').toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  LatLng get point => LatLng(lat, lng);
}

class AreaNewsItem {
  AreaNewsItem({
    required this.id,
    required this.source,
    required this.category,
    required this.title,
    required this.summary,
    required this.url,
    required this.publishedAt,
    this.lat,
    this.lng,
  });

  final String id;
  final String source;
  final String category;
  final String title;
  final String summary;
  final String url;
  final DateTime publishedAt;
  final double? lat;
  final double? lng;

  factory AreaNewsItem.fromJson(Map<String, dynamic> json) {
    return AreaNewsItem(
      id: (json['id'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      publishedAt:
          DateTime.tryParse((json['published_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class SourceStatus {
  SourceStatus({
    required this.name,
    required this.category,
    required this.endpoint,
    required this.eventCount,
    required this.newsCount,
    required this.lastError,
    this.detail = '',
    this.statusLabel,
  });

  final String name;
  final String category;
  final String endpoint;
  final int eventCount;
  final int newsCount;
  final String? lastError;
  final String detail;
  final String? statusLabel;

  factory SourceStatus.fromJson(Map<String, dynamic> json) {
    return SourceStatus(
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      endpoint: (json['endpoint'] ?? '').toString(),
      eventCount: (json['event_count'] as num?)?.toInt() ?? 0,
      newsCount: (json['news_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error']?.toString(),
      detail: (json['detail'] ?? '').toString(),
      statusLabel: json['status_label']?.toString(),
    );
  }
}

class TrafficReason {
  TrafficReason({
    required this.reason,
    required this.category,
    required this.eventCount,
    required this.avgSeverity,
    required this.impactScore,
    required this.sampleTitles,
  });

  final String reason;
  final String category;
  final int eventCount;
  final double avgSeverity;
  final double impactScore;
  final List<String> sampleTitles;

  factory TrafficReason.fromJson(Map<String, dynamic> json) {
    final rawTitles = (json['sampleTitles'] as List<dynamic>? ?? const []);
    return TrafficReason(
      reason: (json['reason'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
      avgSeverity: (json['avgSeverity'] as num?)?.toDouble() ?? 0.0,
      impactScore: (json['impactScore'] as num?)?.toDouble() ?? 0.0,
      sampleTitles: rawTitles.map((e) => e.toString()).toList(growable: false),
    );
  }
}

class RiskResult {
  RiskResult({
    required this.riskScore,
    required this.classification,
    required this.riskDensity,
    required this.contributingEvents,
    required this.evalLatencyMs,
  });

  final double riskScore;
  final String classification;
  final double riskDensity;
  final int contributingEvents;
  final int evalLatencyMs;

  factory RiskResult.fromJson(Map<String, dynamic> json) {
    return RiskResult(
      riskScore: (json['riskScore'] as num?)?.toDouble() ?? 0.0,
      classification: (json['classification'] ?? '').toString(),
      riskDensity: (json['riskDensity'] as num?)?.toDouble() ?? 0.0,
      contributingEvents: (json['contributingEvents'] as num?)?.toInt() ?? 0,
      evalLatencyMs: (json['evalLatencyMs'] as num?)?.toInt() ?? 0,
    );
  }
}
