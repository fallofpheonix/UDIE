import 'package:flutter/material.dart';

import 'state/app_store.dart';
import 'theme.dart';
import 'ui/screens/home_shell.dart';

class UdieApp extends StatefulWidget {
  const UdieApp({super.key});

  @override
  State<UdieApp> createState() => _UdieAppState();
}

class _UdieAppState extends State<UdieApp> {
  late final AppStore _store;

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
      home: HomeShell(store: _store),
    );
  }
}
