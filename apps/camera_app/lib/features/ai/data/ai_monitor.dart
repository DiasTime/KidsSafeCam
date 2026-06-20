import 'dart:async';

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';

import '../domain/ai_detector.dart';

/// Runs a set of [AiDetector]s and turns their detections into `events`
/// documents — which the backend `fanOutEventNotification` trigger turns into
/// parent push notifications and Activity-list rows.
///
/// A per-type cooldown stops a sustained cry or a flurry of fall detections from
/// spamming events/notifications: at most one event per type per [cooldown].
class AiMonitor {
  AiMonitor({
    required EventRepository eventRepository,
    required this.deviceId,
    required this.ownerId,
    required List<AiDetector> detectors,
    Duration cooldown = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _events = eventRepository,
       _detectors = detectors,
       _cooldown = cooldown,
       _now = now ?? DateTime.now;

  final EventRepository _events;
  final String deviceId;
  final String ownerId;
  final List<AiDetector> _detectors;
  final Duration _cooldown;
  final DateTime Function() _now;

  final _subs = <StreamSubscription<AiDetection>>[];
  final _lastEmitted = <BabyEventType, DateTime>{};
  bool _running = false;

  bool get isRunning => _running;

  /// Subscribes to every detector and starts their capture.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    for (final detector in _detectors) {
      _subs.add(detector.detections.listen(_onDetection));
      await detector.start();
    }
  }

  /// Stops capture and unsubscribes. Call when handing the camera/mic to a live
  /// call, or when monitoring ends. The cooldown history is cleared so a fresh
  /// session can emit immediately.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    for (final detector in _detectors) {
      await detector.stop();
    }
    _lastEmitted.clear();
  }

  /// Permanently releases the detectors.
  Future<void> dispose() async {
    await stop();
    for (final detector in _detectors) {
      await detector.dispose();
    }
  }

  Future<void> _onDetection(AiDetection detection) async {
    final now = _now();
    final last = _lastEmitted[detection.type];
    if (last != null && now.difference(last) < _cooldown) return;
    _lastEmitted[detection.type] = now;
    try {
      await _events.addEvent(
        deviceId: deviceId,
        ownerId: ownerId,
        type: detection.type,
        metadata: {
          'confidence': detection.confidence,
          'source': 'on_device_ai',
          ...detection.metadata,
        },
      );
    } catch (_) {
      // A failed event write must not tear down the monitor.
    }
  }
}
