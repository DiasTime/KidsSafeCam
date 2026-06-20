import 'dart:async';

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../ai/presentation/ai_monitor_controller.dart';

/// State the camera screen renders: whether the local preview is live, whether
/// a parent is currently connected, and the peer-connection state of any active
/// call.
@immutable
class CameraStreamingState {
  const CameraStreamingState({
    this.previewReady = false,
    this.paired = false,
    this.callState,
    this.errorMessage,
  });

  /// True once the local camera preview is capturing.
  final bool previewReady;

  /// True once this camera identity is paired to a device.
  final bool paired;

  /// Peer-connection state of the active viewer call, or null when no parent
  /// is connected.
  final RTCPeerConnectionState? callState;

  final String? errorMessage;

  bool get hasViewer =>
      callState != null &&
      callState != RTCPeerConnectionState.RTCPeerConnectionStateClosed &&
      callState != RTCPeerConnectionState.RTCPeerConnectionStateFailed;

  CameraStreamingState copyWith({
    bool? previewReady,
    bool? paired,
    RTCPeerConnectionState? callState,
    bool clearCallState = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CameraStreamingState(
      previewReady: previewReady ?? this.previewReady,
      paired: paired ?? this.paired,
      callState: clearCallState ? null : (callState ?? this.callState),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Drives the camera (callee) side of streaming while the camera screen is
/// active: keeps a local preview running and answers parent calls as they
/// appear on this device's `calls` subcollection. Full background operation is
/// Step 9; this listener only lives as long as the screen is mounted.
class CameraStreamingController
    extends AutoDisposeNotifier<CameraStreamingState> {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  WebRtcSession? _session;
  StreamSubscription<String>? _callSub;
  String? _deviceId;
  bool _disposed = false;

  @override
  CameraStreamingState build() {
    ref.onDispose(_dispose);
    localRenderer.initialize();
    // Keep the AI monitor alive while this screen is mounted; it owns the
    // camera + mic and runs the detectors until a live call borrows them.
    ref.listen(aiMonitorControllerProvider, (_, _) {});
    ref.listen<AsyncValue<Device?>>(
      cameraDeviceProvider,
      (_, next) => _onDeviceChanged(next.valueOrNull?.id),
      fireImmediately: true,
    );
    return const CameraStreamingState();
  }

  void _onDeviceChanged(String? deviceId) {
    if (_disposed || deviceId == _deviceId) return;
    _deviceId = deviceId;
    _callSub?.cancel();
    state = state.copyWith(paired: deviceId != null);
    if (deviceId == null) return;
    _callSub = ref
        .read(signalingClientProvider)
        .watchIncomingCalls(deviceId)
        .listen(_answerCall);
  }

  Future<void> _answerCall(String callId) async {
    final deviceId = _deviceId;
    if (_disposed || deviceId == null) return;

    // Hand the camera + mic to WebRTC: pause the AI monitor first so the call
    // can capture them. AI resumes when the call ends.
    await ref.read(aiMonitorControllerProvider.notifier).pauseForCall();

    // Only one viewer at a time in Step 6: replace any existing session.
    await _session?.close();

    final iceServers = await ref.read(iceServersProvider.future);
    if (_disposed) return;

    final session = ref.read(webRtcSessionFactoryProvider)(
      deviceId: deviceId,
      callId: callId,
      iceServers: iceServers,
    );
    _session = session;
    // Show the operator the call's local capture.
    session.onLocalStream = (stream) {
      if (_disposed || _session != session) return;
      localRenderer.srcObject = stream;
      state = state.copyWith(previewReady: true, clearError: true);
    };
    session.connectionState.addListener(() {
      if (_disposed || _session != session) return;
      final cs = session.connectionState.value;
      state = state.copyWith(callState: cs);
      // Route the parent's push-to-talk audio to the loudspeaker once the call
      // is actually connected — WebRTC defaults mobile output to the earpiece,
      // and setting it before the remote audio session is up gets reverted.
      if (!kIsWeb &&
          cs == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        Helper.setSpeakerphoneOn(true);
      }
      if (cs == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
          cs == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          cs == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _endCall(session);
      }
    });

    try {
      // localStream omitted → the session captures its own camera + mic.
      await session.answerAsCallee();
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: 'Failed to answer the call: $e');
      await session.close();
      if (_session == session) _session = null;
      _resumeMonitoring();
    }
  }

  /// Tears the live call down and hands the camera/mic back to the AI monitor.
  Future<void> _endCall(WebRtcSession session) async {
    if (_session != session) return;
    _session = null;
    await session.close();
    if (_disposed) return;
    localRenderer.srcObject = null;
    state = state.copyWith(previewReady: false, clearCallState: true);
    _resumeMonitoring();
  }

  void _resumeMonitoring() {
    if (_disposed) return;
    ref.read(aiMonitorControllerProvider.notifier).resumeAfterCall();
  }

  Future<void> _dispose() async {
    _disposed = true;
    await _callSub?.cancel();
    await _session?.close();
    _session = null;
    try {
      await localRenderer.dispose();
    } catch (_) {}
  }
}

final cameraStreamingControllerProvider =
    AutoDisposeNotifierProvider<
      CameraStreamingController,
      CameraStreamingState
    >(CameraStreamingController.new);
