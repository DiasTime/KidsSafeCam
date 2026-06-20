import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// VAPID key for **web** push. Get it from Firebase Console → Project Settings →
/// Cloud Messaging → *Web Push certificates*, and pass it at build time:
/// `flutter run -d chrome --dart-define=FCM_VAPID_KEY=<key>`.
/// Native platforms (Android/iOS) ignore it.
const fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Registers this device's FCM token under the signed-in user so the backend
/// fan-out can push event notifications (cry / fall / awake) to the parent.
final fcmRegistrarProvider = Provider<FcmRegistrar>(
  (ref) => FcmRegistrar(vapidKey: fcmVapidKey.isEmpty ? null : fcmVapidKey),
);
