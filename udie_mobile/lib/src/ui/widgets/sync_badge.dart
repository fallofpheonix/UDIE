import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

/// A compact pill badge that shows the current sync state.
///
/// When [state] is [SyncState.connecting] the badge pulses to signal activity.
class SyncBadge extends StatefulWidget {
  const SyncBadge({super.key, required this.state});

  final SyncState state;

  @override
  State<SyncBadge> createState() => _SyncBadgeState();
}

class _SyncBadgeState extends State<SyncBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    if (widget.state == SyncState.connecting) {
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
      SyncState.disconnected => ('OFFLINE', UdieTheme.danger),
      SyncState.connecting => ('SYNCING', UdieTheme.caution),
      SyncState.connectedUnsynced => ('PENDING', Colors.amber),
      SyncState.synced => ('LIVE', UdieTheme.ok),
      SyncState.error => ('ERROR', UdieTheme.danger),
    };

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bgAlpha = widget.state == SyncState.connecting
            ? 0.10 + _pulse.value * 0.18
            : 0.16;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: color.withValues(alpha: bgAlpha),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

