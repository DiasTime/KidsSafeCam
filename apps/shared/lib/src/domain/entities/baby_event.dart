import 'package:equatable/equatable.dart';

/// The kinds of events the system can produce. Mirrors the backend `EventType`.
enum BabyEventType {
  babyCry('baby_cry'),
  fallDetected('fall_detected'),
  motionDetected('motion_detected'),
  soundDetected('sound_detected'),
  connectionLost('connection_lost');

  const BabyEventType(this.wireName);

  /// The string stored in Firestore.
  final String wireName;

  static BabyEventType fromWire(String value) {
    return BabyEventType.values.firstWhere(
      (e) => e.wireName == value,
      orElse: () => BabyEventType.soundDetected,
    );
  }
}

/// A detected event (cry, fall, motion, …) attributed to a device and owner.
class BabyEvent extends Equatable {
  const BabyEvent({
    required this.id,
    required this.deviceId,
    required this.ownerId,
    required this.type,
    required this.timestamp,
    this.metadata = const {},
  });

  final String id;
  final String deviceId;
  final String ownerId;
  final BabyEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  @override
  List<Object?> get props => [id, deviceId, ownerId, type, timestamp];
}
