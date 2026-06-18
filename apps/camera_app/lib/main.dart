import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';

/// Entry point for the Camera app. Firebase initialization is wired in Step 1
/// (firebase_core + firebase_options.dart, which is generated per environment).
void main() {
  runApp(const ProviderScope(child: CameraApp()));
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Baby Monitor — Camera',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: cameraRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
