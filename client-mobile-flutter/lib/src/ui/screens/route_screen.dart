import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/app_models.dart';
import '../../state/app_store.dart';
import '../../theme/udie_theme.dart';
import '../widgets/ui_components.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final TextEditingController _startAddress;
  late final TextEditingController _startLat;
  late final TextEditingController _startLng;
  late final TextEditingController _endAddress;
  late final TextEditingController _endLat;
  late final TextEditingController _endLng;
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
    final c = widget.store.area.center;
    _startAddress = TextEditingController(text: 'Bhopal Center');
    _startLat = TextEditingController(text: c.latitude.toStringAsFixed(6));
    _startLng = TextEditingController(text: c.longitude.toStringAsFixed(6));
    _endAddress = TextEditingController(text: 'MP Nagar Zone 1');
    _endLat = TextEditingController(
      text: (c.latitude + 0.03).toStringAsFixed(6),
    );
    _endLng = TextEditingController(
      text: (c.longitude + 0.03).toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _startAddress.dispose();
    _startLat.dispose();
    _startLng.dispose();
    _endAddress.dispose();
    _endLat.dispose();
    _endLng.dispose();
    super.dispose();
  }

  Future<void> _onEvaluate() async {
    final sLat = double.tryParse(_startLat.text.trim());
    final sLng = double.tryParse(_startLng.text.trim());
    final eLat = double.tryParse(_endLat.text.trim());
    final eLng = double.tryParse(_endLng.text.trim());
    if (sLat == null || sLng == null || eLat == null || eLng == null) {
      return;
    }
    setState(() => _isEvaluating = true);
    await widget.store.evaluateRisk(
      start: LatLng(sLat, sLng),
      end: LatLng(eLat, eLng),
    );
    if (mounted) setState(() => _isEvaluating = false);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        UdieTheme.sp16,
        topPad + UdieTheme.sp8,
        UdieTheme.sp16,
        UdieTheme.sp32,
      ),
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: UdieTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(UdieTheme.radiusMd),
                border: Border.all(
                  color: UdieTheme.accent.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                color: UdieTheme.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: UdieTheme.sp12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Intelligence',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: UdieTheme.textPrimary,
                  ),
                ),
                Text(
                  'Compute corridor risk from backend evaluation',
                  style: TextStyle(
                    fontSize: 12,
                    color: UdieTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: UdieTheme.sp20),

        // ── Waypoints ────────────────────────────────────────────────────────
        _WaypointCard(
          label: 'Origin',
          icon: Icons.trip_origin_rounded,
          color: UdieTheme.ok,
          addressCtrl: _startAddress,
          latCtrl: _startLat,
          lngCtrl: _startLng,
        ),
        // Connector
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            children: List.generate(
              3,
              (i) => Container(
                width: 2,
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: UdieTheme.textMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        _WaypointCard(
          label: 'Destination',
          icon: Icons.place_rounded,
          color: UdieTheme.danger,
          addressCtrl: _endAddress,
          latCtrl: _endLat,
          lngCtrl: _endLng,
        ),
        const SizedBox(height: UdieTheme.sp20),

        // ── Evaluate button ───────────────────────────────────────────────────
        AnimatedSwitcher(
          duration: UdieTheme.durationFast,
          child: _isEvaluating
              ? Container(
                  key: const ValueKey('loading'),
                  height: 48,
                  decoration: BoxDecoration(
                    color: UdieTheme.accent.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(UdieTheme.radiusMd),
                    border: Border.all(
                      color: UdieTheme.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(UdieTheme.accent),
                      ),
                    ),
                  ),
                )
              : FilledButton.icon(
                  key: const ValueKey('button'),
                  onPressed: _onEvaluate,
                  icon: const Icon(Icons.analytics_rounded, size: 18),
                  label: const Text('Engage Route Analysis'),
                ),
        ),
        const SizedBox(height: UdieTheme.sp20),

        // ── Risk result card (animated) ──────────────────────────────────────
        ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final risk = widget.store.lastRisk;
            return AnimatedSwitcher(
              duration: UdieTheme.durationMedium,
              switchInCurve: UdieTheme.curveDefault,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: risk != null
                  ? _RiskResultCard(key: ValueKey(risk.riskScore), risk: risk)
                  : const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }
}

// ── Waypoint card ─────────────────────────────────────────────────────────────

class _WaypointCard extends StatelessWidget {
  const _WaypointCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.addressCtrl,
    required this.latCtrl,
    required this.lngCtrl,
  });

  final String label;
  final IconData icon;
  final Color color;
  final TextEditingController addressCtrl;
  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(UdieTheme.sp14),
      decoration: BoxDecoration(
        color: UdieTheme.surface1,
        borderRadius: BorderRadius.circular(UdieTheme.radiusLg),
        border: Border.all(color: UdieTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(UdieTheme.radiusSm),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: UdieTheme.sp8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: UdieTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: UdieTheme.sp12),
          TextField(
            controller: addressCtrl,
            readOnly: true,
            style: const TextStyle(
              fontSize: 13,
              color: UdieTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(
                Icons.place_rounded,
                size: 16,
                color: UdieTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: UdieTheme.sp8),
          Text(
            '${latCtrl.text}, ${lngCtrl.text}',
            style: const TextStyle(
              color: UdieTheme.textMuted,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Risk result card ──────────────────────────────────────────────────────────

class _RiskResultCard extends StatelessWidget {
  const _RiskResultCard({super.key, required this.risk});

  final RiskResult risk;

  @override
  Widget build(BuildContext context) {
    final riskColor = UdieTheme.riskColor(risk.riskScore);
    final riskLabel = UdieTheme.riskLabel(risk.riskScore);

    return Container(
      decoration: BoxDecoration(
        color: UdieTheme.surface1,
        borderRadius: BorderRadius.circular(UdieTheme.radiusLg),
        border: Border.all(color: riskColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: riskColor.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header band
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UdieTheme.sp16,
              vertical: UdieTheme.sp12,
            ),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(UdieTheme.radiusLg),
                topRight: Radius.circular(UdieTheme.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk Assessment',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: riskColor.withValues(alpha: 0.8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        risk.classification,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score dial
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: riskColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: riskColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        risk.riskScore.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        riskLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: riskColor.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(UdieTheme.sp16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RISK PROFILE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: UdieTheme.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: UdieTheme.sp10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        FractionallySizedBox(
                          widthFactor: risk.riskScore.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  UdieTheme.ok,
                                  riskColor,
                                  UdieTheme.ok.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: UdieTheme.sp16),
                InfoRow(
                  icon: Icons.density_medium_rounded,
                  label: 'Risk Density',
                  value: risk.riskDensity.toStringAsFixed(4),
                ),
                const SizedBox(height: UdieTheme.sp12),
                InfoRow(
                  icon: Icons.warning_amber_rounded,
                  label: 'Contributing Events',
                  value: '${risk.contributingEvents}',
                  valueColor: riskColor,
                ),
                const SizedBox(height: UdieTheme.sp12),
                InfoRow(
                  icon: Icons.speed_rounded,
                  label: 'Evaluation Latency',
                  value: '${risk.evalLatencyMs} ms',
                  valueColor: UdieTheme.ok,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
