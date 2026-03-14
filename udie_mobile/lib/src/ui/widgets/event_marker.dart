import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';

/// A styled, tappable map marker for a [DisruptionEvent].
///
/// The marker is a circle whose diameter and color are driven by the event's
/// severity.  A category-appropriate icon is rendered inside the circle.
class EventMarker extends StatelessWidget {
  const EventMarker({super.key, required this.event, this.onTap});

  final DisruptionEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = UdieTheme.categoryColor(event.category);
    final icon = UdieTheme.categoryIcon(event.category);
    // Diameter scales from 24 dp (severity 0) to 40 dp (severity 1).
    final diameter = 24.0 + event.severity * 16.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: diameter + 4,
        height: diameter + 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.9),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: diameter * 0.52),
          ),
        ),
      ),
    );
  }
}
