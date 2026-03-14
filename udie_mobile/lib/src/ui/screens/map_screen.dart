import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';

import '../../models.dart';
import '../../state/app_store.dart';
import '../../theme.dart';
import '../widgets/event_marker.dart';

const double _kHighSeverity = 0.7;
const double _kMedSeverity = 0.35;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const int _maxMarkers = 180;
  final _timeFormat = DateFormat('dd MMM, HH:mm');

  void _showEventDetail(DisruptionEvent event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _EventDetailSheet(event: event, timeFormat: _timeFormat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    final markers = store.events
        .take(_maxMarkers)
        .map(
          (event) => Marker(
            point: event.point,
            width: 44,
            height: 44,
            child: EventMarker(
              event: event,
              onTap: () => _showEventDetail(event),
            ),
          ),
        )
        .toList(growable: false);

    final isLoading = store.syncState == SyncState.connecting;

    return Stack(
      children: [
        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          key: ValueKey(
            '${store.area.center.latitude}-${store.area.center.longitude}-${store.area.radiusKm}',
          ),
          options: MapOptions(
            initialCenter: store.area.center,
            initialZoom: 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.udie.mobile',
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: store.area.center,
                  radius: store.area.radiusKm * 1000,
                  useRadiusInMeter: true,
                  color: UdieTheme.accent.withValues(alpha: 0.08),
                  borderColor: UdieTheme.accent.withValues(alpha: 0.6),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(markers: markers),
          ],
        ),

        // ── Loading indicator ───────────────────────────────────────────────
        if (isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),

        // ── Severity legend ─────────────────────────────────────────────────
        const Positioned(
          top: 12,
          right: 12,
          child: _MapLegend(),
        ),

        // ── Bottom info panel ───────────────────────────────────────────────
        Positioned(
          left: 12,
          right: 12,
          bottom: 14,
          child: _BottomPanel(store: store),
        ),
      ],
    );
  }
}

// ── Legend ──────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendRow(color: UdieTheme.danger, label: 'High'),
          SizedBox(height: 4),
          _LegendRow(color: UdieTheme.caution, label: 'Med'),
          SizedBox(height: 4),
          _LegendRow(color: UdieTheme.ok, label: 'Low'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

// ── Bottom panel ─────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final high = store.events
        .where((e) => e.severity >= _kHighSeverity)
        .length;
    final med = store.events
        .where((e) =>
            e.severity >= _kMedSeverity &&
            e.severity < _kHighSeverity)
        .length;
    final low = store.events
        .where((e) => e.severity < _kMedSeverity)
        .length;

    return Card(
      elevation: 8,
      shadowColor: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.area.city,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${store.events.length} disruptions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _SeverityBadge(count: high, color: UdieTheme.danger, label: 'H'),
                const SizedBox(width: 4),
                _SeverityBadge(count: med, color: UdieTheme.caution, label: 'M'),
                const SizedBox(width: 4),
                _SeverityBadge(count: low, color: UdieTheme.ok, label: 'L'),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: store.refreshAll,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Refresh', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${store.area.radiusKm.toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 20,
                    divisions: 19,
                    value: store.area.radiusKm,
                    onChanged: (v) {
                      store.updateArea(
                        city: store.area.city,
                        lat: store.area.center.latitude,
                        lng: store.area.center.longitude,
                        radiusKm: v,
                      );
                    },
                    onChangeEnd: (_) => store.refreshAll(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({
    required this.count,
    required this.color,
    required this.label,
  });

  final int count;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Event detail bottom sheet ────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({required this.event, required this.timeFormat});

  final DisruptionEvent event;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final color = UdieTheme.categoryColor(event.category);
    final icon = UdieTheme.categoryIcon(event.category);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.category.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SeverityChip(severity: event.severity),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.source_outlined,
                  label: 'Source',
                  value: event.source,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value:
                      '${event.lat.toStringAsFixed(4)}, ${event.lng.toStringAsFixed(4)}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'Updated',
                  value: timeFormat.format(event.updatedAt.toLocal()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final double severity;

  @override
  Widget build(BuildContext context) {
    final color = severity >= _kHighSeverity
        ? UdieTheme.danger
        : severity >= _kMedSeverity
            ? UdieTheme.caution
            : UdieTheme.ok;
    final label = severity >= _kHighSeverity
        ? 'HIGH'
        : severity >= _kMedSeverity
            ? 'MED'
            : 'LOW';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

