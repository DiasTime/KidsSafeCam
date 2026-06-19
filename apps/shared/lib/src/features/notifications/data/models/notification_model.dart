import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../domain/entities/app_notification.dart';

/// Maps between Firestore documents and the [AppNotification] domain entity.
class NotificationModel {
  NotificationModel._();

  static AppNotification fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: _toDate(data['createdAt']) ?? DateTime.now(),
      eventId: data['eventId'] as String?,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
