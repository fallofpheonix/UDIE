import 'package:flutter/material.dart';
import '../../theme/udie_theme.dart';

/// A skeleton shimmer placeholder used while data is loading.
///
/// Renders an animated gradient sweep over a rounded rectangle.
/// Pass [width] and [height] to size it; if [width] is omitted it will
/// expand to fill available horizontal space.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = UdieTheme.radiusSm,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: const [
                Color(0xFF1C2A3E),
                Color(0xFF253548),
                Color(0xFF1C2A3E),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A convenience column of skeleton rows that mimics a text block.
class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    this.lines = 3,
    this.lastLineWidth = 0.65,
  });

  final int lines;
  final double lastLineWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) {
        final isLast = i == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: i < lines - 1 ? 8 : 0),
          child: LayoutBuilder(
            builder: (context, constraints) => SkeletonBox(
              width: isLast
                  ? constraints.maxWidth * lastLineWidth
                  : constraints.maxWidth,
              height: 13,
            ),
          ),
        );
      }),
    );
  }
}
