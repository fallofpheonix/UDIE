import 'package:latlong2/latlong.dart';

enum SyncState { connecting, syncing, synced, error }

/// Canonical map from display city name → [latitude, longitude] for all
/// supported Indian cities.  This is the single source of truth used by
/// both [AppStore] (validation) and the settings screen (coordinate auto-fill).
///
/// Aliases ('New Delhi', 'Bangalore') are included for backward-compatible
/// city name matching.
const Map<String, List<double>> kCityCoordinates = {
  'Delhi': [28.6139, 77.2090],
  'New Delhi': [28.6139, 77.2090],
  'Mumbai': [19.0760, 72.8777],
  'Bengaluru': [12.9716, 77.5946],
  'Bangalore': [12.9716, 77.5946],
  'Chennai': [13.0827, 80.2707],
  'Hyderabad': [17.3850, 78.4867],
  'Kolkata': [22.5726, 88.3639],
  'Pune': [18.5204, 73.8567],
  'Ahmedabad': [23.0225, 72.5714],
  'Jaipur': [26.9124, 75.7873],
  'Lucknow': [26.8467, 80.9462],
  'Bhopal': [23.2599, 77.4126],
  'Patna': [25.5941, 85.1376],
  'Guwahati': [26.1445, 91.7362],
  'Chandigarh': [30.7333, 76.7794],
  'Srinagar': [34.0837, 74.7973],
  'Kochi': [9.9312, 76.2673],
  'Thiruvananthapuram': [8.5241, 76.9366],
  'Nagpur': [21.1458, 79.0882],
  'Indore': [22.7196, 75.8577],
  'Surat': [21.1702, 72.8311],
  'Kanpur': [26.4499, 80.3319],
  'Varanasi': [25.3176, 82.9739],
  'Visakhapatnam': [17.6868, 83.2185],
  'Coimbatore': [11.0168, 76.9558],
  'Madurai': [9.9252, 78.1198],
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
    return DisruptionEvent(
      id: (json['id'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      severity: (json['severity'] as num?)?.toDouble() ?? 0.0,
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
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
  });

  final String name;
  final String category;
  final String endpoint;
  final int eventCount;
  final int newsCount;
  final String? lastError;

  factory SourceStatus.fromJson(Map<String, dynamic> json) {
    return SourceStatus(
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      endpoint: (json['endpoint'] ?? '').toString(),
      eventCount: (json['event_count'] as num?)?.toInt() ?? 0,
      newsCount: (json['news_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error']?.toString(),
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
