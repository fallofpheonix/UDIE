import 'package:flutter/material.dart';

import 'state/app_store.dart';
import 'theme/udie_theme.dart';
import 'ui/screens/boot_sequence_screen.dart';
import 'ui/screens/home_shell.dart';

class UdieApp extends StatefulWidget {
  const UdieApp({super.key});

  @override
  State<UdieApp> createState() => _UdieAppState();
}

class _UdieAppState extends State<UdieApp> {
  late final AppStore _store;
  bool _bootComplete = false;

  @override
  void initState() {
    super.initState();
    _store = AppStore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.bootstrap();
    });
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UDIE Mobile',
      debugShowCheckedModeBanner: false,
      theme: UdieTheme.build(),
      home: _bootComplete
          ? HomeShell(store: _store)
          : BootSequenceScreen(
              store: _store,
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
