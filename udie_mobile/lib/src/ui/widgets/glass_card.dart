import 'package:flutter/material.dart';
import '../../theme.dart';

/// A card with a subtle frosted-glass look that fits the UDIE design system.
///
/// Renders a container with [UdieTheme.surface1] fill, a thin white border,
/// and a soft drop shadow.  Optionally accepts a [color] override and a
/// [borderRadius] override.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = UdieTheme.radiusLg,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = AnimatedContainer(
      duration: UdieTheme.durationFast,
      decoration: UdieTheme.glassDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );

    if (onTap == null) return container;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        splashColor: UdieTheme.accent.withValues(alpha: 0.08),
        highlightColor: UdieTheme.accent.withValues(alpha: 0.05),
        child: container,
      ),
    );
  }
}
