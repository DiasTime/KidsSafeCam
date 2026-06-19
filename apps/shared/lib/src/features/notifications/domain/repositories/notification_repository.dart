import '../../../../domain/entities/app_notification.dart';

/// Contract for the parent's in-app notification history. Notifications are
/// created by a Cloud Function (the Admin SDK bypasses rules); clients may only
/// read their own and mark them read.
abstract class NotificationRepository {
  /// Streams the user's notifications, newest first.
  Stream<List<AppNotification>> watchNotifications(
    String userId, {
    int limit = 100,
  });

  /// Marks a single notification read.
  Future<void> markRead(String notificationId);
}
