import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../config/config_service.dart';
import '../config/runtime_config.dart';
import '../models/app_models.dart';

class AppStore extends ChangeNotifier {
  AppStore({required RuntimeConfig initialConfig})
    : area = GeoArea(
        city: kOperationalCityName,
        center: const LatLng(kBhopalLatitude, kBhopalLongitude),
        radiusKm: 8,
      ),
      _runtimeConfig = initialConfig,
      _baseUrl = initialConfig.baseUrl,
      _client = ApiClient(
        baseUrl: initialConfig.baseUrl,
        requestTimeout: initialConfig.apiTimeout,
      );

  final GeoArea area;
  final ApiClient _client;
  RuntimeConfig _runtimeConfig;

  String _baseUrl;
  SyncState syncState = SyncState.connecting;
  String? lastError;
  DateTime? lastSyncedAt;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  List<DisruptionEvent> events = const [];
  List<AreaNewsItem> news = const [];
  List<SourceStatus> sources = const [];
  RiskResult? lastRisk;

  Set<String> activeNewsCategories = <String>{};

  String get baseUrl => _baseUrl;
  String get namespace => _client.namespace;
  String get configSource => _runtimeConfig.source;
  String get environment => _runtimeConfig.environment.name;
  int get apiTimeoutMs => _runtimeConfig.apiTimeoutMs;
  Map<String, dynamic> get features => _runtimeConfig.features;
  List<String> get availableCategories =>
      news.map((n) => n.category).toSet().toList(growable: false)..sort();

  Future<void> bootstrap() async {
    await refreshRuntimeConfig();
    await refreshAll();
  }

  Future<void> refreshRuntimeConfig() async {
    final config = await ConfigService.refresh();
    _applyRuntimeConfig(config, notify: false);
  }

  Future<void> refreshAll() async {
    _transition(SyncState.connecting, clearError: true);

    try {
      _client.baseUrl = _baseUrl;
      _client.requestTimeout = _runtimeConfig.apiTimeout;
      await _client.detectNamespace();
    } on SocketException catch (e) {
      _fail('Transport failure: ${e.message}', scheduleReconnect: true);
      return;
    } on HttpException catch (e) {
      _fail('API contract failure: ${e.message}');
      return;
    } on FormatException catch (e) {
      _fail('API contract failure: ${e.message}');
      return;
    } on Exception catch (e) {
      _fail('Transport failure: $e', scheduleReconnect: true);
      return;
    }

    _transition(SyncState.syncing);

    try {
      final snapshot = await _client.fetchOperationalSnapshot(
        area,
        categories: activeNewsCategories,
      );
      events = snapshot.events;
      news = snapshot.news;
      sources = snapshot.sources;
      lastSyncedAt = DateTime.now();
      _reconnectAttempts = 0;
      _cancelReconnect();
      _transition(SyncState.synced, clearError: true);
    } on SocketException catch (e) {
      _fail('Transport failure: ${e.message}', scheduleReconnect: true);
    } on HttpException catch (e) {
      _fail('Data-plane failure: ${e.message}');
    } on FormatException catch (e) {
      _fail('API contract failure: ${e.message}');
    } on Exception catch (e) {
      _fail('Data-plane failure: $e');
    }
  }

  Future<void> refreshNewsOnly() async {
    try {
      news = await _client.fetchNewsSignals(
        area,
        categories: activeNewsCategories,
      );
      lastSyncedAt = DateTime.now();
      if (!_disposed) {
        notifyListeners();
      }
    } on SocketException catch (e) {
      _fail('Transport failure: ${e.message}', scheduleReconnect: true);
    } on HttpException catch (e) {
      _fail('Data-plane failure: ${e.message}');
    } on FormatException catch (e) {
      _fail('API contract failure: ${e.message}');
    } on Exception catch (e) {
      _fail('Data-plane failure: $e');
    }
  }

  Future<void> evaluateRisk({
    required LatLng start,
    required LatLng end,
  }) async {
    _transition(SyncState.syncing, clearError: true);

    final route = <LatLngCoordinate>[
      LatLngCoordinate(start.latitude, start.longitude),
      LatLngCoordinate(
        start.latitude + (end.latitude - start.latitude) / 2,
        start.longitude + (end.longitude - start.longitude) / 2,
      ),
      LatLngCoordinate(end.latitude, end.longitude),
    ];

    try {
      lastRisk = await _client.calculateRisk(route);
      lastSyncedAt = DateTime.now();
      _transition(SyncState.synced, clearError: true);
    } on SocketException catch (e) {
      _fail('Transport failure: ${e.message}', scheduleReconnect: true);
    } on HttpException catch (e) {
      _fail('Data-plane failure: ${e.message}');
    } on FormatException catch (e) {
      _fail('API contract failure: ${e.message}');
    } on Exception catch (e) {
      _fail('Data-plane failure: $e');
    }
  }

  void updateArea({
    required String city,
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    if (city.trim().toLowerCase() != kOperationalCityName.toLowerCase()) {
      _fail('Data-plane failure: only $kOperationalCityName is supported');
      return;
    }

    area.city = kOperationalCityName;
    area.center = LatLng(lat, lng);
    area.radiusKm = radiusKm;
    notifyListeners();
  }

  Future<void> updateBaseUrl(String value) async {
    final config = await ConfigService.setBaseUrlOverride(value);
    _applyRuntimeConfig(config);
  }

  void toggleCategory(String category) {
    if (activeNewsCategories.contains(category)) {
      activeNewsCategories.remove(category);
    } else {
      activeNewsCategories.add(category);
    }
    notifyListeners();
  }

  void clearActiveCategories() {
    activeNewsCategories.clear();
    notifyListeners();
  }

  void _transition(SyncState nextState, {bool clearError = false}) {
    syncState = nextState;
    if (clearError) {
      lastError = null;
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _fail(String message, {bool scheduleReconnect = false}) {
    syncState = SyncState.error;
    lastError = message;
    if (!_disposed) {
      notifyListeners();
    }
    if (scheduleReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) {
      return;
    }
    final delaySeconds = math.min(30, 1 << math.min(_reconnectAttempts, 4));
    _reconnectAttempts += 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      if (_disposed) {
        return;
      }
      await refreshAll();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _applyRuntimeConfig(RuntimeConfig config, {bool notify = true}) {
    final changed = _runtimeConfig.baseUrl != config.baseUrl ||
        _runtimeConfig.apiTimeoutMs != config.apiTimeoutMs ||
        _runtimeConfig.environment != config.environment ||
        _runtimeConfig.source != config.source ||
        !const MapEquality<String, dynamic>().equals(
          _runtimeConfig.features,
          config.features,
        );
    _runtimeConfig = config;
    _baseUrl = config.baseUrl;
    _client.baseUrl = config.baseUrl;
    _client.requestTimeout = config.apiTimeout;
    if (notify && changed && !_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelReconnect();
    _client.close();
    super.dispose();
  }
}
