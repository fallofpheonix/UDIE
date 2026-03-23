import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../theme/udie_theme.dart';

class GlassEventSheet extends StatelessWidget {
  const GlassEventSheet({
    super.key,
    required this.event,
    required this.observedAt,
  });

  final DisruptionEvent event;
  final String observedAt;

  Color get _severityColor => UdieTheme.riskColor(event.severity);

  String get _severityLabel {
    if (event.severity >= 0.7) {
      return 'critical';
    }
    if (event.severity >= 0.35) {
      return 'major';
    }
    return 'minor';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: UdieTheme.surface0.withValues(alpha: 0.78),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          event.title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _severityColor.withValues(alpha: 0.16),
                      border: Border.all(
                        color: _severityColor.withValues(alpha: 0.45),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _severityLabel.toUpperCase(),
                      style: TextStyle(
                        color: _severityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.radio_button_checked_rounded,
                    color: _severityColor,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${event.lat.toStringAsFixed(4)}, ${event.lng.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Observed: $observedAt',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showGlassEventSheet(
  BuildContext context, {
  required DisruptionEvent event,
  required String observedAt,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GlassEventSheet(event: event, observedAt: observedAt),
  );
}
