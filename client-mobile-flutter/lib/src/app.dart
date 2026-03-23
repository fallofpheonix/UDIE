import 'package:flutter/material.dart';

import 'config/runtime_config.dart';
import 'state/app_store.dart';
import 'theme/udie_theme.dart';
import 'ui/screens/boot_sequence_screen.dart';
import 'ui/screens/home_shell.dart';

class UdieApp extends StatefulWidget {
  const UdieApp({
    super.key,
    required this.initialConfig,
    this.bootstrapError,
  });

  final RuntimeConfig? initialConfig;
  final String? bootstrapError;

  @override
  State<UdieApp> createState() => _UdieAppState();
}

class _UdieAppState extends State<UdieApp> {
  AppStore? _store;
  bool _bootComplete = false;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    if (config != null) {
      _store = AppStore(initialConfig: config);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _store?.bootstrap();
      });
    }
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return MaterialApp(
      title: 'UDIE Mobile',
      debugShowCheckedModeBanner: false,
      theme: UdieTheme.build(),
      home: widget.bootstrapError != null
          ? _BootstrapFailureScreen(message: widget.bootstrapError!)
          : store == null
          ? const _BootstrapFailureScreen(
              message: 'Runtime configuration was not initialized.',
            )
          : _bootComplete
          ? HomeShell(store: store)
          : BootSequenceScreen(
              store: store,
              onBootComplete: () {
                if (!mounted || _bootComplete) {
                  return;
                }
                setState(() => _bootComplete = true);
              },
            ),
    );
  }
}

class _BootstrapFailureScreen extends StatelessWidget {
  const _BootstrapFailureScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BOOTSTRAP FAILURE',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
