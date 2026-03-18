import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../theme/udie_theme.dart';

/// A compact pill badge that shows the current sync state.
///
/// When [state] is connecting or syncing the dot pulses to signal activity.
class SyncBadge extends StatefulWidget {
  const SyncBadge({super.key, required this.state});

  final SyncState state;

  @override
  State<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends State<SyncBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(SyncBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.state == SyncState.connecting || widget.state == SyncState.syncing) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (widget.state) {
      SyncState.connecting => ('CONNECTING', UdieTheme.info),
      SyncState.syncing => ('SYNCING', UdieTheme.caution),
      SyncState.synced => ('LIVE', UdieTheme.ok),
      SyncState.error => ('ERROR', UdieTheme.danger),
    };

    return AnimatedContainer(
      duration: UdieTheme.durationFast,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UdieTheme.radiusFull),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder: (context, _) => Transform.scale(
              scale: widget.state == SyncState.connecting || widget.state == SyncState.syncing
                  ? _scale.value
                  : 1.0,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
