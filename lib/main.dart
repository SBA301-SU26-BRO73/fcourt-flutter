import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'core/config/app_config.dart';
import 'features/offline/data/offline_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeOfflineWorker();
  final dependencies = AppDependencies.create(AppConfig.fromEnvironment());
  runApp(FcourtApp(dependencies: dependencies));
}
