import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';

import '../../models.dart';
import '../../state/app_store.dart';
import '../../theme.dart';
import '../widgets/event_marker.dart';
import '../widgets/ui_components.dart';

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
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _showEventDetail(DisruptionEvent event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) =>
          _EventDetailSheet(event: event, timeFormat: _timeFormat),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;

        final markers = store.events
            .take(_maxMarkers)
            .map(
              (event) => Marker(
                point: event.point,
                width: 56,
                height: 56,
                child: EventMarker(
                  event: event,
                  onTap: () => _showEventDetail(event),
                ),
              ),
            )
            .toList(growable: false);

        final isLoading = store.syncState == SyncState.connecting || store.syncState == SyncState.syncing;

        return Stack(
          children: [
            // ── Map ───────────────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              key: ValueKey(
                '${store.area.center.latitude}-'
                '${store.area.center.longitude}-'
                '${store.area.radiusKm}',
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
                      color: UdieTheme.accent.withValues(alpha: 0.07),
                      borderColor: UdieTheme.accent.withValues(alpha: 0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
                MarkerLayer(markers: markers),
              ],
            ),

            // ── Loading bar ────────────────────────────────────────────────────
            if (isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(UdieTheme.accent),
                ),
              ),

            // ── Floating action buttons (right side) ───────────────────────────
            Positioned(
              top: topPadding + 12,
              right: 12,
              child: _MapFABColumn(
                onCenter: () => _mapController.move(
                  store.area.center,
                  _mapController.camera.zoom,
                ),
                onZoomIn: () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                ),
                onZoomOut: () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                ),
                onRefresh: store.refreshAll,
              ),
            ),

            // ── Severity legend ────────────────────────────────────────────────
            Positioned(
              top: topPadding + 12,
              left: 12,
              child: const _MapLegend(),
            ),

            // ── Bottom info panel ──────────────────────────────────────────────
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _BottomPanel(
                store: store,
                mapController: _mapController,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Floating action buttons ───────────────────────────────────────────────────

class _MapFABColumn extends StatelessWidget {
  const _MapFABColumn({
    required this.onCenter,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRefresh,
  });

  final VoidCallback onCenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapFAB(icon: Icons.my_location_rounded, onTap: onCenter),
        const SizedBox(height: 8),
        _MapFAB(icon: Icons.add_rounded, onTap: onZoomIn),
        const SizedBox(height: 4),
        _MapFAB(icon: Icons.remove_rounded, onTap: onZoomOut),
        const SizedBox(height: 8),
        _MapFAB(
          icon: Icons.refresh_rounded,
          onTap: onRefresh,
          color: UdieTheme.accent,
        ),
      ],
    );
  }
}

class _MapFAB extends StatefulWidget {
  const _MapFAB({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  State<_MapFAB> createState() => _MapFABState();
}

class _MapFABState extends State<_MapFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.12,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - _press.value,
          child: child,
        ),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: UdieTheme.surface1.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(UdieTheme.radiusMd),
            border: Border.all(color: UdieTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.color ?? UdieTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: UdieTheme.glassDecoration(
        color: UdieTheme.surface0,
        borderRadius: UdieTheme.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendRow(color: UdieTheme.danger, label: 'High'),
          SizedBox(height: 5),
          _LegendRow(color: UdieTheme.caution, label: 'Med'),
          SizedBox(height: 5),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: UdieTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.store, required this.mapController});

  final AppStore store;
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    final high = store.events
        .where((e) => e.severity >= _kHighSeverity)
        .length;
    final med = store.events
        .where((e) =>
            e.severity >= _kMedSeverity && e.severity < _kHighSeverity)
        .length;
    final low = store.events
        .where((e) => e.severity < _kMedSeverity)
        .length;

    return Container(
      decoration: UdieTheme.glassDecoration(
        color: UdieTheme.surface0,
        borderRadius: UdieTheme.radiusXl,
      ),
      padding: const EdgeInsets.fromLTRB(
        UdieTheme.sp16,
        UdieTheme.sp16,
        UdieTheme.sp16,
        UdieTheme.sp12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // City + severity row
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
                        fontSize: 17,
                        color: UdieTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${store.events.length} active disruptions',
                      style: const TextStyle(
                        fontSize: 12,
                        color: UdieTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: UdieTheme.sp12),
              SeverityCountBadge(
                count: high,
                color: UdieTheme.danger,
                label: 'HIGH',
              ),
              const SizedBox(width: UdieTheme.sp6),
              SeverityCountBadge(
                count: med,
                color: UdieTheme.caution,
                label: 'MED',
              ),
              const SizedBox(width: UdieTheme.sp6),
              SeverityCountBadge(
                count: low,
                color: UdieTheme.ok,
                label: 'LOW',
              ),
            ],
          ),
          const SizedBox(height: UdieTheme.sp12),
          // Radius row
          Row(
            children: [
              const Icon(
                Icons.radio_button_checked_rounded,
                size: 14,
                color: UdieTheme.accent,
              ),
              const SizedBox(width: 6),
              Text(
                '${store.area.radiusKm.toStringAsFixed(0)} km radius',
                style: const TextStyle(
                  fontSize: 12,
                  color: UdieTheme.textSecondary,
                  fontWeight: FontWeight.w600,
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
    );
  }
}

// ── Event detail bottom sheet ─────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({required this.event, required this.timeFormat});

  final DisruptionEvent event;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final color = UdieTheme.categoryColor(event.category);
    final icon = UdieTheme.categoryIcon(event.category);
    final riskColor = UdieTheme.riskColor(event.severity);
    final riskLabel = UdieTheme.riskLabel(event.severity);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: UdieTheme.surface1,
        borderRadius: BorderRadius.circular(UdieTheme.radiusXl),
        border: Border.all(color: UdieTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UdieTheme.sp16,
              0,
              UdieTheme.sp16,
              UdieTheme.sp20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(UdieTheme.radiusMd),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: UdieTheme.sp12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.category.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: UdieTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: UdieTheme.sp8),
                    // Severity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UdieTheme.sp8,
                        vertical: UdieTheme.sp4,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(UdieTheme.radiusSm),
                        border: Border.all(
                          color: riskColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            (event.severity * 100).toStringAsFixed(0),
                            style: TextStyle(
                              color: riskColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            riskLabel,
                            style: TextStyle(
                              color: riskColor.withValues(alpha: 0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UdieTheme.sp16),
                Container(
                  height: 1,
                  color: UdieTheme.border,
                ),
                const SizedBox(height: UdieTheme.sp16),
                InfoRow(
                  icon: Icons.source_outlined,
                  label: 'Source',
                  value: event.source,
                ),
                const SizedBox(height: UdieTheme.sp12),
                InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Coordinates',
                  value:
                      '${event.lat.toStringAsFixed(4)}, ${event.lng.toStringAsFixed(4)}',
                ),
                const SizedBox(height: UdieTheme.sp12),
                InfoRow(
                  icon: Icons.schedule_outlined,
                  label: 'Last Updated',
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
