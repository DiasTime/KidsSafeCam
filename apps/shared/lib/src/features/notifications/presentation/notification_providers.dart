import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_notification.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/repositories/firestore_notification_repository.dart';
import '../domain/repositories/notification_repository.dart';

/// The app's [NotificationRepository]. Override in tests with a fake.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FirestoreNotificationRepository(),
);

/// Streams the signed-in user's notifications, newest first.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(const <AppNotification>[]);
  return ref.watch(notificationRepositoryProvider).watchNotifications(user.id);
});

/// Count of unread notifications — drives a badge on the parent home screen.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications =
      ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.read).length;
});
