import 'package:flutter/material.dart';

class LiveAssetBeacon extends StatefulWidget {
  const LiveAssetBeacon({
    super.key,
    this.color = Colors.blueAccent,
    this.size = 60,
  });

  final Color color;
  final double size;

  @override
  State<LiveAssetBeacon> createState() => _LiveAssetBeaconState();
}

class _LiveAssetBeaconState extends State<LiveAssetBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coreSize = widget.size * 0.27;
    final innerSize = widget.size * 0.10;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_controller.value * 2.0),
                child: Opacity(
                  opacity: 1.0 - _controller.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: coreSize,
            height: coreSize,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
