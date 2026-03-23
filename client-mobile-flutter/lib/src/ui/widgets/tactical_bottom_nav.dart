import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

typedef TacticalDestination =
    ({
      IconData icon,
      IconData selectedIcon,
      String label,
    });

class TacticalBottomNav extends StatelessWidget {
  const TacticalBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TacticalDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: UdieTheme.surface0.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / destinations.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: UdieTheme.durationMedium,
                        curve: UdieTheme.curveDefault,
                        top: 0,
                        left: itemWidth * currentIndex + (itemWidth / 2) - 15,
                        child: Container(
                          width: 30,
                          height: 3,
                          decoration: BoxDecoration(
                            color: UdieTheme.accent,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: [
                              BoxShadow(
                                color: UdieTheme.accent.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < destinations.length; i++)
                            Expanded(
                              child: _NavItem(
                                destination: destinations[i],
                                selected: currentIndex == i,
                                onTap: () => onTap(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final TacticalDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.selected
                    ? widget.destination.selectedIcon
                    : widget.destination.icon,
                color: widget.selected
                    ? UdieTheme.accent
                    : Colors.white.withValues(alpha: 0.42),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                widget.destination.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.selected
                      ? UdieTheme.accent
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
