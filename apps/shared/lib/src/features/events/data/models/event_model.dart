import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../domain/entities/baby_event.dart';

/// Maps between Firestore documents and the [BabyEvent] domain entity.
class EventModel {
  EventModel._();

  static BabyEvent fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return BabyEvent(
      id: doc.id,
      deviceId: data['deviceId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      type: BabyEventType.fromWire(data['type'] as String? ?? ''),
      timestamp: _toDate(data['timestamp']) ?? DateTime.now(),
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// Serializes an event for a producer (on-device AI, Step 12+) to write.
  /// `timestamp` uses a server timestamp so ordering is consistent across peers.
  static Map<String, dynamic> toMap({
    required String deviceId,
    required String ownerId,
    required BabyEventType type,
    Map<String, dynamic> metadata = const {},
  }) =>
      {
        'deviceId': deviceId,
        'ownerId': ownerId,
        'type': type.wireName,
        'timestamp': FieldValue.serverTimestamp(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
