import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants.dart';
import '../../../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../models/notification_model.dart';

/// Firestore-backed [NotificationRepository]. Scoped by `userId` (also enforced
/// by the security rules); ordering matches the composite index
/// (userId, createdAt desc).
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);

  @override
  Stream<List<AppNotification>> watchNotifications(
    String userId, {
    int limit = 100,
  }) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(NotificationModel.fromDoc).toList());
  }

  @override
  Future<void> markRead(String notificationId) {
    return _notifications.doc(notificationId).update({'read': true});
  }
}
