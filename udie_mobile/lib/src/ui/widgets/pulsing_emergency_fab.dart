import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

class PulsingEmergencyFab extends StatefulWidget {
  const PulsingEmergencyFab({
    super.key,
    required this.onTap,
    this.heroTag = 'emergency_fab',
  });

  final VoidCallback onTap;
  final Object heroTag;

  @override
  State<PulsingEmergencyFab> createState() => _PulsingEmergencyFabState();
}

class _PulsingEmergencyFabState extends State<PulsingEmergencyFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 2.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = Tween<double>(
      begin: 0.45,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: UdieTheme.danger.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              );
            },
          ),
          FloatingActionButton(
            heroTag: widget.heroTag,
            backgroundColor: UdieTheme.danger,
            elevation: 10,
            onPressed: widget.onTap,
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
