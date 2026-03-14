import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../models.dart';

class AppStore extends ChangeNotifier {
  static const Set<String> _supportedIndianCities = {
    'new delhi',
    'delhi',
    'mumbai',
    'bengaluru',
    'bangalore',
    'chennai',
    'hyderabad',
    'kolkata',
    'pune',
    'ahmedabad',
    'jaipur',
    'lucknow',
    'bhopal',
    'patna',
    'guwahati',
    'chandigarh',
    'srinagar',
    'kochi',
    'thiruvananthapuram',
    'nagpur',
    'indore',
    'surat',
    'kanpur',
    'varanasi',
    'visakhapatnam',
    'coimbatore',
    'madurai',
  };

  AppStore()
    : area = GeoArea(
        city: 'Delhi',
        center: const LatLng(28.6139, 77.2090),
        radiusKm: 10,
      ),
      _baseUrl = _defaultBaseUrl(),
      _client = ApiClient(baseUrl: _defaultBaseUrl());

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  final GeoArea area;
  final ApiClient _client;

  String _baseUrl;
  SyncState syncState = SyncState.disconnected;
  String? lastError;
  DateTime? lastSyncedAt;

  List<DisruptionEvent> events = const [];
  List<AreaNewsItem> news = const [];
  List<SourceStatus> sources = const [];
  RiskResult? lastRisk;

  Set<String> activeNewsCategories = <String>{};

  String get baseUrl => _baseUrl;
  String get namespace => _client.namespace;
  List<String> get availableCategories =>
      news.map((n) => n.category).toSet().toList(growable: false)..sort();

  Future<void> bootstrap() async {
    await refreshAll();
  }

  Future<void> refreshAll() async {
    syncState = SyncState.connecting;
    lastError = null;
    notifyListeners();

    try {
      _client.baseUrl = _baseUrl;
      await _client.detectNamespace();
      syncState = SyncState.connectedUnsynced;
      notifyListeners();

      final eventsData = await _client.fetchEvents(area);
      final newsData = await _client.fetchNews(
        area,
        categories: activeNewsCategories,
      );
      final sourcesData = await _client.fetchSources(area);

      events = eventsData;
      news = newsData;
      sources = sourcesData;
      lastSyncedAt = DateTime.now();
      syncState = SyncState.synced;
      notifyListeners();
    } on SocketException catch (e) {
      syncState = SyncState.disconnected;
      lastError = e.message;
      notifyListeners();
    } on HttpException catch (e) {
      syncState = SyncState.error;
      lastError = e.message;
      notifyListeners();
    } on Exception catch (e) {
      syncState = SyncState.error;
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshNewsOnly() async {
    try {
      final newsData = await _client.fetchNews(
        area,
        categories: activeNewsCategories,
      );
      news = newsData;
      lastSyncedAt = DateTime.now();
      syncState = SyncState.synced;
      notifyListeners();
    } on Exception catch (e) {
      syncState = SyncState.error;
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> evaluateRisk({
    required LatLng start,
    required LatLng end,
  }) async {
    syncState = SyncState.connecting;
    notifyListeners();

    final route = <LatLngCoordinate>[
      LatLngCoordinate(start.latitude, start.longitude),
      LatLngCoordinate(
        start.latitude + (end.latitude - start.latitude) / 2,
        start.longitude + (end.longitude - start.longitude) / 2,
      ),
      LatLngCoordinate(end.latitude, end.longitude),
    ];

    try {
      final result = await _client.calculateRisk(route);
      lastRisk = result;
      syncState = SyncState.synced;
      lastSyncedAt = DateTime.now();
      notifyListeners();
    } on Exception catch (e) {
      syncState = SyncState.error;
      lastError = e.toString();
      notifyListeners();
    }
  }

  void updateArea({
    required String city,
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    final normalized = city.trim().toLowerCase();
    if (!_supportedIndianCities.contains(normalized)) {
      syncState = SyncState.error;
      lastError = 'Only supported Indian cities are allowed';
      notifyListeners();
      return;
    }

    area.city = city;
    area.center = LatLng(lat, lng);
    area.radiusKm = radiusKm;
    syncState = SyncState.connectedUnsynced;
    notifyListeners();
  }

  void updateBaseUrl(String value) {
    _baseUrl = value.trim();
    syncState = SyncState.connectedUnsynced;
    notifyListeners();
  }

  void toggleCategory(String category) {
    if (activeNewsCategories.contains(category)) {
      activeNewsCategories.remove(category);
    } else {
      activeNewsCategories.add(category);
    }
    syncState = SyncState.connectedUnsynced;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
