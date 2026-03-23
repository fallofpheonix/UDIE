import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../theme/udie_theme.dart';

/// A styled, tappable map marker for a [DisruptionEvent].
///
/// The marker is a circle whose size and color are driven by the event's
/// severity.  A category-appropriate icon is rendered inside.  High-severity
/// markers have a pulsing ring to draw attention.
class EventMarker extends StatefulWidget {
  const EventMarker({super.key, required this.event, this.onTap});

  final DisruptionEvent event;
  final VoidCallback? onTap;

  @override
  State<EventMarker> createState() => _EventMarkerState();
}

class _EventMarkerState extends State<EventMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring;
  late final Animation<double> _ringAnim;

  bool get _isHigh => widget.event.severity >= 0.7;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringAnim = CurvedAnimation(parent: _ring, curve: Curves.easeOut);
    if (_isHigh) _ring.repeat();
  }

  @override
  void didUpdateWidget(EventMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isHigh && !_ring.isAnimating) {
      _ring.repeat();
    } else if (!_isHigh && _ring.isAnimating) {
      _ring.stop();
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = UdieTheme.categoryColor(widget.event.category);
    final icon = UdieTheme.categoryIcon(widget.event.category);
    final diameter = 26.0 + widget.event.severity * 14.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        width: diameter + 16,
        height: diameter + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring for high severity
            if (_isHigh)
              AnimatedBuilder(
                animation: _ringAnim,
                builder: (context, _) => Container(
                  width: diameter + 8 + _ringAnim.value * 14,
                  height: diameter + 8 + _ringAnim.value * 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(
                        alpha: (1 - _ringAnim.value) * 0.55,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            // Core circle
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.92),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: diameter * 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
