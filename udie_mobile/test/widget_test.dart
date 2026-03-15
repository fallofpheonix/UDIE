import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:udie_mobile/src/models.dart';

void main() {
  // ──────────────────────────────────────────────────────────
  // DisruptionEvent model tests
  // ──────────────────────────────────────────────────────────
  group('DisruptionEvent.fromJson', () {
    test('parses a complete JSON object', () {
      final json = {
        'id': 'evt-001',
        'source': 'ndma',
        'category': 'flood',
        'title': 'Flood alert',
        'lat': 28.6139,
        'lng': 77.2090,
        'severity': 0.8,
        'updated_at': '2024-01-15T10:30:00.000Z',
      };

      final event = DisruptionEvent.fromJson(json);

      expect(event.id, 'evt-001');
      expect(event.source, 'ndma');
      expect(event.category, 'flood');
      expect(event.title, 'Flood alert');
      expect(event.lat, 28.6139);
      expect(event.lng, 77.2090);
      expect(event.severity, 0.8);
      expect(event.updatedAt.isAfter(DateTime(2024)), isTrue);
    });

    test('handles missing optional fields with safe defaults', () {
      final json = <String, dynamic>{};
      final event = DisruptionEvent.fromJson(json);

      expect(event.id, '');
      expect(event.lat, 0.0);
      expect(event.lng, 0.0);
      expect(event.severity, 0.0);
      expect(event.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('point getter returns correct LatLng', () {
      final json = {
        'id': 'x',
        'source': 's',
        'category': 'c',
        'title': 't',
        'lat': 12.9716,
        'lng': 77.5946,
        'severity': 0.5,
        'updated_at': '',
      };
      final event = DisruptionEvent.fromJson(json);
      expect(event.point.latitude, 12.9716);
      expect(event.point.longitude, 77.5946);
    });
  });

  // ──────────────────────────────────────────────────────────
  // AreaNewsItem model tests
  // ──────────────────────────────────────────────────────────
  group('AreaNewsItem.fromJson', () {
    test('parses a complete news item', () {
      final json = {
        'id': 'news-1',
        'source': 'govt',
        'category': 'weather',
        'title': 'Heavy rain expected',
        'summary': 'IMD issues red alert',
        'url': 'https://example.com',
        'published_at': '2024-03-01T08:00:00.000Z',
        'lat': 19.076,
        'lng': 72.8777,
      };

      final item = AreaNewsItem.fromJson(json);

      expect(item.id, 'news-1');
      expect(item.category, 'weather');
      expect(item.lat, 19.076);
      expect(item.lng, 72.8777);
    });

    test('nullable lat/lng defaults to null when absent', () {
      final json = {
        'id': 'news-2',
        'source': 'src',
        'category': 'cat',
        'title': 'T',
        'summary': 'S',
        'url': 'https://example.com',
        'published_at': '2024-01-01T00:00:00Z',
      };
      final item = AreaNewsItem.fromJson(json);
      expect(item.lat, isNull);
      expect(item.lng, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────
  // SourceStatus model tests
  // ──────────────────────────────────────────────────────────
  group('SourceStatus.fromJson', () {
    test('parses event and news counts', () {
      final json = {
        'name': 'ndma-sachet',
        'category': 'government',
        'endpoint': 'https://sachet.ndma.gov.in',
        'event_count': 42,
        'news_count': 7,
        'last_error': null,
      };
      final status = SourceStatus.fromJson(json);
      expect(status.eventCount, 42);
      expect(status.newsCount, 7);
      expect(status.lastError, isNull);
    });

    test('captures last_error string', () {
      final json = {
        'name': 'src',
        'category': 'cat',
        'endpoint': 'https://example.com',
        'event_count': 0,
        'news_count': 0,
        'last_error': 'Connection timed out',
      };
      final status = SourceStatus.fromJson(json);
      expect(status.lastError, 'Connection timed out');
    });
  });

  // ──────────────────────────────────────────────────────────
  // RiskResult model tests
  // ──────────────────────────────────────────────────────────
  group('RiskResult.fromJson', () {
    test('parses a DANGER risk response', () {
      final json = {
        'riskScore': 0.85,
        'classification': 'DANGER',
        'riskDensity': 4.2,
        'contributingEvents': 5,
        'evalLatencyMs': 3,
      };
      final result = RiskResult.fromJson(json);
      expect(result.riskScore, 0.85);
      expect(result.classification, 'DANGER');
      expect(result.contributingEvents, 5);
      expect(result.evalLatencyMs, 3);
    });

    test('defaults to zero values on empty JSON', () {
      final result = RiskResult.fromJson({});
      expect(result.riskScore, 0.0);
      expect(result.classification, '');
      expect(result.contributingEvents, 0);
    });
  });

  // ──────────────────────────────────────────────────────────
  // GeoArea model tests
  // ──────────────────────────────────────────────────────────
  group('GeoArea.toQuery', () {
    test('produces correct query map keys', () {
      final area = GeoArea(
        city: 'Mumbai',
        center: LatLng(19.076, 72.8777),
        radiusKm: 10,
      );
      final query = area.toQuery();
      expect(query['city'], 'Mumbai');
      expect(query.containsKey('lat'), isTrue);
      expect(query.containsKey('lng'), isTrue);
      expect(query.containsKey('radiusKm'), isTrue);
    });
  });
}
