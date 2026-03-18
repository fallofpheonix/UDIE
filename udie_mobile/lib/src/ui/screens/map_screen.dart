import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../state/app_store.dart';
import '../../theme/udie_theme.dart';
import 'emergency_report_ui.dart';
import '../widgets/event_marker.dart';
import '../widgets/glass_event_sheet.dart';
import '../widgets/hud_sync_overlay.dart';
import '../widgets/live_feed_sheet.dart';
import '../widgets/pulsing_emergency_fab.dart';
import '../widgets/radar_empty_state.dart';
import '../widgets/route_risk_scanner.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.store,
    this.onOpenRoutePlanner,
  });

  final AppStore store;
  final VoidCallback? onOpenRoutePlanner;

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
    showGlassEventSheet(
      context,
      event: event,
      observedAt: _timeFormat.format(event.updatedAt.toLocal()),
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

            // ── Sync overlay ───────────────────────────────────────────────────
            if (isLoading)
              const Positioned.fill(
                child: HudSyncOverlay(),
              ),

            if (!isLoading && store.events.isEmpty)
              const Positioned.fill(
                child: RadarEmptyState(),
              ),

            Positioned(
              top: topPadding + 8,
              left: 12,
              right: 12,
              child: RouteRiskScanner(
                isScanning: false,
                originLabel: store.area.city,
                destinationLabel: 'Select destination in route planner',
                actionLabel: 'OPEN ROUTE ANALYZER',
                onAnalyzeRoute:
                    widget.onOpenRoutePlanner ?? widget.store.refreshAll,
              ),
            ),

            // ── Floating action buttons (right side) ───────────────────────────
            Positioned(
              top: topPadding + 184,
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

            Positioned(
              right: 16,
              bottom: 132,
              child: PulsingEmergencyFab(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmergencyReportUI(),
                    ),
                  );
                },
              ),
            ),

            // ── Severity legend ────────────────────────────────────────────────
            Positioned(
              top: topPadding + 184,
              left: 12,
              child: const _MapLegend(),
            ),

            Positioned.fill(
              child: LiveFeedSheet(
                events: store.events,
                syncState: store.syncState,
                onSelectEvent: _showEventDetail,
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
