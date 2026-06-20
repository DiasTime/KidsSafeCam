import 'dart:async';

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:camera_app/features/ai/data/ai_monitor.dart';
import 'package:camera_app/features/ai/domain/ai_detector.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDetector implements AiDetector {
  final _controller = StreamController<AiDetection>.broadcast();
  bool started = false;

  @override
  String get name => 'fake';

  @override
  Stream<AiDetection> get detections => _controller.stream;

  void emit(AiDetection d) => _controller.add(d);

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => started = false;

  @override
  Future<void> dispose() async => _controller.close();
}

class _RecordingEventRepository implements EventRepository {
  final List<BabyEventType> added = [];

  @override
  Future<String> addEvent({
    required String deviceId,
    required String ownerId,
    required BabyEventType type,
    Map<String, dynamic> metadata = const {},
  }) async {
    added.add(type);
    return 'id${added.length}';
  }

  @override
  Stream<List<BabyEvent>> watchEvents(String ownerId, {int limit = 100}) =>
      const Stream.empty();
}

void main() {
  test('emits an event for a detection and starts the detectors', () async {
    final detector = _FakeDetector();
    final repo = _RecordingEventRepository();
    final monitor = AiMonitor(
      eventRepository: repo,
      deviceId: 'dev',
      ownerId: 'owner',
      detectors: [detector],
      now: () => DateTime(2026),
    );

    await monitor.start();
    expect(detector.started, isTrue);

    detector.emit(const AiDetection(type: BabyEventType.babyCry));
    await Future<void>.delayed(Duration.zero);

    expect(repo.added, [BabyEventType.babyCry]);
    await monitor.stop();
    expect(detector.started, isFalse);
  });

  test('applies a per-type cooldown', () async {
    final detector = _FakeDetector();
    final repo = _RecordingEventRepository();
    var clock = DateTime(2026);
    final monitor = AiMonitor(
      eventRepository: repo,
      deviceId: 'dev',
      ownerId: 'owner',
      detectors: [detector],
      cooldown: const Duration(minutes: 1),
      now: () => clock,
    );

    await monitor.start();

    detector.emit(const AiDetection(type: BabyEventType.babyCry));
    await Future<void>.delayed(Duration.zero);
    // Same type within the cooldown window is suppressed.
    detector.emit(const AiDetection(type: BabyEventType.babyCry));
    await Future<void>.delayed(Duration.zero);
    // A different type is not affected by the cry cooldown.
    detector.emit(const AiDetection(type: BabyEventType.fallDetected));
    await Future<void>.delayed(Duration.zero);
    // After the cooldown elapses, cry is allowed again.
    clock = clock.add(const Duration(minutes: 2));
    detector.emit(const AiDetection(type: BabyEventType.babyCry));
    await Future<void>.delayed(Duration.zero);

    expect(repo.added, [
      BabyEventType.babyCry,
      BabyEventType.fallDetected,
      BabyEventType.babyCry,
    ]);
    await monitor.stop();
  });
}
