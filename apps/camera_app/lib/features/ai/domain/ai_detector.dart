import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';

/// A single detection emitted by an [AiDetector] (a cry, a fall, a wake-up, …).
class AiDetection {
  const AiDetection({
    required this.type,
    this.confidence = 1.0,
    this.metadata = const {},
  });

  /// The event this detection maps to (becomes the `events.type`).
  final BabyEventType type;

  /// Detector confidence in [0, 1]; carried into the event metadata.
  final double confidence;

  /// Extra detector-specific context stored on the event.
  final Map<String, dynamic> metadata;
}

/// A source of on-device detections. Implementations own their capture
/// (audio frames for cry, camera frames for fall/wake) and emit [AiDetection]s
/// on [detections]. [start]/[stop] acquire and release that capture so the
/// monitor can pause detectors while a live WebRTC call borrows the hardware.
abstract class AiDetector {
  /// Stable identifier used in logs/metadata (e.g. `cry`, `fall`, `wake`).
  String get name;

  /// Detections produced while the detector is running.
  Stream<AiDetection> get detections;

  /// Acquire capture and begin analysing. Safe to call when already started.
  Future<void> start();

  /// Release capture and stop analysing. Safe to call when already stopped.
  Future<void> stop();

  /// Release all resources permanently.
  Future<void> dispose();
}
