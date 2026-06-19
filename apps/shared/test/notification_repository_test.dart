import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreNotificationRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreNotificationRepository(firestore: firestore);
  });

  Future<void> seed(
    String userId, {
    required String title,
    required bool read,
    required DateTime at,
  }) {
    return firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': 'b',
      'read': read,
      'createdAt': Timestamp.fromDate(at),
    });
  }

  test('watchNotifications scopes to the user, newest first', () async {
    await seed('parent1', title: 'old', read: true, at: DateTime(2026, 1, 1));
    await seed('parent1', title: 'new', read: false, at: DateTime(2026, 1, 2));
    await seed('other', title: 'theirs', read: false, at: DateTime(2026, 1, 3));

    final list = await repo.watchNotifications('parent1').first;

    expect(list.map((n) => n.title), ['new', 'old']);
    expect(list.every((n) => n.userId == 'parent1'), isTrue);
  });

  test('markRead flips the read flag', () async {
    final ref = await firestore.collection('notifications').add({
      'userId': 'parent1',
      'title': 'Baby is crying',
      'body': 'b',
      'read': false,
      'createdAt': Timestamp.now(),
    });

    await repo.markRead(ref.id);

    final doc = await ref.get();
    expect(doc.get('read'), isTrue);
  });
}
