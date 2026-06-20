import '../../domain/ai_detector.dart';
// ML Kit pose detection is mobile-only; web/desktop fall back to a no-op stub.
import 'pose_motion_detector_stub.dart'
    if (dart.library.io) 'pose_motion_detector_io.dart' as impl;

/// Builds the platform's camera-based fall + wake detector, or `null` where
/// unsupported (web). The returned detector also exposes a camera preview.
PoseMotionDetectorBase? createPoseMotionDetector() =>
    impl.createPoseMotionDetector();

/// Shared surface so the camera UI can show the monitoring preview without
/// importing the platform implementation.
abstract class PoseMotionDetectorBase implements AiDetector {
  /// The active camera controller (a `CameraController`), exposed as `Object?`
  /// so the UI can build a `CameraPreview` without the web build importing the
  /// camera plugin. Null until [start] and after [stop].
  Object? get previewController;
}
