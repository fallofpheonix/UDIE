import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

class HudSyncOverlay extends StatefulWidget {
  const HudSyncOverlay({super.key});

  @override
  State<HudSyncOverlay> createState() => _HudSyncOverlayState();
}

class _HudSyncOverlayState extends State<HudSyncOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: UdieTheme.bg.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _rotationController,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          UdieTheme.accent.withValues(alpha: 0.5),
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: Tween(begin: 1.0, end: 0.0).animate(
                      _rotationController,
                    ),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: UdieTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'SYNCING GRID...',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
