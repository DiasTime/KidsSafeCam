import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'firebase_options.dart';

/// reCAPTCHA v3 site key (web). Real key only needed for web builds; pass via
/// `--dart-define=RECAPTCHA_V3_SITE_KEY=...`. Localhost dev uses the debug-token
/// flag in web/index.html instead.
const _recaptchaV3SiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: 'RECAPTCHA_V3_SITE_KEY_PLACEHOLDER',
);

/// Entry point for the Camera app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check guards the callable Cloud Functions (pairing + TURN). Each
  // platform attests differently; debug builds use debug providers (register
  // the printed token in the Firebase console), release builds use real
  // attestation (Play Integrity / DeviceCheck / reCAPTCHA).
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
    providerApple: kReleaseMode
        ? const AppleDeviceCheckProvider()
        : const AppleDebugProvider(),
    providerWeb: ReCaptchaV3Provider(_recaptchaV3SiteKey),
  );
  runApp(const ProviderScope(child: CameraApp()));
}

class CameraApp extends ConsumerWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Baby Monitor — Camera',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
