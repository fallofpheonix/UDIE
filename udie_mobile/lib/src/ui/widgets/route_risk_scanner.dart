import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

class RouteRiskScanner extends StatefulWidget {
  const RouteRiskScanner({
    super.key,
    required this.onAnalyzeRoute,
    this.isScanning = false,
    this.originLabel = 'Current Location',
    this.destinationLabel = 'Enter Destination...',
    this.actionLabel = 'ANALYZE ROUTE',
  });

  final VoidCallback onAnalyzeRoute;
  final bool isScanning;
  final String originLabel;
  final String destinationLabel;
  final String actionLabel;

  @override
  State<RouteRiskScanner> createState() => _RouteRiskScannerState();
}

class _RouteRiskScannerState extends State<RouteRiskScanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOutSine),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(RouteRiskScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isScanning != widget.isScanning) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isScanning) {
      _scanController.repeat();
    } else {
      _scanController.stop();
      _scanController.value = 0;
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: UdieTheme.surface0.withValues(alpha: 0.72),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  if (widget.isScanning)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment(0, _scanAnimation.value),
                            heightFactor: 0.5,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    UdieTheme.accent.withValues(alpha: 0),
                                    UdieTheme.accent.withValues(alpha: 0.16),
                                    UdieTheme.accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLocationInput(
                          Icons.my_location,
                          widget.originLabel,
                          UdieTheme.accent,
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 11),
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        _buildLocationInput(
                          Icons.place,
                          widget.destinationLabel,
                          UdieTheme.danger,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.isScanning
                                  ? const Color(0xFF123562)
                                  : UdieTheme.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: widget.isScanning
                                ? null
                                : widget.onAnalyzeRoute,
                            child: Text(
                              widget.isScanning
                                  ? 'COMPUTING RISK...'
                                  : widget.actionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInput(IconData icon, String hint, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            hint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
