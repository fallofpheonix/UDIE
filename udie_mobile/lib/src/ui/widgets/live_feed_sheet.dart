import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../theme/udie_theme.dart';

class LiveFeedSheet extends StatelessWidget {
  const LiveFeedSheet({
    super.key,
    required this.events,
    required this.syncState,
    required this.onSelectEvent,
  });

  final List<DisruptionEvent> events;
  final SyncState syncState;
  final ValueChanged<DisruptionEvent> onSelectEvent;

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...events]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return DraggableScrollableSheet(
      initialChildSize: 0.18,
      minChildSize: 0.18,
      maxChildSize: 0.62,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: UdieTheme.surface0.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LIVE FEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _syncColor(syncState),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _syncLabel(syncState),
                            style: TextStyle(
                              color: _syncColor(syncState),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sortedEvents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        'No active disruptions in the current viewport.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ...List.generate(sortedEvents.length, (index) {
                      final event = sortedEvents[index];
                      return _FeedItem(
                        event: event,
                        isNew: index == 0,
                        onTap: () => onSelectEvent(event),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeedItem extends StatelessWidget {
  const _FeedItem({
    required this.event,
    required this.isNew,
    required this.onTap,
  });

  final DisruptionEvent event;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = UdieTheme.categoryColor(event.category);
    final severity = _severityLabel(event.severity);
    final formatter = DateFormat('HH:mm:ss');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew ? color.withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            UdieTheme.categoryIcon(event.category),
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.category.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${event.title} · ${formatter.format(event.updatedAt.toLocal())}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Text(
          severity,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

String _severityLabel(double severity) {
  if (severity >= 0.7) {
    return 'CRITICAL';
  }
  if (severity >= 0.35) {
    return 'MAJOR';
  }
  return 'MINOR';
}

String _syncLabel(SyncState state) {
  switch (state) {
    case SyncState.connecting:
      return 'CONNECTING';
    case SyncState.syncing:
      return 'SYNCING';
    case SyncState.synced:
      return 'SYNCED';
    case SyncState.error:
      return 'ERROR';
  }
}

Color _syncColor(SyncState state) {
  switch (state) {
    case SyncState.connecting:
      return UdieTheme.info;
    case SyncState.syncing:
      return UdieTheme.caution;
    case SyncState.synced:
      return UdieTheme.ok;
    case SyncState.error:
      return UdieTheme.danger;
  }
}
