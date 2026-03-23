import 'package:flutter/material.dart';

import 'src/config/config_service.dart';
import 'src/config/runtime_config.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  RuntimeConfig? initialConfig;
  String? bootstrapError;
  try {
    initialConfig = await ConfigService.init();
  } on Object catch (error) {
    bootstrapError = error.toString();
  }

  runApp(
    UdieApp(
      initialConfig: initialConfig,
      bootstrapError: bootstrapError,
    ),
  );
}
