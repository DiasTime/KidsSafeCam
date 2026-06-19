import '../../../../domain/entities/baby_event.dart';

/// Contract for reading and producing baby-monitor events.
abstract class EventRepository {
  /// Streams the events owned by [ownerId], newest first.
  Stream<List<BabyEvent>> watchEvents(String ownerId, {int limit = 100});

  /// Records a new event (used by the camera's on-device AI, Step 12+).
  /// Returns the new event's id.
  Future<String> addEvent({
    required String deviceId,
    required String ownerId,
    required BabyEventType type,
    Map<String, dynamic> metadata = const {},
  });
}
