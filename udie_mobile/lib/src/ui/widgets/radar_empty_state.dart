import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

class RadarEmptyState extends StatefulWidget {
  const RadarEmptyState({super.key});

  @override
  State<RadarEmptyState> createState() => _RadarEmptyStateState();
}

class _RadarEmptyStateState extends State<RadarEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                var value = (_radarController.value - (index * 0.33)) % 1.0;
                if (value < 0) {
                  value += 1.0;
                }

                return Transform.scale(
                  scale: value * 3.0,
                  child: Opacity(
                    opacity: (1.0 - value) * 0.22,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: UdieTheme.ok, width: 2),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: UdieTheme.ok.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: UdieTheme.ok.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'SECTOR CLEAR',
                  style: TextStyle(
                    color: UdieTheme.ok,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
