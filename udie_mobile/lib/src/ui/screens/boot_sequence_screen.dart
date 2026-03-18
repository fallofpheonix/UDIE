import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../state/app_store.dart';
import '../../theme/udie_theme.dart';

class BootSequenceScreen extends StatefulWidget {
  const BootSequenceScreen({
    super.key,
    required this.store,
    required this.onBootComplete,
  });

  final AppStore store;
  final VoidCallback onBootComplete;

  @override
  State<BootSequenceScreen> createState() => _BootSequenceScreenState();
}

class _BootSequenceScreenState extends State<BootSequenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _completionQueued = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final lines = _bootLines();
            final isTerminalState =
                widget.store.syncState == SyncState.synced ||
                widget.store.syncState == SyncState.error;

            if (isTerminalState && !_completionQueued) {
              _completionQueued = true;
              Future<void>.delayed(
                const Duration(milliseconds: 420),
                _completeBoot,
              );
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: UdieTheme.accent.withValues(alpha: 0.45),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: UdieTheme.accent.withValues(alpha: 0.18),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.hub_outlined,
                          color: UdieTheme.accent,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 56),
                    SizedBox(
                      height: 128,
                      child: Column(
                        children: [
                          for (var i = 0; i < lines.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                lines[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: i == lines.length - 1
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.36),
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  letterSpacing: 1.8,
                                  fontWeight: i == lines.length - 1
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<String> _bootLines() {
    switch (widget.store.syncState) {
      case SyncState.connecting:
        return const [
          'INITIALIZING UDIE KERNEL...',
          'ESTABLISHING SECURE CONNECTION...',
        ];
      case SyncState.syncing:
        return [
          'INITIALIZING UDIE KERNEL...',
          'ESTABLISHING SECURE CONNECTION...',
          'SYNCING BHOPAL EVENT VIEW...',
          'PROBING ${widget.store.namespace.toUpperCase()}...',
        ];
      case SyncState.synced:
        return [
          'INITIALIZING UDIE KERNEL...',
          'ESTABLISHING SECURE CONNECTION...',
          'SYNCING BHOPAL EVENT VIEW...',
          'PROBING ${widget.store.namespace.toUpperCase()}...',
          'SYSTEM ONLINE. WELCOME, OPERATOR.',
        ];
      case SyncState.error:
        return [
          'INITIALIZING UDIE KERNEL...',
          'ESTABLISHING SECURE CONNECTION...',
          'SYNCING BHOPAL EVENT VIEW...',
          widget.store.lastError?.toUpperCase() ?? 'BOOT DEGRADED.',
          'ENTERING TERMINAL WITH DEGRADED CONNECTIVITY.',
        ];
    }
  }

  Future<void> _completeBoot() async {
    if (!mounted) {
      return;
    }
    await _fadeController.reverse();
    if (mounted) {
      widget.onBootComplete();
    }
  }
}
