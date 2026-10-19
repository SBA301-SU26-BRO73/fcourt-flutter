import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_dependencies.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class FcourtApp extends StatefulWidget {
  const FcourtApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<FcourtApp> createState() => _FcourtAppState();
}

class _FcourtAppState extends State<FcourtApp> {
  late final GoRouter _router = createRouter(widget.dependencies);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FCOURT',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}
