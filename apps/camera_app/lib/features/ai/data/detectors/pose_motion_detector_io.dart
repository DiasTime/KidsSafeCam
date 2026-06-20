import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../domain/ai_detector.dart';
import 'pose_motion_detector.dart';

PoseMotionDetectorBase? createPoseMotionDetector() => PoseMotionDetector();

/// Camera-based **fall** + **wake** detection using ML Kit Pose.
///
/// Owns the camera while monitoring: it runs an image stream, estimates the
/// baby's pose, and derives two signals:
///  - **fall** — a rapid downward motion of the torso into a horizontal
///    orientation.
///  - **wake** — a transition from sustained stillness (asleep) to sustained
///    movement.
///
/// The heuristics use normalized landmark geometry so they're resolution
/// independent; the thresholds are deliberately conservative and meant to be
/// tuned on-device.
class PoseMotionDetector implements PoseMotionDetectorBase {
  PoseMotionDetector();

  // Tunables (normalized image units, seconds).
  static const _processEveryMs = 200; // ~5 fps
  static const _fallDownVelocity = 0.9; // torso-Y units per second
  static const _torsoHorizontalRatio = 0.7; // |dx| / |dy| of torso vector
  static const _stillMotion = 0.012; // below = "still"
  static const _wakeMotion = 0.05; // above = "moving"
  static const _sleepConfirm = Duration(seconds: 20);
  static const _wakeConfirmFrames = 3;

  final _controller = StreamController<AiDetection>.broadcast();
  final _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  CameraController? _camera;
  bool _busy = false;

  Map<PoseLandmarkType, PoseLandmark>? _prev;
  DateTime? _prevAt;
  DateTime? _stillSince;
  bool _asleep = false;
  int _wakeFrames = 0;

  @override
  String get name => 'pose';

  @override
  Stream<AiDetection> get detections => _controller.stream;

  @override
  Object? get previewController => _camera;

  @override
  Future<void> start() async {
    if (_camera != null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();
    _camera = controller;
    await controller.startImageStream(_onImage);
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy) return;
    final now = DateTime.now();
    if (_prevAt != null &&
        now.difference(_prevAt!).inMilliseconds < _processEveryMs) {
      return;
    }
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final poses = await _poseDetector.processImage(input);
      if (poses.isEmpty) {
        _prev = null;
        return;
      }
      _analyse(poses.first, image, now);
    } catch (_) {
      // Skip a bad frame.
    } finally {
      _busy = false;
    }
  }

  void _analyse(Pose pose, CameraImage image, DateTime now) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final lms = pose.landmarks;

    final shoulders = _mid(
      lms[PoseLandmarkType.leftShoulder],
      lms[PoseLandmarkType.rightShoulder],
    );
    final hips = _mid(
      lms[PoseLandmarkType.leftHip],
      lms[PoseLandmarkType.rightHip],
    );
    if (shoulders == null || hips == null) return;

    // ── Fall: rapid downward torso motion into a horizontal pose ──
    final dt = _prevAt == null
        ? 0.0
        : now.difference(_prevAt!).inMilliseconds / 1000.0;
    if (_prev != null && dt > 0) {
      final prevShoulders = _mid(
        _prev![PoseLandmarkType.leftShoulder],
        _prev![PoseLandmarkType.rightShoulder],
      );
      if (prevShoulders != null) {
        final vY = ((shoulders.dy - prevShoulders.dy) / h) / dt; // +ve = down
        final torsoDx = (shoulders.dx - hips.dx).abs() / w;
        final torsoDy = (shoulders.dy - hips.dy).abs() / h;
        final horizontal =
            torsoDy < 1e-3 || (torsoDx / (torsoDy + 1e-6)) > _torsoHorizontalRatio;
        if (vY > _fallDownVelocity && horizontal) {
          _controller.add(
            AiDetection(
              type: BabyEventType.fallDetected,
              confidence: math.min(1.0, vY / (_fallDownVelocity * 2)),
              metadata: {'downVelocity': vY},
            ),
          );
        }
      }
    }

    // ── Wake: stillness → movement transition ──
    final motion = _motion(lms, w, h);
    if (motion != null) {
      if (motion < _stillMotion) {
        _stillSince ??= now;
        _wakeFrames = 0;
        if (!_asleep &&
            now.difference(_stillSince!).compareTo(_sleepConfirm) >= 0) {
          _asleep = true;
        }
      } else if (motion > _wakeMotion) {
        _stillSince = null;
        if (_asleep && ++_wakeFrames >= _wakeConfirmFrames) {
          _asleep = false;
          _wakeFrames = 0;
          _controller.add(
            AiDetection(
              type: BabyEventType.babyAwake,
              confidence: math.min(1.0, motion / (_wakeMotion * 2)),
              metadata: {'motion': motion},
            ),
          );
        }
      } else {
        _stillSince = null;
        _wakeFrames = 0;
      }
    }

    _prev = Map.of(lms);
    _prevAt = now;
  }

  /// Mean normalized displacement of a few key landmarks since the last frame.
  double? _motion(Map<PoseLandmarkType, PoseLandmark> lms, double w, double h) {
    final prev = _prev;
    if (prev == null) return null;
    const keys = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    var sum = 0.0;
    var n = 0;
    for (final k in keys) {
      final a = lms[k];
      final b = prev[k];
      if (a == null || b == null) continue;
      final dx = (a.x - b.x) / w;
      final dy = (a.y - b.y) / h;
      sum += math.sqrt(dx * dx + dy * dy);
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  ({double dx, double dy})? _mid(PoseLandmark? a, PoseLandmark? b) {
    if (a == null || b == null) return null;
    return (dx: (a.x + b.x) / 2, dy: (a.y + b.y) / 2);
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(
      camera.description.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.isEmpty) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> stop() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      try {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
      } catch (_) {}
      await camera.dispose();
    }
    _prev = null;
    _prevAt = null;
    _stillSince = null;
    _asleep = false;
    _wakeFrames = 0;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _poseDetector.close();
    await _controller.close();
  }
}
