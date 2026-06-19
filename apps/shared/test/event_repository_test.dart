import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreEventRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestoreEventRepository(firestore: firestore);
  });

  test('addEvent records an event the owner can read back', () async {
    final id = await repo.addEvent(
      deviceId: 'dev1',
      ownerId: 'parent1',
      type: BabyEventType.babyCry,
      metadata: {'confidence': 0.9},
    );

    final doc = await firestore.collection('events').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.get('ownerId'), 'parent1');
    expect(doc.get('type'), 'baby_cry');
    expect((doc.get('metadata') as Map)['confidence'], 0.9);
  });

  test('watchEvents returns only the owner\'s events, newest first', () async {
    final events = firestore.collection('events');
    await events.add({
      'deviceId': 'dev1',
      'ownerId': 'parent1',
      'type': 'baby_cry',
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });
    await events.add({
      'deviceId': 'dev1',
      'ownerId': 'parent1',
      'type': 'fall_detected',
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, 2)),
    });
    // Another parent's event must not leak.
    await events.add({
      'deviceId': 'dev9',
      'ownerId': 'other',
      'type': 'baby_cry',
      'timestamp': Timestamp.fromDate(DateTime(2026, 1, 3)),
    });

    final list = await repo.watchEvents('parent1').first;

    expect(list.length, 2);
    expect(list.first.type, BabyEventType.fallDetected); // newest first
    expect(list.last.type, BabyEventType.babyCry);
    expect(list.every((e) => e.ownerId == 'parent1'), isTrue);
  });
}
