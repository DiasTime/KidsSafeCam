import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_monitor.dart';
import '../data/detectors/cry_detector.dart';
import '../data/detectors/pose_motion_detector.dart';
import '../domain/ai_detector.dart';

/// What the camera UI renders for on-device monitoring.
@immutable
class AiMonitorState {
  const AiMonitorState({
    this.monitoring = false,
    this.previewController,
    this.activeDetectors = const [],
  });

  /// True while detectors are running (paired and no live call borrowing the
  /// camera/mic).
  final bool monitoring;

  /// The pose detector's `CameraController` (as `Object?`) for the live preview.
  final Object? previewController;

  /// Names of the detectors currently running (e.g. `cry`, `pose`).
  final List<String> activeDetectors;

  AiMonitorState copyWith({
    bool? monitoring,
    Object? previewController,
    List<String>? activeDetectors,
  }) => AiMonitorState(
    monitoring: monitoring ?? this.monitoring,
    previewController: previewController ?? this.previewController,
    activeDetectors: activeDetectors ?? this.activeDetectors,
  );
}

/// Drives the on-device AI monitor on the camera. It starts the detectors once
/// the camera is paired (so events can be attributed to the device owner) and
/// no live call is active, and surfaces a preview + status for the UI. The
/// streaming controller calls [pauseForCall]/[resumeAfterCall] to hand the
/// camera + mic to WebRTC during a live view.
class AiMonitorController extends AutoDisposeNotifier<AiMonitorState> {
  AiMonitor? _monitor;
  String? _deviceId;
  String? _ownerId;
  bool _pausedForCall = false;

  @override
  AiMonitorState build() {
    ref.onDispose(_dispose);
    ref.listen<AsyncValue<Device?>>(cameraDeviceProvider, (_, next) {
      _onDevice(next.valueOrNull);
    }, fireImmediately: true);
    return const AiMonitorState();
  }

  Future<void> _onDevice(Device? device) async {
    if (device == null) {
      _deviceId = null;
      _ownerId = null;
      await _stop();
      return;
    }
    _deviceId = device.id;
    _ownerId = device.ownerId;
    if (!_pausedForCall) await _start();
  }

  Future<void> _start() async {
    if (_monitor != null || _deviceId == null || _ownerId == null) return;
    final cry = createCryDetector();
    final pose = createPoseMotionDetector();
    final detectors = <AiDetector>[?cry, ?pose];
    if (detectors.isEmpty) return; // unsupported platform (web)

    final monitor = AiMonitor(
      eventRepository: ref.read(eventRepositoryProvider),
      deviceId: _deviceId!,
      ownerId: _ownerId!,
      detectors: detectors,
    );
    _monitor = monitor;
    try {
      await monitor.start();
    } catch (_) {
      // A failed capture (e.g. permission) leaves the monitor idle.
    }
    state = state.copyWith(
      monitoring: true,
      previewController: pose?.previewController,
      activeDetectors: [for (final d in detectors) d.name],
    );
  }

  Future<void> _stop() async {
    final monitor = _monitor;
    _monitor = null;
    await monitor?.dispose();
    state = const AiMonitorState();
  }

  /// Releases the camera + mic so a live call can take them.
  Future<void> pauseForCall() async {
    _pausedForCall = true;
    await _stop();
  }

  /// Resumes monitoring after a live call ends.
  Future<void> resumeAfterCall() async {
    _pausedForCall = false;
    await _start();
  }

  Future<void> _dispose() async {
    await _stop();
  }
}

final aiMonitorControllerProvider =
    AutoDisposeNotifierProvider<AiMonitorController, AiMonitorState>(
      AiMonitorController.new,
    );
