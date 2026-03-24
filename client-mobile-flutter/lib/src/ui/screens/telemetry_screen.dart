import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../state/app_store.dart';
import '../../theme/udie_theme.dart';
import '../widgets/live_asset_beacon.dart';

class TelemetryScreen extends StatefulWidget {
  const TelemetryScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'SYSTEM TELEMETRY',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final store = widget.store;
          final syncColor = _syncColor(store.syncState);
          final syncLabel = store.syncState.name.toUpperCase();
          final lastSynced = store.lastSyncedAt == null
              ? 'PENDING'
              : DateFormat('dd MMM HH:mm:ss').format(store.lastSyncedAt!);
          final sourceErrors = store.sources
              .where((source) => (source.lastError ?? '').isNotEmpty)
              .length;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: UdieTheme.surface0,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: syncColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.78 + (_pulseController.value * 0.08),
                          child: child,
                        );
                      },
                      child: LiveAssetBeacon(
                        color: syncColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'NODE: ${store.area.city.toUpperCase()} · $syncLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MetricGauge(
                    label: 'EVENTS',
                    value: store.events.length.toString(),
                    unit: 'in view',
                    color: UdieTheme.accent,
                    progress: _normalizedProgress(store.events.length, 100),
                  ),
                  _MetricGauge(
                    label: 'SOURCES',
                    value: store.sources.length.toString(),
                    unit: 'active',
                    color: UdieTheme.info,
                    progress: _normalizedProgress(store.sources.length, 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MetricGauge(
                    label: 'NEWS',
                    value: store.news.length.toString(),
                    unit: 'items',
                    color: UdieTheme.caution,
                    progress: _normalizedProgress(store.news.length, 60),
                  ),
                  _MetricGauge(
                    label: 'FAULTS',
                    value: sourceErrors.toString(),
                    unit: 'sources',
                    color: sourceErrors == 0
                        ? UdieTheme.ok
                        : UdieTheme.danger,
                    progress: _normalizedProgress(sourceErrors, 5),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'RUNTIME',
                style: TextStyle(
                  color: UdieTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _StreamRow(label: 'Sync State', value: syncLabel),
              _StreamRow(label: 'Environment', value: store.environment),
              _StreamRow(label: 'Config Source', value: store.configSource),
              _StreamRow(label: 'API Namespace', value: store.namespace),
              _StreamRow(label: 'Backend URL', value: store.baseUrl),
              _StreamRow(
                label: 'API Timeout',
                value: '${store.apiTimeoutMs} ms',
              ),
              _StreamRow(label: 'Last Sync', value: lastSynced),
              _StreamRow(label: 'Operational City', value: store.area.city),
              _StreamRow(
                label: 'Visible Radius',
                value: '${store.area.radiusKm.toStringAsFixed(1)} km',
              ),
              if (store.lastError != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: UdieTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: UdieTheme.danger.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    store.lastError!,
                    style: const TextStyle(
                      color: UdieTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static double _normalizedProgress(int value, int scale) {
    if (scale <= 0) {
      return 0;
    }
    return (value / scale).clamp(0.0, 1.0);
  }
}

class _MetricGauge extends StatelessWidget {
  const _MetricGauge({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.progress,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1E293B)),
                ),
              ),
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StreamRow extends StatelessWidget {
  const _StreamRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _syncColor(SyncState state) {
  switch (state) {
    case SyncState.connecting:
      return UdieTheme.info;
    case SyncState.syncing:
      return UdieTheme.accent;
    case SyncState.synced:
      return UdieTheme.ok;
    case SyncState.error:
      return UdieTheme.danger;
  }
}
