import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SyncState.disconnected => ('DISCONNECTED', UdieTheme.danger),
      SyncState.connecting => ('CONNECTING', UdieTheme.caution),
      SyncState.connectedUnsynced => ('CONNECTED_UNSYNCED', Colors.amber),
      SyncState.synced => ('SYNCED', UdieTheme.ok),
      SyncState.error => ('ERROR', UdieTheme.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
