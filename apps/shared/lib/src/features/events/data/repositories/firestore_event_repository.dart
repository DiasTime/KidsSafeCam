import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants.dart';
import '../../../../domain/entities/baby_event.dart';
import '../../domain/repositories/event_repository.dart';
import '../models/event_model.dart';

/// Firestore-backed [EventRepository]. Queries are scoped by `ownerId`, which
/// the security rules also enforce; ordering matches the composite index in
/// `backend/firestore/firestore.indexes.json` (ownerId, timestamp desc).
class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection(FirestoreCollections.events);

  @override
  Stream<List<BabyEvent>> watchEvents(String ownerId, {int limit = 100}) {
    return _events
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(EventModel.fromDoc).toList());
  }

  @override
  Future<String> addEvent({
    required String deviceId,
    required String ownerId,
    required BabyEventType type,
    Map<String, dynamic> metadata = const {},
  }) async {
    final ref = await _events.add(
      EventModel.toMap(
        deviceId: deviceId,
        ownerId: ownerId,
        type: type,
        metadata: metadata,
      ),
    );
    return ref.id;
  }
}
