import 'dart:async';

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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

  MediaStream? _previewStream;
  WebRtcSession? _session;
  StreamSubscription<String>? _callSub;
  String? _deviceId;
  bool _disposed = false;

  @override
  CameraStreamingState build() {
    ref.onDispose(_dispose);
    _startPreview();
    ref.listen<AsyncValue<Device?>>(
      cameraDeviceProvider,
      (_, next) => _onDeviceChanged(next.valueOrNull?.id),
      fireImmediately: true,
    );
    return const CameraStreamingState();
  }

  Future<void> _startPreview() async {
    try {
      await localRenderer.initialize();
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });
      if (_disposed) {
        await stream.dispose();
        return;
      }
      _previewStream = stream;
      localRenderer.srcObject = stream;
      state = state.copyWith(previewReady: true, clearError: true);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: 'Could not start the camera: $e');
    }
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
    session.connectionState.addListener(() {
      if (_disposed || _session != session) return;
      state = state.copyWith(callState: session.connectionState.value);
    });

    try {
      await session.answerAsCallee(localStream: _previewStream);
      // Route the parent's push-to-talk audio to the loudspeaker — WebRTC
      // defaults to the earpiece on mobile, which is inaudible across a room.
      if (!kIsWeb) {
        await Helper.setSpeakerphoneOn(true);
      }
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: 'Failed to answer the call: $e');
      await session.close();
      if (_session == session) _session = null;
    }
  }

  Future<void> _dispose() async {
    _disposed = true;
    await _callSub?.cancel();
    await _session?.close();
    _session = null;
    try {
      await _previewStream?.dispose();
    } catch (_) {}
    _previewStream = null;
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
