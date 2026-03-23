import 'package:flutter/material.dart';

import '../../theme/udie_theme.dart';

class EmergencyReportUI extends StatefulWidget {
  const EmergencyReportUI({
    super.key,
    this.onClose,
    this.onSubmit,
    this.isSubmitting = false,
    this.isSuccess = false,
  });

  final VoidCallback? onClose;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final bool isSuccess;

  @override
  State<EmergencyReportUI> createState() => _EmergencyReportUIState();
}

class _EmergencyReportUIState extends State<EmergencyReportUI>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final Animation<double> _fadeAnimation;
  final _typeController = TextEditingController();
  final _severityController = TextEditingController();
  final _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Curves.easeIn,
    );
    _typeController.text = 'Collision';
    _severityController.text = 'Major';
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _typeController.dispose();
    _severityController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REPORT DISRUPTION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _buildAnimatedField(
                  label: 'INCIDENT TYPE',
                  hint: 'e.g., Collision, Roadblock',
                  controller: _typeController,
                  delay: 0.2,
                ),
                const SizedBox(height: 24),
                _buildAnimatedField(
                  label: 'SEVERITY',
                  hint: 'Tap to select',
                  controller: _severityController,
                  delay: 0.4,
                ),
                const SizedBox(height: 24),
                _buildAnimatedField(
                  label: 'ADDITIONAL DETAILS',
                  hint: 'Optional description...',
                  controller: _detailsController,
                  delay: 0.6,
                  maxLines: 3,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: (widget.isSubmitting || widget.isSuccess)
                      ? null
                      : widget.onSubmit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 60,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: widget.isSuccess
                          ? UdieTheme.ok
                          : UdieTheme.danger,
                      borderRadius: BorderRadius.circular(
                        widget.isSubmitting ? 30 : 12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isSuccess
                                  ? UdieTheme.ok
                                  : UdieTheme.danger)
                              .withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : widget.isSuccess
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 32,
                            )
                          : const Text(
                              'TRANSMIT SIGNAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required double delay,
    int maxLines = 1,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: UdieTheme.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
