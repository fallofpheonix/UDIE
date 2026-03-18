import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

class OperatorProfileScreen extends StatefulWidget {
  const OperatorProfileScreen({
    super.key,
    required this.operatorName,
    required this.clearanceLabel,
    required this.sector,
    required this.terminalId,
  });

  final String operatorName;
  final String clearanceLabel;
  final String sector;
  final String terminalId;

  @override
  State<OperatorProfileScreen> createState() => _OperatorProfileScreenState();
}

class _OperatorProfileScreenState extends State<OperatorProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'OPERATOR CREDENTIALS',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 450,
          decoration: BoxDecoration(
            color: UdieTheme.surface0,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: UdieTheme.accent.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: UdieTheme.accent.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: UdieTheme.accent,
                          size: 40,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: UdieTheme.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CLEARANCE: ${widget.clearanceLabel}',
                            style: const TextStyle(
                              color: UdieTheme.accent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'OPERATOR ID',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.operatorName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ASSIGNED SECTOR',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.sector.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(30, (index) {
                          final width = index % 3 == 0 ? 4.0 : 2.0;
                          return Container(
                            width: width,
                            color: Colors.white70,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'UID: ${widget.terminalId}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return Positioned(
                    top: _scanController.value * 446,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
