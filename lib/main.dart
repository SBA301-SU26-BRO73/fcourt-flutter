import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'core/config/app_config.dart';
import 'features/offline/data/offline_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  if (!kIsWeb) await Firebase.initializeApp();
  await initializeOfflineWorker();
  final dependencies = AppDependencies.create(AppConfig.fromEnvironment());
  runApp(FcourtApp(dependencies: dependencies));
}
