import 'package:flutter/material.dart';
import '../../theme.dart';

/// A small colored badge showing a count and a short label.
///
/// Used in the map bottom panel to show High / Medium / Low event counts.
class SeverityCountBadge extends StatelessWidget {
  const SeverityCountBadge({
    super.key,
    required this.count,
    required this.color,
    required this.label,
  });

  final int count;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UdieTheme.sp8,
        vertical: UdieTheme.sp4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(UdieTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal key–value row used inside detail sheets.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: UdieTheme.surface2,
            borderRadius: BorderRadius.circular(UdieTheme.radiusSm),
          ),
          child: Icon(
            icon,
            size: 14,
            color: UdieTheme.textSecondary,
          ),
        ),
        const SizedBox(width: UdieTheme.sp8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: UdieTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? UdieTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A section header with a thin leading accent line.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: UdieTheme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: UdieTheme.sp8),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: UdieTheme.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A drag handle bar used at the top of bottom sheets.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: UdieTheme.sp12),
        decoration: BoxDecoration(
          color: UdieTheme.borderStrong,
          borderRadius: BorderRadius.circular(UdieTheme.radiusFull),
        ),
      ),
    );
  }
}
